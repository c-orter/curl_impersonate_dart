# curl_impersonate_dart

A Dart and Flutter library providing browser impersonation features (TLS and HTTP/2 fingerprinting) using `libcurl-impersonate`. It is designed as a drop-in replacement for `package:http`.

This library helps you bypass bot detection systems (such as Cloudflare, Akamai, Datadome, etc.) by mimicking the TLS Client Hello signatures and HTTP/2 settings of popular web browsers.

## Target Platform Support

* **Android:** Full Impersonation FFI (downloads and bundles `.so` binaries automatically). Requires API 21+.
* **iOS:** Full Impersonation FFI (downloads and bundles `.xcframework` automatically via CocoaPods). Requires iOS 13+.
* **Desktop Development Fallback:** Automatically falls back to standard HTTP clients (`package:http`) on macOS, Windows, and Linux to allow testing and development without app crashes.

---

## Upstream

This package bundles **libcurl-impersonate v2.2.3**, which is based on **curl 8.22.0**.

The version is pinned in exactly two places, which must be kept in sync when upgrading:

* `android/build.gradle` → `ext.curlImpersonateVersion`
* `ios/curl_impersonate_dart.podspec` → the `prepare_command` download URL

### Upgrading

1. Bump the version in both files above.
2. Delete any previously downloaded binaries (the Gradle task keeps a
   `.curl-impersonate-version` stamp per ABI and will re-download automatically,
   but `android/build` and `ios/Pods` may hold stale artifacts):
   ```bash
   rm -rf android/src/main/jniLibs android/build ios/Pods
   ```

### Notable upstream changes since v1.5.6

* curl updated to **8.22.0**.
* **`chrome150`** target added. `BrowserProfile.chrome` now points at it.
* `CURLOPT_IMPERSONATE` and 33 further fingerprint-tuning options are exposed
  through `CurlOpt` — override individual TLS/HTTP2/HTTP3 attributes instead of
  taking whatever the profile ships with.
* `CURLINFO_REDIRECT_HISTORY` (`CurlInfo.REDIRECT_HISTORY`) exposes the headers of
  each redirect response followed.
* HTTP/3 and QUIC fingerprints are available. Only `chrome145`, `chrome146`,
  `chrome150` and `firefox147` carry them — see `BrowserProfile.supportsHttp3`.

The `curl_easy_impersonate` C signature and all existing `CURLOPT`/`CURLINFO`
numeric values are unchanged from v1.5.6, so existing code keeps working.

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

`BrowserProfile` exposes every target the pinned release supports. Prefer the
`BrowserProfile.values` list or `validateProfile()` over hand-written strings —
an unknown target is rejected before it can reach the native layer.

* **Chrome Desktop:** `chrome99`, `chrome100`, `chrome101`, `chrome104`,
  `chrome107`, `chrome110`, `chrome116`, `chrome119`, `chrome120`, `chrome123`,
  `chrome124`, `chrome131`, `chrome133a`, `chrome136`, `chrome142`, `chrome145`,
  `chrome146`, `chrome150`
* **Chrome Mobile:** `chrome99_android`, `chrome131_android`
* **Edge:** `edge99`, `edge101`
* **Firefox:** `firefox133`, `firefox135`, `firefox144`, `firefox147`
* **Safari Desktop:** `safari153`, `safari155`, `safari170`, `safari180`,
  `safari184`, `safari260`, `safari2601`
* **Safari iOS:** `safari172_ios`, `safari180_ios`, `safari184_ios`, `safari260_ios`
* **Tor:** `tor145`

Notes carried over from upstream:

* Chromium-based browsers share one fingerprint apart from `User-Agent` and
  `sec-ch-ua-platform`, so impersonating `edge*` or `chrome*_android` usually
  needs your own headers.
* The `-a` suffix (`chrome133a`) marks an alternative fingerprint observed in the
  wild via A/B testing, not an official browser release.

### Fingerprint Tuning

Each impersonate profile sets roughly forty TLS and HTTP/2 attributes in one call.
Since libcurl-impersonate v2.0.0 they are individually overridable, so you can
change just the ones you need:

```dart
final client = CurlImpersonateClient(
  defaultImpersonate: BrowserProfile.chrome150,
  overrides: const FingerprintOverrides(
    grease: false,
    certCompression: 'brotli',
    http2PseudoHeadersOrder: 'masp',
  ),
);

// Layer a per-request patch over the client defaults (non-destructive).
await client.request(
  url: 'https://example.com',
  method: 'GET',
  requestOverrides: const FingerprintOverrides(splitCookies: true),
);
```

Overrides are applied *after* the impersonate profile and after your headers, so
they win over both. `null` means "keep the profile default".

> A fingerprint is scored as a *whole*. Overriding one attribute to a value no
> real browser emits tends to make detection easier, not harder — change only
> what you have evidence about.

See **[docs/fingerprint-tuning.md](docs/fingerprint-tuning.md)** for a full
per-option breakdown and worked scraping scenarios.

### Introspecting the Bundled Library

```dart
final client = CurlImpersonateClient();
print(client.curlVersion);          // e.g. 8.22.0-IMPERSONATE, null on desktop
print(BrowserProfile.supportsHttp3(BrowserProfile.chrome150)); // true

// Fails fast with a readable message instead of silently requesting unimpersonated.
CurlImpersonateClient.validateProfile('chrome999'); // throws ArgumentError
client.close();
```

---

## Native Architecture & FFI Calling Convention Details

To maintain compatibility with various system architectures, the package wraps FFI in specific ways:

1. **Android calling convention:** Direct register FFI call mappings.
2. **iOS calling convention:** iOS on Apple Silicon utilizes a custom ARM64 calling convention where variadic parameters (like `curl_easy_setopt`) are always passed on the stack instead of CPU registers. To accommodate this, the package uses a lightweight compiled C shim (`ios/Classes/shim.c`) that bridges standard register-based FFI arguments into stack-aligned arguments expected by iOS `libcurl`.
3. **Cross-Platform fallback:** The `isNative` getter verifies if FFI bindings successfully loaded. Non-mobile systems will transparently run standard HTTP clients under the hood, ensuring developers can test their code on local systems before publishing to device simulators or staging environments.
