cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "curl_impersonate_dart")
project(${PROJECT_NAME} LANGUAGES CXX)

# Upstream libcurl-impersonate release to bind against.
# Must be kept in sync with ext.curlImpersonateVersion in android/build.gradle
# and the download URL in ios/curl_impersonate_dart.podspec.
set(CURL_IMPERSONATE_VERSION "2.3.2")

# Flutter desktop only targets x64 and arm64.
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
  set(CURL_IMPERSONATE_ARCH "x86_64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(CURL_IMPERSONATE_ARCH "aarch64")
else()
  message(FATAL_ERROR
    "curl_impersonate_dart: unsupported Linux architecture "
    "'${CMAKE_SYSTEM_PROCESSOR}' (supported: x86_64, aarch64)")
endif()

# The binary is cached next to this file and stamped with the version it came
# from. Existence of the .so alone is not a sufficient guard: bumping the version
# would silently keep the previous release in an already-populated tree (the same
# class of bug the Android and iOS builds guard against).
set(CURL_IMPERSONATE_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.libcurl-impersonate/${CURL_IMPERSONATE_ARCH}")
set(CURL_IMPERSONATE_LIB "${CURL_IMPERSONATE_LIB_DIR}/libcurl-impersonate.so")
set(CURL_IMPERSONATE_STAMP "${CURL_IMPERSONATE_LIB_DIR}/.curl-impersonate-version")

set(_cached_version "")
if(EXISTS "${CURL_IMPERSONATE_STAMP}")
  file(READ "${CURL_IMPERSONATE_STAMP}" _cached_version)
  string(STRIP "${_cached_version}" _cached_version)
endif()

if(EXISTS "${CURL_IMPERSONATE_LIB}" AND _cached_version STREQUAL CURL_IMPERSONATE_VERSION)
  message(STATUS "curl_impersonate_dart: libcurl-impersonate v${CURL_IMPERSONATE_VERSION} for ${CURL_IMPERSONATE_ARCH} already present, skipping download.")
else()
  set(_url "https://github.com/lexiforest/curl-impersonate/releases/download/v${CURL_IMPERSONATE_VERSION}/libcurl-impersonate-v${CURL_IMPERSONATE_VERSION}.${CURL_IMPERSONATE_ARCH}-linux-gnu.tar.gz")
  set(_archive "${CMAKE_CURRENT_BINARY_DIR}/libcurl-impersonate.tar.gz")
  set(_staging "${CMAKE_CURRENT_BINARY_DIR}/libcurl-impersonate-extract")

  message(STATUS "curl_impersonate_dart: Downloading libcurl-impersonate.so v${CURL_IMPERSONATE_VERSION} for ${CURL_IMPERSONATE_ARCH} from ${_url}...")
  file(DOWNLOAD "${_url}" "${_archive}" STATUS _dl_status TLS_VERIFY ON)
  list(GET _dl_status 0 _dl_code)
  if(NOT _dl_code EQUAL 0)
    list(GET _dl_status 1 _dl_msg)
    file(REMOVE "${_archive}")
    message(FATAL_ERROR
      "curl_impersonate_dart: failed to fetch libcurl-impersonate v${CURL_IMPERSONATE_VERSION} "
      "for ${CURL_IMPERSONATE_ARCH} from ${_url}\n  ${_dl_msg}\n"
      "The build cannot continue: without the native library every request would "
      "silently fall back to an unimpersonated client.")
  endif()

  # Extract into a scratch dir first so a failed extraction cannot leave a
  # half-written .so behind for the next build to trust.
  file(REMOVE_RECURSE "${_staging}")
  file(MAKE_DIRECTORY "${_staging}")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar xzf "${_archive}"
    WORKING_DIRECTORY "${_staging}"
    RESULT_VARIABLE _tar_result)
  file(REMOVE "${_archive}")
  if(NOT _tar_result EQUAL 0 OR NOT EXISTS "${_staging}/libcurl-impersonate.so")
    file(REMOVE_RECURSE "${_staging}")
    message(FATAL_ERROR "curl_impersonate_dart: archive did not contain libcurl-impersonate.so")
  endif()

  # libcurl-impersonate.so is a symlink chain to libcurl-impersonate.so.4.x.y;
  # configure_file reads through it and writes a plain file, which is what we
  # want to bundle.
  file(MAKE_DIRECTORY "${CURL_IMPERSONATE_LIB_DIR}")
  configure_file("${_staging}/libcurl-impersonate.so" "${CURL_IMPERSONATE_LIB}" COPYONLY)
  file(WRITE "${CURL_IMPERSONATE_STAMP}" "${CURL_IMPERSONATE_VERSION}")
  file(REMOVE_RECURSE "${_staging}")
endif()

# Flutter installs these next to the app's native libraries (<bundle>/lib), which
# is on the runner's RPATH, so DynamicLibrary.open('libcurl-impersonate.so')
# resolves without any further setup.
set(curl_impersonate_dart_bundled_libraries
  "${CURL_IMPERSONATE_LIB}"
  PARENT_SCOPE
)
