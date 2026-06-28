import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:http/http.dart' as http;

import 'curl_consts.dart';
import 'curl_ffi.dart';

class CurlResponse {
  final int statusCode;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final List<String> cookies;
  final String effectiveUrl;

  CurlResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
    required this.cookies,
    required this.effectiveUrl,
  });

  String get body => utf8.decode(bodyBytes, allowMalformed: true);
  dynamic get json => jsonDecode(body);

  @override
  String toString() => 'CurlResponse(statusCode: $statusCode, effectiveUrl: $effectiveUrl)';
}

// Payload passed to worker isolate
class _CurlRequestPayload {
  final String url;
  final String method;
  final String? impersonate;
  final Map<String, String> headers;
  final List<int>? bodyBytes;
  final List<String> initialCookies;
  final int timeoutMs;
  final bool followRedirects;
  final int maxRedirects;
  final String? proxy;
  final bool verify;
  final String? caBundlePath;

  _CurlRequestPayload({
    required this.url,
    required this.method,
    this.impersonate,
    required this.headers,
    this.bodyBytes,
    required this.initialCookies,
    required this.timeoutMs,
    required this.followRedirects,
    required this.maxRedirects,
    this.proxy,
    required this.verify,
    this.caBundlePath,
  });
}

typedef _CurlResponseResult = ({
  int statusCode,
  Map<String, String> headers,
  List<int> bodyBytes,
  List<String> cookies,
  String effectiveUrl,
  String? error,
});

// Top-level function executed inside Isolate.run
_CurlResponseResult _executeRequestInIsolate(_CurlRequestPayload payload) {
  final lib = LibCurl.instance;
  final curl = lib.easyInit();
  if (curl.address == 0) {
    return (
      statusCode: 0,
      headers: {},
      bodyBytes: [],
      cookies: [],
      effectiveUrl: payload.url,
      error: 'Failed to initialize curl handle',
    );
  }

  // Set target URL
  lib.setoptString(curl, CurlOpt.URL, payload.url);

  // Apply browser profile impersonation
  if (payload.impersonate != null) {
    final impersonatePtr = payload.impersonate!.toNativeUtf8();
    try {
      final ret = lib.easyImpersonate(curl, impersonatePtr, 1);
      if (ret != 0) {
        // Log/warn about profile setting failure, but proceed
      }
    } finally {
      malloc.free(impersonatePtr);
    }
  }

  // Set Request Method
  final method = payload.method.toUpperCase();
  if (method == 'POST') {
    lib.setoptInt(curl, CurlOpt.POST, 1);
  } else if (method != 'GET') {
    lib.setoptString(curl, CurlOpt.CUSTOMREQUEST, method);
  }

  // Set Headers
  ffi.Pointer<ffi.Void> headerList = ffi.Pointer.fromAddress(0);
  payload.headers.forEach((key, val) {
    final headerLinePtr = '$key: $val'.toNativeUtf8();
    headerList = lib.slistAppend(headerList, headerLinePtr);
    malloc.free(headerLinePtr);
  });
  if (headerList.address != 0) {
    lib.setoptPtr(curl, CurlOpt.HTTPHEADER, headerList);
  }

  // Set Request Body
  ffi.Pointer<ffi.Uint8> bodyPtr = ffi.Pointer.fromAddress(0);
  if (payload.bodyBytes != null && payload.bodyBytes!.isNotEmpty) {
    final bodyLen = payload.bodyBytes!.length;
    bodyPtr = malloc<ffi.Uint8>(bodyLen);
    final bodyView = bodyPtr.asTypedList(bodyLen);
    bodyView.setAll(0, payload.bodyBytes!);

    lib.setoptPtr(curl, CurlOpt.POSTFIELDS, bodyPtr.cast<ffi.Void>());
    lib.setoptInt(curl, CurlOpt.POSTFIELDSIZE, bodyLen);
    if (method == 'GET') {
      lib.setoptString(curl, CurlOpt.CUSTOMREQUEST, 'GET');
    }
  }

  // Setup Cookie Engine and initial cookies
  lib.setoptString(curl, CurlOpt.COOKIEFILE, ''); // memory only
  for (final cookie in payload.initialCookies) {
    lib.setoptString(curl, CurlOpt.COOKIELIST, cookie);
  }

  // Set Timeout, Redirects, SSL verification, Proxy
  lib.setoptInt(curl, CurlOpt.TIMEOUT, (payload.timeoutMs / 1000).round());
  lib.setoptInt(curl, CurlOpt.CONNECTTIMEOUT, (payload.timeoutMs / 1000).round());
  lib.setoptInt(curl, CurlOpt.FOLLOWLOCATION, payload.followRedirects ? 1 : 0);
  lib.setoptInt(curl, CurlOpt.MAXREDIRS, payload.maxRedirects);
  lib.setoptInt(curl, CurlOpt.SSL_VERIFYPEER, payload.verify ? 1 : 0);
  lib.setoptInt(curl, CurlOpt.SSL_VERIFYHOST, payload.verify ? 2 : 0);
  if (payload.caBundlePath != null && payload.verify) {
    lib.setoptString(curl, CurlOpt.CAINFO, payload.caBundlePath!);
  }

  if (payload.proxy != null) {
    lib.setoptString(curl, CurlOpt.PROXY, payload.proxy!);
  }

  // Automatically decompress HTTP responses (gzip, deflate, br, zstd, etc.)
  lib.setoptString(curl, CurlOpt.ACCEPT_ENCODING, '');

  final responseHeaders = <String, String>{};
  final responseBody = <int>[];

  // Callback implementations
  int headerCallback(ffi.Pointer<ffi.Uint8> ptr, int size, int nmemb, ffi.Pointer<ffi.Void> userdata) {
    final len = size * nmemb;
    final bytes = ptr.asTypedList(len);
    final line = utf8.decode(bytes, allowMalformed: true);
    final colonIdx = line.indexOf(':');
    if (colonIdx != -1) {
      final key = line.substring(0, colonIdx).trim().toLowerCase();
      final val = line.substring(colonIdx + 1).trim();
      responseHeaders[key] = val;
    }
    return len;
  }

  int writeCallback(ffi.Pointer<ffi.Uint8> ptr, int size, int nmemb, ffi.Pointer<ffi.Void> userdata) {
    final len = size * nmemb;
    final bytes = ptr.asTypedList(len);
    responseBody.addAll(bytes);
    return len;
  }

  // Bind Native Callables
  final headerCallable = ffi.NativeCallable<CurlWriteCallbackNative>.isolateLocal(headerCallback, exceptionalReturn: 0);
  final writeCallable = ffi.NativeCallable<CurlWriteCallbackNative>.isolateLocal(writeCallback, exceptionalReturn: 0);

  lib.setoptFunc(curl, CurlOpt.HEADERFUNCTION, headerCallable.nativeFunction.cast<ffi.Void>());
  lib.setoptFunc(curl, CurlOpt.WRITEFUNCTION, writeCallable.nativeFunction.cast<ffi.Void>());

  // Perform Request
  final performCode = lib.easyPerform(curl);

  _CurlResponseResult result;
  if (performCode != 0) {
    result = (
      statusCode: 0,
      headers: {},
      bodyBytes: [],
      cookies: [],
      effectiveUrl: payload.url,
      error: 'Curl error code: $performCode',
    );
  } else {
    final statusCode = lib.getInfoLong(curl, CurlInfo.RESPONSE_CODE);
    final effectiveUrl = lib.getInfoString(curl, CurlInfo.EFFECTIVE_URL) ?? payload.url;
    final cookies = lib.getInfoCookieList(curl);

    result = (
      statusCode: statusCode,
      headers: responseHeaders,
      bodyBytes: responseBody,
      cookies: cookies,
      effectiveUrl: effectiveUrl,
      error: null,
    );
  }

  // Clean up
  if (headerList.address != 0) {
    lib.slistFreeAll(headerList);
  }
  if (bodyPtr.address != 0) {
    malloc.free(bodyPtr);
  }
  headerCallable.close();
  writeCallable.close();
  lib.easyCleanup(curl);

  return result;
}

