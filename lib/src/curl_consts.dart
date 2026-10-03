// Option codes, info codes, and impersonation profiles for libcurl.
//
// Values are derived from the upstream libcurl-impersonate headers and verified
// against the bundled `include/curl/curl.h` of the pinned release. The upstream
// numbering scheme is `CURLOPT(name, type, num) = type + num`, which has been
// stable across the 1.x -> 2.x upgrade.
class CurlOpt {
  static const int WRITEDATA = 10001;
  static const int URL = 10002;
  static const int PORT = 3;
  static const int PROXY = 10004;
  static const int READDATA = 10009;
  static const int WRITEFUNCTION = 20011;
  static const int READFUNCTION = 20012;
  static const int TIMEOUT = 13;
  static const int POSTFIELDS = 10015;
  static const int REFERER = 10016;
  static const int USERAGENT = 10018;
  static const int COOKIE = 10022;
  static const int HTTPHEADER = 10023;
  static const int HEADERDATA = 10029;
  static const int COOKIEFILE = 10031;
  static const int SSLVERSION = 32;
  static const int CUSTOMREQUEST = 10036;
  static const int VERBOSE = 41;
  static const int HEADER = 42;
  static const int NOPROGRESS = 43;
  static const int UPLOAD = 46;
  static const int POST = 47;
  static const int FOLLOWLOCATION = 52;
  static const int POSTFIELDSIZE = 60;
  static const int SSL_VERIFYPEER = 64;
  static const int CAINFO = 10065;
  static const int MAXREDIRS = 68;
  static const int CONNECTTIMEOUT = 78;
  static const int HEADERFUNCTION = 20079;
  static const int SSL_VERIFYHOST = 81;
  static const int COOKIEJAR = 10082;
  static const int HTTP_VERSION = 84;
  static const int ACCEPT_ENCODING = 10102;
  static const int COOKIELIST = 10135;
  static const int PROXY_CAINFO = 10246;

  // --- curl-impersonate fingerprint tuning (v2.x) ---
  //
  // These let you override individual parts of an impersonated profile instead
  // of having to take whatever the profile ships with. Every one of these is
  // applied *after* CURLOPT.IMPERSONATE and wins over it.
  static const int IMPERSONATE = 10999; // stringpoint, "name[:yes|no]"
  static const int HTTPBASEHEADER = 11000; // slist
  static const int SSL_SIG_HASH_ALGS = 11001; // stringpoint
  static const int SSL_ENABLE_ALPS = 1002; // long
  static const int SSL_CERT_COMPRESSION = 11003; // stringpoint
  static const int SSL_ENABLE_TICKET = 1004; // long
  static const int HTTP2_PSEUDO_HEADERS_ORDER = 11005; // stringpoint
  static const int HTTP2_SETTINGS = 11006; // stringpoint, "1:v;2:v;3:v"
  static const int SSL_PERMUTE_EXTENSIONS = 1007; // long
  static const int HTTP2_WINDOW_UPDATE = 1008; // long
  static const int HTTP2_STREAMS = 11010; // stringpoint
  static const int TLS_GREASE = 1011; // long
  static const int TLS_EXTENSION_ORDER = 11012; // stringpoint
  static const int TLS_KEY_USAGE_NO_CHECK = 1014; // long
  static const int TLS_SIGNED_CERT_TIMESTAMPS = 1015; // long
  static const int TLS_STATUS_REQUEST = 1016; // long
  static const int TLS_DELEGATED_CREDENTIALS = 11017; // stringpoint
  static const int TLS_RECORD_SIZE_LIMIT = 1018; // long
  static const int TLS_KEY_SHARES_LIMIT = 1019; // long
  static const int TLS_USE_NEW_ALPS_CODEPOINT = 1020; // long
  static const int HTTP2_NO_PRIORITY = 1021; // long
  static const int STREAM_EXCLUSIVE = 1013; // long
  static const int PROXY_CREDENTIAL_NO_REUSE = 1022; // long
  static const int SPLIT_COOKIES = 1023; // long
  static const int FORM_BOUNDARY = 11024; // stringpoint
  static const int HTTPHEADER_ORDER = 11030; // stringpoint
  static const int HTTP3_PSEUDO_HEADERS_ORDER = 11025; // stringpoint
  static const int HTTP3_SETTINGS = 11026; // stringpoint
  static const int QUIC_TRANSPORT_PARAMETERS = 11027; // stringpoint
  static const int HTTP3_SIG_HASH_ALGS = 11028; // stringpoint
  static const int HTTP3_TLS_EXTENSION_ORDER = 11029; // stringpoint
  static const int HTTP3_HTTPHEADER = 11031; // slist
  static const int HTTP3_HTTPHEADER_ORDER = 11032; // stringpoint
  static const int HTTP3_SSL_EC_CURVES = 11033; // stringpoint
  static const int WS_HTTPHEADER = 11034; // slist
  static const int WS_HTTPHEADER_ORDER = 11035; // stringpoint
  static const int WS_SSL_DISABLE_TICKET = 1036; // long
  static const int WS_SSL_CERT_COMPRESSION = 11037; // stringpoint
  static const int QUIC_CID_LENGTH = 11038; // stringpoint
  static const int HTTP3_SSL_PERMUTE_EXTENSIONS = 1039; // long
  static const int TLS_TRUST_ANCHORS = 11040; // stringpoint
  static const int QUIC_INITIAL_PACKET_NUMBER = 1041; // long
}

