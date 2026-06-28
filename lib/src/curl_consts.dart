// Option codes, info codes, and impersonation profiles for libcurl.
// Values extracted from standard libcurl headers.

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
}

class CurlInfo {
  static const int EFFECTIVE_URL = 0x100000 + 1; // 1048577
  static const int RESPONSE_CODE = 0x200000 + 2; // 2097154
  static const int HEADER_SIZE = 0x200000 + 11; // 2097163
  static const int COOKIELIST = 0x400000 + 28; // 4194332
  static const int REDIRECT_URL = 0x100000 + 31; // 1048607
  static const int REDIRECT_COUNT = 0x200000 + 20; // 2097172
}

class CurlVersion {
  static const int NONE = 0;
  static const int HTTP1_0 = 1;
  static const int HTTP1_1 = 2;
  static const int HTTP2_0 = 3;
  static const int HTTP3 = 4;
}

class BrowserProfile {
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
  static const String chrome136 = 'chrome136';
  static const String chrome142 = 'chrome142';
  static const String chrome145 = 'chrome145';
  static const String chrome146 = 'chrome146';
  static const String chrome = 'chrome146'; // Default Chrome alias

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
}
