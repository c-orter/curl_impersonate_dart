# curl_impersonate_dart

A Dart and Flutter library providing browser impersonation features (TLS and HTTP/2 fingerprinting) using `libcurl-impersonate`. It is designed as a drop-in replacement for `package:http`.

This library helps you bypass bot detection systems (such as Cloudflare, Akamai, Datadome, etc.) by mimicking the TLS Client Hello signatures and HTTP/2 settings of popular web browsers.

## Target Platform Support

* **Android:** Full Impersonation FFI (downloads and bundles `.so` binaries automatically).
* **iOS:** Full Impersonation FFI (downloads and bundles `.xcframework` automatically via CocoaPods).
* **Desktop Development Fallback:** Automatically falls back to standard HTTP clients (`package:http`) on macOS, Windows, and Linux to allow testing and development without app crashes.

---

## Features

* **Drop-in `package:http` compatibility:** Implements `http.BaseClient` so you can use standard Dart HTTP APIs.
* **Worker Isolates:** Requests run asynchronously inside background Isolates to prevent blocking Flutter's main UI thread.
* **Cookie Persistence:** Out-of-the-box cookie engine synchronization across subsequent requests and redirects.
* **HTTP/2 & TLS Fingerprinting:** Choose from pre-configured targets (Chrome, Firefox, Safari, Edge) or target specific mobile operating systems.
* **Automatic Decompression:** Handles compressed response content (Gzip, Deflate, Brotli, Zstd) automatically.
* **Proxy and SSL Controls:** Easily configure HTTP/Socks proxies and toggle peer verification.

---

## Installation

Add `curl_impersonate_dart` to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  curl_impersonate_dart:
    path: /path/to/curl_impersonate_dart  # Or standard pub git reference
```

### Native Setup

#### Android
No additional setup is required. The library automatically fetches the appropriate `libcurl-impersonate.so` binaries for `arm64-v8a` and `x86_64` during your Gradle build and packages them within the final APK.

#### iOS
Run `pod install` in your Flutter project's `ios` directory:
```bash
cd ios
pod install
```
This automatically fetches the prebuilt static framework framework and compiles the necessary calling convention alignment shims.

---

## Usage

### Basic GET and POST requests

You can use the high-level `request()` helper to perform calls and parse responses.

```dart
import 'package:curl_impersonate_dart/curl_impersonate_dart.dart';

void main() async {
  // Initialize the client (defaults to Chrome impersonation)
  final client = CurlImpersonateClient(
    defaultImpersonate: BrowserProfile.chrome,
    timeout: Duration(seconds: 15),
  );

  try {
    // 1. Basic GET request
    final getRes = await client.request(
      url: 'https://httpbin.org/headers',
      method: 'GET',
    );
    print('Status: ${getRes.statusCode}');
    print('Headers: ${getRes.headers}');
    print('Body: ${getRes.body}');
    print('JSON: ${getRes.json}');

    // 2. POST request with custom profile (Safari)
    final postRes = await client.request(
      url: 'https://httpbin.org/post',
      method: 'POST',
      impersonate: BrowserProfile.safari,
      body: 'hello world',
      headers: {'Content-Type': 'text/plain'},
    );
    print('POST response: ${postRes.body}');
    
    // 3. Form URL-Encoded request
    final formRes = await client.request(
      url: 'https://httpbin.org/post',
      method: 'POST',
      bodyFields: {'username': 'johndoe', 'token': 'xyz'},
    );
    print('Form response: ${formRes.body}');
  } finally {
    client.close();
  }
}
```

### Cookie Persistence

Cookies returned by a request are automatically stored in memory and attached to subsequent requests targeting the same domain.

```dart
final client = CurlImpersonateClient();

// Set cookie
await client.request(
  url: 'https://httpbin.org/cookies/set?session_id=123456',
  method: 'GET',
);

// Read back cookie
final response = await client.request(
  url: 'https://httpbin.org/cookies',
  method: 'GET',
);
print(response.body); // Will print {"cookies": {"session_id": "123456"}}

// Extract specific cookies manually
final domainCookies = client.getCookieMapForDomain('httpbin.org');
print('Session ID: ${domainCookies['session_id']}');

client.close();
```

### Drop-in package:http `BaseClient` Integration

Since `CurlImpersonateClient` extends `http.BaseClient`, you can pass it directly to any package that accepts a standard `http.Client`.

```dart
final client = CurlImpersonateClient(defaultImpersonate: BrowserProfile.firefox);

final response = await client.get(Uri.parse('https://httpbin.org/get'));
print(response.body);

client.close();
```

---

## Configuration Options

When creating a client, you can configure several default parameters:

```dart
final client = CurlImpersonateClient(
  defaultImpersonate: BrowserProfile.chrome, // Impersonation profile
  timeout: Duration(seconds: 30),            // Default request timeout
  verify: true,                              // SSL verification
  proxy: 'socks5h://127.0.0.1:9050',         // SOCKS5/HTTP Proxy URL
);
```

### Supported Impersonation Profiles

Available profiles defined in `BrowserProfile`:

* `BrowserProfile.chrome` (Chrome Desktop)
* `BrowserProfile.chromeAndroid` (Chrome Android)
* `BrowserProfile.firefox` (Firefox Desktop)
* `BrowserProfile.safari` (Safari Desktop)
* `BrowserProfile.safariIos` (Safari iOS)
* `BrowserProfile.edge` (Edge Desktop)

---

## Native Architecture & FFI Calling Convention Details

To maintain compatibility with various system architectures, the package wraps FFI in specific ways:

1. **Android calling convention:** Direct register FFI call mappings.
2. **iOS calling convention:** iOS on Apple Silicon utilizes a custom ARM64 calling convention where variadic parameters (like `curl_easy_setopt`) are always passed on the stack instead of CPU registers. To accommodate this, the package uses a lightweight compiled C shim (`ios/Classes/shim.c`) that bridges standard register-based FFI arguments into stack-aligned arguments expected by iOS `libcurl`.
3. **Cross-Platform fallback:** The `isNative` getter verifies if FFI bindings successfully loaded. Non-mobile systems will transparently run standard HTTP clients under the hood, ensuring developers can test their code on local systems before publishing to device simulators or staging environments.
