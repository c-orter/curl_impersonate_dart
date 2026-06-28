import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';
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
      final version = LibCurl.instance.version().toDartString();
      print('Underlying LibCurl Version: $version');
      expect(version, isNotEmpty);
      expect(version.toLowerCase(), contains('impersonate'));
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
