#include <stdarg.h>

// Dynamic forwarders to prevent dead-code stripping of libcurl-impersonate C symbols on iOS
void* ios_curl_easy_init() {
    extern void* curl_easy_init();
    return curl_easy_init();
}

void ios_curl_easy_cleanup(void* handle) {
    extern void curl_easy_cleanup(void*);
    curl_easy_cleanup(handle);
}

int ios_curl_easy_perform(void* handle) {
    extern int curl_easy_perform(void*);
    return curl_easy_perform(handle);
}

int ios_curl_easy_impersonate(void* handle, const char* target, int default_headers) {
    extern int curl_easy_impersonate(void*, const char*, int);
    return curl_easy_impersonate(handle, target, default_headers);
}

const char* ios_curl_version() {
    extern const char* curl_version();
    return curl_version();
}

void* ios_curl_slist_append(void* list, const char* string) {
    extern void* curl_slist_append(void*, const char*);
    return curl_slist_append(list, string);
}

void ios_curl_slist_free_all(void* list) {
    extern void curl_slist_free_all(void*);
    curl_slist_free_all(list);
}

// On iOS ARM64, variadic arguments (like the third parameter in curl_easy_setopt/curl_easy_getinfo)
// are passed on the stack according to Apple's ABI, whereas standard arguments are passed in registers.
// Since Dart FFI always generates register-based calls for non-variadic declarations, calling curl_easy_setopt
// directly from Dart would fail on iOS real devices. These fixed-signature wrappers ensure the arguments
// are correctly placed by the C compiler.

int ios_curl_easy_setopt_long(void* curl, int option, long param) {
    extern int curl_easy_setopt(void*, int, ...);
    return curl_easy_setopt(curl, option, param);
}

int ios_curl_easy_setopt_ptr(void* curl, int option, void* param) {
    extern int curl_easy_setopt(void*, int, ...);
    return curl_easy_setopt(curl, option, param);
}

int ios_curl_easy_getinfo(void* curl, int info, void* param) {
    extern int curl_easy_getinfo(void*, int, ...);
    return curl_easy_getinfo(curl, info, param);
}
