import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'curl_consts.dart';

// Callback signatures
typedef CurlWriteCallbackNative = ffi.Size Function(
    ffi.Pointer<ffi.Uint8> ptr, ffi.Size size, ffi.Size nmemb, ffi.Pointer<ffi.Void> userdata);
typedef CurlWriteCallback = int Function(
    ffi.Pointer<ffi.Uint8> ptr, int size, int nmemb, ffi.Pointer<ffi.Void> userdata);

class LibCurl {
  static LibCurl? _instance;
  late final ffi.DynamicLibrary dyLib;

  // Bindings
  late final ffi.Pointer<ffi.Void> Function() easyInit;
  late final void Function(ffi.Pointer<ffi.Void> handle) easyCleanup;
  late final int Function(ffi.Pointer<ffi.Void> handle) easyPerform;
  late final int Function(ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> target, int defaultHeaders) easyImpersonate;
  late final ffi.Pointer<Utf8> Function() version;
  late final ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void> list, ffi.Pointer<Utf8> string) slistAppend;
  late final void Function(ffi.Pointer<ffi.Void> list) slistFreeAll;

  // Option-setting shims (to handle variadic args across different ABIs)
  late final int Function(ffi.Pointer<ffi.Void> handle, int option, int value) _setoptInt;
  late final int Function(ffi.Pointer<ffi.Void> handle, int option, ffi.Pointer<Utf8> value) _setoptString;
  late final int Function(ffi.Pointer<ffi.Void> handle, int option, ffi.Pointer<ffi.Void> value) _setoptPtr;
  late final int Function(ffi.Pointer<ffi.Void> handle, int option, ffi.Pointer<ffi.Void> value) _setoptFunc;

  // Get info
  late final int Function(ffi.Pointer<ffi.Void> handle, int info, ffi.Pointer<ffi.Void> value) easyGetinfo;

  // Singleton instance accessor
  static LibCurl get instance {
    _instance ??= LibCurl._load();
    return _instance!;
  }

  /// Version of the loaded native library, e.g. `8.22.0-IMPERSONATE`.
  String get versionString {
    try {
      final ptr = version();
      if (ptr.address == 0) return 'unknown';
      return ptr.toDartString();
    } catch (_) {
      return 'unknown';
    }
  }

  LibCurl._load() {
    dyLib = _loadLibrary();
    _initBindings();
  }

  ffi.DynamicLibrary _loadLibrary() {
    if (Platform.isIOS) {
      try {
        return ffi.DynamicLibrary.open('Frameworks/curl_impersonate_dart.framework/curl_impersonate_dart');
      } catch (_) {
        return ffi.DynamicLibrary.process();
      }
    }
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libcurl-impersonate.so');
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  void _initBindings() {
    String sym(String name) => Platform.isIOS ? name.replaceAll('curl_', 'ios_curl_') : name;

    easyInit = dyLib.lookupFunction<ffi.Pointer<ffi.Void> Function(), ffi.Pointer<ffi.Void> Function()>(
      sym('curl_easy_init'),
    );
    easyCleanup = dyLib.lookupFunction<ffi.Void Function(ffi.Pointer<ffi.Void>), void Function(ffi.Pointer<ffi.Void>)>(
      sym('curl_easy_cleanup'),
    );
    easyPerform = dyLib.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>), int Function(ffi.Pointer<ffi.Void>)>(
      sym('curl_easy_perform'),
    );
    easyImpersonate = dyLib.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>, ffi.Int32),
        int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>, int)>(
      sym('curl_easy_impersonate'),
    );
    version = dyLib.lookupFunction<ffi.Pointer<Utf8> Function(), ffi.Pointer<Utf8> Function()>(
      sym('curl_version'),
    );
    slistAppend = dyLib.lookupFunction<
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>)>(
      sym('curl_slist_append'),
    );
    slistFreeAll = dyLib.lookupFunction<ffi.Void Function(ffi.Pointer<ffi.Void>), void Function(ffi.Pointer<ffi.Void>)>(
      sym('curl_slist_free_all'),
    );
    easyGetinfo = dyLib.lookupFunction<
        ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<ffi.Void>),
        int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Void>)>(
      sym('curl_easy_getinfo'),
    );

    // Resolve setopt bindings
    if (Platform.isIOS) {
      // iOS stack constraint requires C wrappers in Xcode project
      _setoptInt = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.IntPtr),
          int Function(ffi.Pointer<ffi.Void>, int, int)>(
        'ios_curl_easy_setopt_long',
      );
      _setoptString = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<Utf8>),
          int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<Utf8>)>(
        'ios_curl_easy_setopt_ptr',
      );
      _setoptPtr = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Void>)>(
        'ios_curl_easy_setopt_ptr',
      );
      _setoptFunc = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Void>)>(
        'ios_curl_easy_setopt_ptr',
      );
    } else {
      // Android: Call curl_easy_setopt directly
      _setoptInt = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.IntPtr),
          int Function(ffi.Pointer<ffi.Void>, int, int)>(
        'curl_easy_setopt',
      );
      _setoptString = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<Utf8>),
          int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<Utf8>)>(
        'curl_easy_setopt',
      );
      _setoptPtr = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Void>)>(
        'curl_easy_setopt',
      );
      _setoptFunc = dyLib.lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Void>)>(
        'curl_easy_setopt',
      );
    }
  }

  // Easy opt helpers
  int setoptInt(ffi.Pointer<ffi.Void> handle, int option, int value) {
    return _setoptInt(handle, option, value);
  }

  int setoptString(ffi.Pointer<ffi.Void> handle, int option, String value) {
    final ptr = value.toNativeUtf8();
    try {
      return _setoptString(handle, option, ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  int setoptPtr(ffi.Pointer<ffi.Void> handle, int option, ffi.Pointer<ffi.Void> value) {
    return _setoptPtr(handle, option, value);
  }

  int setoptFunc(ffi.Pointer<ffi.Void> handle, int option, ffi.Pointer<ffi.Void> value) {
    return _setoptFunc(handle, option, value);
  }

  // Getinfo helpers
  int getInfoLong(ffi.Pointer<ffi.Void> handle, int info) {
    final size = ffi.sizeOf<ffi.Long>();
    if (size == 8) {
      final ptr = malloc<ffi.Int64>();
      try {
        final ret = easyGetinfo(handle, info, ptr.cast<ffi.Void>());
        if (ret != 0) return 0;
        return ptr.value;
      } finally {
        malloc.free(ptr);
      }
    } else {
      final ptr = malloc<ffi.Int32>();
      try {
        final ret = easyGetinfo(handle, info, ptr.cast<ffi.Void>());
        if (ret != 0) return 0;
        return ptr.value;
      } finally {
        malloc.free(ptr);
      }
    }
  }

  String? getInfoString(ffi.Pointer<ffi.Void> handle, int info) {
    final ptr = malloc<ffi.Pointer<Utf8>>();
    try {
      final ret = easyGetinfo(handle, info, ptr.cast<ffi.Void>());
      if (ret != 0 || ptr.value.address == 0) return null;
      return ptr.value.toDartString();
    } finally {
      malloc.free(ptr);
    }
  }

  List<String> getInfoCookieList(ffi.Pointer<ffi.Void> handle) {
    final ptr = malloc<ffi.Pointer<ffi.Void>>();
    try {
      final ret = easyGetinfo(handle, CurlInfo.COOKIELIST, ptr.cast<ffi.Void>());
      if (ret != 0 || ptr.value.address == 0) return [];
      
      final list = <String>[];
      ffi.Pointer<ffi.Void> current = ptr.value;
      
      while (current.address != 0) {
        final dataPtr = current.cast<ffi.Pointer<Utf8>>().value;
        if (dataPtr.address != 0) {
          list.add(dataPtr.toDartString());
        }
        current = (current.cast<ffi.Uint8>() + ffi.sizeOf<ffi.Pointer>()).cast<ffi.Pointer<ffi.Void>>().value;
      }
      return list;
    } finally {
      malloc.free(ptr);
    }
  }
}
