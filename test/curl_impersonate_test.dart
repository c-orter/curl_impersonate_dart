import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:curl_impersonate_dart/curl_impersonate_dart.dart';
import 'package:curl_impersonate_dart/src/curl_ffi.dart';

void main() {
  late HttpServer server;
  late String serverUrl;

  setUpAll(() async {
    // Start local server on a random port
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://127.0.0.1:${server.port}';

    server.listen((HttpRequest request) async {
      final response = request.response;

      // Parse request body
      final bodyBytes = await request.fold<List<int>>([], (a, b) => a..addAll(b));
      final bodyStr = utf8.decode(bodyBytes);

      print('LocalServer: Request Method: ${request.method}, Path: ${request.uri.path}');
      print('LocalServer: Body Bytes Length: ${bodyBytes.length}');
      print('LocalServer: Body Content: "$bodyStr"');

      if (request.uri.path == '/get') {
        response.headers.contentType = ContentType.json;
        final headersMap = <String, String>{};
        request.headers.forEach((name, values) {
          headersMap[name] = values.join(', ');
        });

        response.write(jsonEncode({
          'headers': headersMap,
          'method': request.method,
        }));
      } else if (request.uri.path == '/post') {
        response.headers.contentType = ContentType.json;
        final headersMap = <String, String>{};
        request.headers.forEach((name, values) {
          headersMap[name] = values.join(', ');
        });

        var form = <String, String>{};
        if (request.headers.value('content-type')?.contains('application/x-www-form-urlencoded') == true) {
          final decoded = Uri.splitQueryString(bodyStr);
          form = decoded;
        }

        response.write(jsonEncode({
          'data': bodyStr,
          'method': request.method,
          'form': form,
          'headers': headersMap,
        }));
      } else if (request.uri.path == '/cookies/set') {
        final token = request.uri.queryParameters['token'];
        response.statusCode = 302;
        response.headers.add('set-cookie', 'token=$token; Path=/; HttpOnly');
        response.headers.set('location', '/cookies');
      } else if (request.uri.path == '/cookies') {
        final cookieHeader = request.headers.value('cookie') ?? '';
        final cookies = <String, String>{};
        if (cookieHeader.isNotEmpty) {
          final parts = cookieHeader.split(';');
          for (final part in parts) {
            final eq = part.indexOf('=');
            if (eq != -1) {
              cookies[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
            }
          }
        }
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'cookies': cookies}));
      } else {
        response.statusCode = 404;
      }

      await response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  group('LibCurl Core & Loader Tests', () {
    test('LibCurl version getter', () {
      final isSupported = Platform.isAndroid || Platform.isIOS;
      if (!isSupported) {
        print('Skipping native FFI test on unsupported platform: ${Platform.operatingSystem}');
        return;
      }
      final version = LibCurl.instance.versionString;
      print('Underlying LibCurl Version: $version');
      expect(version, isNotEmpty);
      expect(version.toLowerCase(), contains('impersonate'));
    });
  });

  // These assert against the pinned libcurl-impersonate release's headers and
  // therefore run on every platform, including the desktop fallback.
  group('Upstream constant & profile parity', () {
    test('option and info codes match upstream header values', () {
      // Numeric values are compiled into upstream curl.h as `type + num`.
      // A silent shift here would misdirect every setopt call at runtime.
      expect(CurlOpt.URL, equals(10002));
      expect(CurlOpt.WRITEFUNCTION, equals(20011));
      expect(CurlOpt.HEADERFUNCTION, equals(20079));
      expect(CurlOpt.POSTFIELDS, equals(10015));
      expect(CurlOpt.ACCEPT_ENCODING, equals(10102));
      expect(CurlOpt.COOKIELIST, equals(10135));
      expect(CurlOpt.PROXY_CAINFO, equals(10246));

      expect(CurlInfo.EFFECTIVE_URL, equals(0x100000 + 1));
      expect(CurlInfo.RESPONSE_CODE, equals(0x200000 + 2));
      expect(CurlInfo.COOKIELIST, equals(0x400000 + 28));

      // New in libcurl-impersonate v2.x.
      expect(CurlOpt.IMPERSONATE, equals(10999));
      expect(CurlInfo.REDIRECT_HISTORY, equals(0x400000 + 1001));
      expect(CurlOpt.TLS_TRUST_ANCHORS, equals(11040));
      expect(CurlOpt.QUIC_INITIAL_PACKET_NUMBER, equals(1041));
    });

    test('profile list covers the pinned upstream release', () {
      // chrome150 arrived in v2.1.0; chrome133a/tor145 were never exposed.
      expect(BrowserProfile.chrome150, equals('chrome150'));
      expect(BrowserProfile.chrome, equals('chrome150'));
      expect(BrowserProfile.chrome133a, equals('chrome133a'));
      expect(BrowserProfile.tor145, equals('tor145'));

      expect(BrowserProfile.values, contains(BrowserProfile.chrome150));
      expect(BrowserProfile.values, contains(BrowserProfile.chrome99Android));
      expect(BrowserProfile.values, contains(BrowserProfile.safari260Ios));
      // Every entry must be a distinct, non-empty target name.
      expect(BrowserProfile.values.toSet().length, equals(BrowserProfile.values.length));
      expect(BrowserProfile.values.any((p) => p.isEmpty), isFalse);
    });

    test('HTTP/3 capability list matches upstream H3 fingerprints', () {
      expect(BrowserProfile.supportsHttp3(BrowserProfile.chrome150), isTrue);
      expect(BrowserProfile.supportsHttp3(BrowserProfile.firefox147), isTrue);
      expect(BrowserProfile.supportsHttp3(BrowserProfile.chrome142), isFalse);
      expect(BrowserProfile.supportsHttp3(BrowserProfile.safari), isFalse);
    });

    test('validateProfile rejects unknown targets and accepts known ones', () {
      expect(() => CurlImpersonateClient.validateProfile('chrome150'), returnsNormally);
      expect(
        () => CurlImpersonateClient.validateProfile('chrome999'),
        throwsA(isA<ArgumentError>()),
      );
      // A malformed profile must not reach the native layer silently.
      expect(
        () => CurlImpersonateClient.validateProfile(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CurlImpersonateClient Request Tests', () {
    late CurlImpersonateClient client;

    setUp(() {
      client = CurlImpersonateClient(defaultImpersonate: BrowserProfile.chrome);
    });

    tearDown(() {
      client.close();
    });

    test('Perform basic GET request', () async {
      final response = await client.request(
        url: '$serverUrl/get',
        method: 'GET',
      );
      expect(response.statusCode, equals(200));
      expect(response.body, contains('headers'));
    });

    test('Perform POST request with body', () async {
      final response = await client.request(
        url: '$serverUrl/post',
        method: 'POST',
        body: 'hello world',
        headers: {'content-type': 'text/plain'},
      );
      expect(response.statusCode, equals(200));
      expect(response.json['data'], equals('hello world'));
    });

    test('Perform urlencoded POST request', () async {
      final response = await client.request(
        url: '$serverUrl/post',
        method: 'POST',
        bodyFields: {'name': 'test_user', 'value': '123'},
      );
      expect(response.statusCode, equals(200));
      expect(response.json['form']['name'], equals('test_user'));
      expect(response.json['form']['value'], equals('123'));
    });

    test('Cookie persistence across requests', () async {
      // Set a cookie (disabling automatic redirect so we can test the session cookie storage)
      final setResponse = await client.request(
        url: '$serverUrl/cookies/set?token=abcdef',
        method: 'GET',
        followRedirects: false,
      );
      expect(setResponse.statusCode, equals(302));

      // Get cookies to see if they are sent back
      final getResponse = await client.request(
        url: '$serverUrl/cookies',
        method: 'GET',
      );
      expect(getResponse.statusCode, equals(200));
      expect(getResponse.json['cookies']['token'], equals('abcdef'));
    });

    test('Impersonate Firefox profile', () async {
      final response = await client.request(
        url: '$serverUrl/get',
        method: 'GET',
        impersonate: BrowserProfile.firefox,
      );
      expect(response.statusCode, equals(200));
    });

    test('Impersonate Safari profile', () async {
      final response = await client.request(
        url: '$serverUrl/get',
        method: 'GET',
        impersonate: BrowserProfile.safari,
      );
      expect(response.statusCode, equals(200));
    });

    test('Live GET request stability verification', () async {
      final response = await client.request(
        url: 'https://www.google.com',
        method: 'GET',
      );
      expect(response.statusCode, equals(200));
      expect(response.body, contains('Google'));
    });
  });
}