class CurlInfo {
  static const int EFFECTIVE_URL = 0x100000 + 1; // 1048577
  static const int RESPONSE_CODE = 0x200000 + 2; // 2097154
  static const int HEADER_SIZE = 0x200000 + 11; // 2097163
  static const int COOKIELIST = 0x400000 + 28; // 4194332
  static const int REDIRECT_URL = 0x100000 + 31; // 1048607
  static const int REDIRECT_COUNT = 0x200000 + 20; // 2097172

  /// Headers of the individual redirect responses followed on the most recent
  /// transfer (curl-impersonate v2.0.0rc4+). Returns a `curl_slist *`.
  static const int REDIRECT_HISTORY = 0x400000 + 1001; // 4195305
}

class CurlVersion {
  static const int NONE = 0;
  static const int HTTP1_0 = 1;
  static const int HTTP1_1 = 2;
  static const int HTTP2_0 = 3;
  static const int HTTP3 = 4;
}

/// Impersonation targets supported by the pinned libcurl-impersonate release.
///
/// The authoritative list is the set of `bin/curl_*` wrapper scripts in the
/// upstream repo. Two notes carried over from upstream:
///
///  * Chromium-based targets share one fingerprint apart from `User-Agent` and
///    `sec-ch-ua-platform`, so `edge*` and `chrome*_android` are aliases you may
///    need to override with your own headers.
///  * The `-a` suffix (e.g. `chrome133a`) marks an alternative fingerprint
///    observed in the wild via A/B testing, not an official browser release.
///
/// Only [chrome145], [chrome146], [chrome150] and [firefox147] carry HTTP/3 and
/// QUIC fingerprints; see [http3Capable].
class BrowserProfile {
  /// Profiles that carry a matching HTTP/3 (QUIC) fingerprint upstream.
  static const Set<String> http3Capable = {
    'chrome145',
    'chrome146',
    'chrome150',
    'firefox147',
  };

  static bool supportsHttp3(String profile) => http3Capable.contains(profile);

  // Edge
  static const String edge99 = 'edge99';
  static const String edge101 = 'edge101';
  static const String edge = 'edge101'; // Default Edge alias

  // Chrome Desktop
  static const String chrome99 = 'chrome99';
  static const String chrome100 = 'chrome100';
  static const String chrome101 = 'chrome101';
  static const String chrome104 = 'chrome104';
  static const String chrome107 = 'chrome107';
  static const String chrome110 = 'chrome110';
  static const String chrome116 = 'chrome116';
  static const String chrome119 = 'chrome119';
  static const String chrome120 = 'chrome120';
  static const String chrome123 = 'chrome123';
  static const String chrome124 = 'chrome124';
  static const String chrome131 = 'chrome131';

  /// Alternative chrome131 fingerprint observed via A/B testing.
  static const String chrome133a = 'chrome133a';

  static const String chrome136 = 'chrome136';
  static const String chrome142 = 'chrome142';
  static const String chrome145 = 'chrome145';
  static const String chrome146 = 'chrome146';

  /// New in libcurl-impersonate v2.1.0. BoringSSL is pinned to the Chrome 150
  /// profile upstream, so this is the most current Chrome fingerprint available.
  static const String chrome150 = 'chrome150';

  static const String chrome = 'chrome150'; // Default Chrome alias

  // Chrome Mobile
  static const String chrome99Android = 'chrome99_android';
  static const String chrome131Android = 'chrome131_android';
  static const String chromeAndroid = 'chrome131_android'; // Default Chrome Android alias

  // Firefox
  static const String firefox133 = 'firefox133';
  static const String firefox135 = 'firefox135';
  static const String firefox144 = 'firefox144';
  static const String firefox147 = 'firefox147';
  static const String firefox = 'firefox147'; // Default Firefox alias

  // Safari Desktop
  static const String safari153 = 'safari153';
  static const String safari155 = 'safari155';
  static const String safari170 = 'safari170';
  static const String safari180 = 'safari180';
  static const String safari184 = 'safari184';
  static const String safari260 = 'safari260';
  static const String safari2601 = 'safari2601';
  static const String safari = 'safari2601'; // Default Safari alias

  // Safari iOS
  static const String safari172Ios = 'safari172_ios';
  static const String safari180Ios = 'safari180_ios';
  static const String safari184Ios = 'safari184_ios';
  static const String safari260Ios = 'safari260_ios';
  static const String safariIos = 'safari260_ios'; // Default Safari iOS alias

  // Tor Browser
  static const String tor145 = 'tor145';

  /// Every profile the pinned upstream release accepts.
  static const List<String> values = [
    edge99, edge101,
    chrome99, chrome100, chrome101, chrome104, chrome107, chrome110,
    chrome116, chrome119, chrome120, chrome123, chrome124, chrome131,
    chrome133a, chrome136, chrome142, chrome145, chrome146, chrome150,
    chrome99Android, chrome131Android,
    firefox133, firefox135, firefox144, firefox147,
    safari153, safari155, safari170, safari172Ios, safari180, safari180Ios,
    safari184, safari184Ios, safari260, safari2601, safari260Ios,
    tor145,
  ];
}