class CurlImpersonateClient extends http.BaseClient {
  final String? defaultImpersonate;
  final Duration timeout;
  final bool verify;
  final String? proxy;
  List<String> _cookies = [];

  static String? _caBundlePath;
  static bool _caDownloading = false;

  static Future<void> _initCaBundle() async {
    if (_caBundlePath != null) return;
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/cacert.pem');
    if (file.existsSync() && file.lengthSync() > 0) {
      _caBundlePath = file.path;
      return;
    }
    if (_caDownloading) return;
    _caDownloading = true;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://curl.se/ca/cacert.pem'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final sink = file.openWrite();
        await response.pipe(sink);
        _caBundlePath = file.path;
      }
    } catch (_) {
    } finally {
      _caDownloading = false;
    }
  }

  late final http.Client _fallbackClient;
  bool _useFallback = false;

  CurlImpersonateClient({
    this.defaultImpersonate = BrowserProfile.chrome,
    this.timeout = const Duration(seconds: 30),
    this.verify = true,
    this.proxy,
  }) {
    try {
      // Force init to check if platform supports dynamic FFI loading
      LibCurl.instance;
    } catch (_) {
      _useFallback = true;
      _fallbackClient = http.Client();
    }
  }

  bool get isNative => !_useFallback;

  List<String> get cookies => _cookies;
  set cookies(List<String> val) => _cookies = val;

  @override
  void close() {
    _cookies.clear();
    if (_useFallback) {
      _fallbackClient.close();
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_useFallback) {
      return _fallbackClient.send(request);
    }

    await _initCaBundle();
    final streamBytes = await request.finalize().toBytes();
    
    final payload = _CurlRequestPayload(
      url: request.url.toString(),
      method: request.method,
      impersonate: defaultImpersonate,
      headers: request.headers,
      bodyBytes: streamBytes,
      initialCookies: _cookies,
      timeoutMs: timeout.inMilliseconds,
      followRedirects: request.followRedirects,
      maxRedirects: request.maxRedirects,
      proxy: proxy,
      verify: verify,
      caBundlePath: _caBundlePath,
    );

    final result = await Isolate.run(() => _executeRequestInIsolate(payload));

    if (result.error != null) {
      throw http.ClientException(result.error!, request.url);
    }

    _cookies = result.cookies;

    final controller = StreamController<List<int>>();
    controller.add(result.bodyBytes);
    unawaited(controller.close());

    return http.StreamedResponse(
      controller.stream,
      result.statusCode,
      contentLength: result.bodyBytes.length,
      request: request,
      headers: result.headers,
    );
  }

  Future<CurlResponse> request({
    required String url,
    required String method,
    String? impersonate,
    Map<String, String>? headers,
    List<int>? bodyBytes,
    String? body,
    Map<String, String>? bodyFields,
    Duration? timeout,
    bool followRedirects = true,
    int maxRedirects = 5,
    bool? verify,
    String? proxy,
  }) async {
    if (_useFallback) {
      final uri = Uri.parse(url);
      final req = http.Request(method, uri);

      if (headers != null) req.headers.addAll(headers);
      if (_cookies.isNotEmpty) {
        final cookieHeader = _cookies.map((c) {
          final idx = c.indexOf(';');
          return idx != -1 ? c.substring(0, idx) : c;
        }).join('; ');
        req.headers['cookie'] = cookieHeader;
      }
      if (bodyBytes != null) {
        req.bodyBytes = bodyBytes;
      } else if (bodyFields != null) {
        req.bodyFields = bodyFields;
      } else if (body != null) {
        req.body = body;
      }

      req.followRedirects = followRedirects;
      req.maxRedirects = maxRedirects;

      final res = await _fallbackClient.send(req);
      final httpResponse = await http.Response.fromStream(res);

      final setCookie = httpResponse.headers['set-cookie'];
      if (setCookie != null) {
        _cookies.add(setCookie);
      }

      return CurlResponse(
        statusCode: httpResponse.statusCode,
        headers: httpResponse.headers,
        bodyBytes: httpResponse.bodyBytes,
        cookies: _cookies,
        effectiveUrl: url,
      );
    }

    await _initCaBundle();
    final finalHeaders = headers != null ? Map<String, String>.from(headers) : <String, String>{};
    List<int>? finalBodyBytes = bodyBytes;

    if (bodyFields != null) {
      final parts = <String>[];
      bodyFields.forEach((key, val) {
        parts.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(val)}');
      });
      finalBodyBytes = utf8.encode(parts.join('&'));
      finalHeaders['content-type'] = 'application/x-www-form-urlencoded';
    } else if (body != null) {
      finalBodyBytes = utf8.encode(body);
    }

    final payload = _CurlRequestPayload(
      url: url,
      method: method,
      impersonate: impersonate ?? defaultImpersonate,
      headers: finalHeaders,
      bodyBytes: finalBodyBytes,
      initialCookies: _cookies,
      timeoutMs: (timeout ?? this.timeout).inMilliseconds,
      followRedirects: followRedirects,
      maxRedirects: maxRedirects,
      proxy: proxy ?? this.proxy,
      verify: verify ?? this.verify,
      caBundlePath: _caBundlePath,
    );

    final result = await Isolate.run(() => _executeRequestInIsolate(payload));

    if (result.error != null) {
      throw http.ClientException(result.error!, Uri.parse(url));
    }

    _cookies = result.cookies;

    return CurlResponse(
      statusCode: result.statusCode,
      headers: result.headers,
      bodyBytes: result.bodyBytes,
      cookies: result.cookies,
      effectiveUrl: result.effectiveUrl,
    );
  }

  Map<String, String> getCookieMapForDomain(String domain) {
    final map = <String, String>{};
    for (final line in _cookies) {
      final parts = line.split('\t');
      if (parts.length >= 7) {
        var hostname = parts[0];
        if (hostname.startsWith('#HttpOnly_')) {
          hostname = hostname.substring(10);
        }
        if (domain.contains(hostname) || hostname.contains(domain)) {
          final name = parts[5];
          final val = parts[6];
          map[name] = val;
        }
      } else {
        // Fallback cookie parse style for standard response cookies
        final parts = line.split(';');
        if (parts.isNotEmpty) {
          final pair = parts[0].split('=');
          if (pair.length == 2) {
            map[pair[0].trim()] = pair[1].trim();
          }
        }
      }
    }
    return map;
  }
}
