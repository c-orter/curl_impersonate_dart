import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'curl_consts.dart';
import 'curl_ffi.dart';

/// Selective overrides of an impersonated browser fingerprint.
///
/// Every field is optional and `null` means "leave whatever the impersonate
/// profile already set". Overrides are applied to the curl handle *after*
/// [CurlOpt.IMPERSONATE], so they win over the profile's baked-in defaults.
///
/// The practical rule for scraping: **only override what you have evidence
/// about.** A fingerprint is scored as a whole; changing one attribute to a
/// value that does not correspond to any real browser often makes detection
/// *easier*, not harder, because the combination itself becomes anomalous.
///
/// See `docs/fingerprint-tuning.md` for a per-option breakdown and worked
/// scraping scenarios.
class FingerprintOverrides {
  const FingerprintOverrides({
    // --- TLS ClientHello ---
    this.sigHashAlgs,
    this.enableAlps,
    this.certCompression,
    this.enableTicket,
    this.permuteExtensions,
    this.grease,
    this.extensionOrder,
    this.trustAnchors,
    this.useNewAlpsCodepoint,
    this.keyUsageCheck,
    this.signedCertTimestamps,
    this.statusRequest,
    this.delegatedCredentials,
    this.recordSizeLimit,
    this.keySharesLimit,

    // --- HTTP/2 ---
    this.http2PseudoHeadersOrder,
    this.http2Settings,
    this.http2WindowUpdate,
    this.http2Streams,
    this.http2NoPriority,
    this.streamExclusive,

    // --- Header ordering & base headers ---
    this.httpHeaderOrder,
    this.baseHeaders,

    // --- Cookies, forms, proxy ---
    this.splitCookies,
    this.formBoundary,
    this.proxyCredentialNoReuse,

    // --- HTTP/3 / QUIC ---
    this.http3PseudoHeadersOrder,
    this.http3Headers,
    this.http3Settings,
    this.quicTransportParameters,
    this.http3SigHashAlgs,
    this.http3ExtensionOrder,
    this.http3HeaderOrder,
    this.http3EcCurves,
    this.quicCidLength,
    this.quicInitialPacketNumber,
    this.http3PermuteExtensions,

    // --- WebSocket ---
    this.wsHeaders,
    this.wsHeaderOrder,
    this.wsDisableTicket,
    this.wsCertCompression,
  });

  const FingerprintOverrides.none() : this();

  // --- TLS ClientHello ---

  /// Space-separated TLS signature hash algorithms, e.g. `'rsa_pss_rsae_sha256 sha256'`.
  /// Published in the ClientHello `signature_algorithms` extension.
  final String? sigHashAlgs;

  /// Whether to advertise ALPS (Application-Layer Protocol Settings).
  final bool? enableAlps;

  /// Comma-separated certificate compression algorithms. Supported: `zlib`, `brotli`.
  final String? certCompression;

  /// Whether to send the TLS session ticket extension (RFC 5077).
  final bool? enableTicket;

  /// Whether BoringSSL permutes TLS extension order.
  final bool? permuteExtensions;

  /// Whether to emit TLS GREASE values in the ClientHello.
  final bool? grease;

  /// Comma-separated TLS extension order as extension IDs.
  final String? extensionOrder;

  /// Comma-separated TLS trust anchor relative OIDs.
  ///
  /// Introduced upstream for Chrome 152; profile-specific.
  final String? trustAnchors;

  /// Use the newer ALPS codepoint instead of the original one.
  final bool? useNewAlpsCodepoint;

  /// Perform the TLS key usage check. Note the upstream option is the inverse,
  /// `TLS_KEY_USAGE_NO_CHECK`; this field reads the natural way and is inverted
  /// on the way down.
  final bool? keyUsageCheck;

  /// Enable TLS Signed Certificate Timestamps.
  final bool? signedCertTimestamps;

  /// Enable the OCSP status request extension.
  final bool? statusRequest;

  /// Firefox delegated credentials.
  final String? delegatedCredentials;

  /// Firefox `record_size_limit`.
  final int? recordSizeLimit;

  /// Firefox `key_shares_limit`.
  final int? keySharesLimit;

  // --- HTTP/2 ---

  /// Order of HTTP/2 pseudo-headers as a permutation of `'masp'`, mapping to
  /// `:method`, `:authority`, `:scheme`, `:path`.
  final String? http2PseudoHeadersOrder;

  /// HTTP/2 SETTINGS frame, formatted as `id:value` pairs joined by `;`.
  /// Use [formatSettings].
  final String? http2Settings;

  /// HTTP/2 initial window update.
  final int? http2WindowUpdate;

  /// Initial HTTP/2 stream count.
  final String? http2Streams;

  /// Omit the priority bit in the HTTP/2 HEADERS frame.
  final bool? http2NoPriority;

  /// HTTP/2 stream exclusiveness (0 or 1).
  final int? streamExclusive;

  // --- Header ordering & base headers ---

  /// Comma-separated order for ordinary HTTP headers.
  final String? httpHeaderOrder;

  /// Extra headers merged with [CurlOpt.HTTPHEADER] and attributed to the
  /// impersonated browser, rather than to your code.
  final List<String>? baseHeaders;

  // --- Cookies, forms, proxy ---

  /// Emit each cookie in its own `Cookie` header instead of one joined header.
  final bool? splitCookies;

  /// multipart/form-data boundary style.
  final String? formBoundary;

  /// Do not reuse TLS sessions or connections across proxy credentials.
  final bool? proxyCredentialNoReuse;

  // --- HTTP/3 / QUIC ---

  /// HTTP/3 pseudo-header order, same permutation form as the HTTP/2 option.
  final String? http3PseudoHeadersOrder;

  /// Headers used for HTTP/3 connections instead of [CurlOpt.HTTPHEADER].
  final List<String>? http3Headers;

  /// HTTP/3 SETTINGS frame. Use [formatSettings].
  final String? http3Settings;

  /// QUIC transport parameters as `id:value` pairs joined by `;`.
  /// Use [formatTransportParameters].
  final String? quicTransportParameters;

  /// TLS signature hash algorithms for QUIC, used instead of [sigHashAlgs].
  final String? http3SigHashAlgs;

  /// TLS extension order for QUIC, used instead of [extensionOrder].
  final String? http3ExtensionOrder;

  /// Comma-separated header order for HTTP/3 connections.
  final String? http3HeaderOrder;

  /// Elliptic curves for HTTP/3 connections.
  final String? http3EcCurves;

  /// QUIC initial connection ID length profile.
  final String? quicCidLength;

  /// QUIC initial packet number. `-1` selects Firefox's randomized
  /// distribution; non-negative selects a fixed number.
  final int? quicInitialPacketNumber;

  /// BoringSSL extension permutation for HTTP/3 only. `-1` inherits
  /// [permuteExtensions], `0` disables, `1` enables.
  final int? http3PermuteExtensions;

  // --- WebSocket ---

  /// Headers used for `ws://` and `wss://` instead of [CurlOpt.HTTPHEADER].
  final List<String>? wsHeaders;

  /// Comma-separated header order for WebSocket connections.
  final String? wsHeaderOrder;

  /// Disable the TLS session ticket extension for WebSockets.
  final bool? wsDisableTicket;

  /// Certificate compression algorithms for WebSocket connections.
  final String? wsCertCompression;

  /// Builds an `id:value;id:value` string for the SETTINGS-style options.
  ///
  /// ```dart
  /// FingerprintOverrides.formatSettings({1: 65536, 2: 0, 3: 100});
  /// // '1:65536;2:0;3:100'
  /// ```
  static String formatSettings(Map<int, Object> settings) =>
      settings.entries.map((e) => '${e.key}:${e.value}').join(';');

  /// Builds an `id:value;id:value` string for QUIC transport parameters.
  static String formatTransportParameters(Map<int, Object> params) =>
      formatSettings(params);

  /// Returns a copy with the non-null fields of [other] applied on top.
  ///
  /// Use this for per-request overrides layered over client defaults.
  FingerprintOverrides merge(FingerprintOverrides? other) {
    if (other == null) return this;
    return FingerprintOverrides(
      sigHashAlgs: other.sigHashAlgs ?? sigHashAlgs,
      enableAlps: other.enableAlps ?? enableAlps,
      certCompression: other.certCompression ?? certCompression,
      enableTicket: other.enableTicket ?? enableTicket,
      permuteExtensions: other.permuteExtensions ?? permuteExtensions,
      grease: other.grease ?? grease,
      extensionOrder: other.extensionOrder ?? extensionOrder,
      trustAnchors: other.trustAnchors ?? trustAnchors,
      useNewAlpsCodepoint: other.useNewAlpsCodepoint ?? useNewAlpsCodepoint,
      keyUsageCheck: other.keyUsageCheck ?? keyUsageCheck,
      signedCertTimestamps: other.signedCertTimestamps ?? signedCertTimestamps,
      statusRequest: other.statusRequest ?? statusRequest,
      delegatedCredentials: other.delegatedCredentials ?? delegatedCredentials,
      recordSizeLimit: other.recordSizeLimit ?? recordSizeLimit,
      keySharesLimit: other.keySharesLimit ?? keySharesLimit,
      http2PseudoHeadersOrder:
          other.http2PseudoHeadersOrder ?? http2PseudoHeadersOrder,
      http2Settings: other.http2Settings ?? http2Settings,
      http2WindowUpdate: other.http2WindowUpdate ?? http2WindowUpdate,
      http2Streams: other.http2Streams ?? http2Streams,
      http2NoPriority: other.http2NoPriority ?? http2NoPriority,
      streamExclusive: other.streamExclusive ?? streamExclusive,
      httpHeaderOrder: other.httpHeaderOrder ?? httpHeaderOrder,
      baseHeaders: other.baseHeaders ?? baseHeaders,
      splitCookies: other.splitCookies ?? splitCookies,
      formBoundary: other.formBoundary ?? formBoundary,
      proxyCredentialNoReuse:
          other.proxyCredentialNoReuse ?? proxyCredentialNoReuse,
      http3PseudoHeadersOrder:
          other.http3PseudoHeadersOrder ?? http3PseudoHeadersOrder,
      http3Headers: other.http3Headers ?? http3Headers,
      http3Settings: other.http3Settings ?? http3Settings,
      quicTransportParameters:
          other.quicTransportParameters ?? quicTransportParameters,
      http3SigHashAlgs: other.http3SigHashAlgs ?? http3SigHashAlgs,
      http3ExtensionOrder: other.http3ExtensionOrder ?? http3ExtensionOrder,
      http3HeaderOrder: other.http3HeaderOrder ?? http3HeaderOrder,
      http3EcCurves: other.http3EcCurves ?? http3EcCurves,
      quicCidLength: other.quicCidLength ?? quicCidLength,
      quicInitialPacketNumber:
          other.quicInitialPacketNumber ?? quicInitialPacketNumber,
      http3PermuteExtensions:
          other.http3PermuteExtensions ?? http3PermuteExtensions,
      wsHeaders: other.wsHeaders ?? wsHeaders,
      wsHeaderOrder: other.wsHeaderOrder ?? wsHeaderOrder,
      wsDisableTicket: other.wsDisableTicket ?? wsDisableTicket,
      wsCertCompression: other.wsCertCompression ?? wsCertCompression,
    );
  }

  /// Applies every non-null field to [handle].
  ///
  /// Must be called *after* the impersonate profile and after
  /// [CurlOpt.HTTPHEADER] have been set, because several of these options
  /// are order-dependent (header ordering in particular).
  void applyTo(LibCurl lib, ffi.Pointer<ffi.Void> handle) {
    // Long options.
    if (enableAlps != null) _bool(lib, handle, CurlOpt.SSL_ENABLE_ALPS, enableAlps!);
    if (enableTicket != null) _bool(lib, handle, CurlOpt.SSL_ENABLE_TICKET, enableTicket!);
    if (permuteExtensions != null) _bool(lib, handle, CurlOpt.SSL_PERMUTE_EXTENSIONS, permuteExtensions!);
    if (grease != null) _bool(lib, handle, CurlOpt.TLS_GREASE, grease!);
    if (keyUsageCheck != null) _bool(lib, handle, CurlOpt.TLS_KEY_USAGE_NO_CHECK, !keyUsageCheck!);
    if (signedCertTimestamps != null) _bool(lib, handle, CurlOpt.TLS_SIGNED_CERT_TIMESTAMPS, signedCertTimestamps!);
    if (statusRequest != null) _bool(lib, handle, CurlOpt.TLS_STATUS_REQUEST, statusRequest!);
    if (useNewAlpsCodepoint != null) _bool(lib, handle, CurlOpt.TLS_USE_NEW_ALPS_CODEPOINT, useNewAlpsCodepoint!);
    if (recordSizeLimit != null) _int(lib, handle, CurlOpt.TLS_RECORD_SIZE_LIMIT, recordSizeLimit!);
    if (keySharesLimit != null) _int(lib, handle, CurlOpt.TLS_KEY_SHARES_LIMIT, keySharesLimit!);
    if (http2WindowUpdate != null) _int(lib, handle, CurlOpt.HTTP2_WINDOW_UPDATE, http2WindowUpdate!);
    if (http2NoPriority != null) _bool(lib, handle, CurlOpt.HTTP2_NO_PRIORITY, http2NoPriority!);
    if (streamExclusive != null) _int(lib, handle, CurlOpt.STREAM_EXCLUSIVE, streamExclusive!);
    if (splitCookies != null) _bool(lib, handle, CurlOpt.SPLIT_COOKIES, splitCookies!);
    if (proxyCredentialNoReuse != null) _bool(lib, handle, CurlOpt.PROXY_CREDENTIAL_NO_REUSE, proxyCredentialNoReuse!);
    if (quicInitialPacketNumber != null) _int(lib, handle, CurlOpt.QUIC_INITIAL_PACKET_NUMBER, quicInitialPacketNumber!);
    if (http3PermuteExtensions != null) _int(lib, handle, CurlOpt.HTTP3_SSL_PERMUTE_EXTENSIONS, http3PermuteExtensions!);
    if (wsDisableTicket != null) _bool(lib, handle, CurlOpt.WS_SSL_DISABLE_TICKET, wsDisableTicket!);

    // String options.
    if (sigHashAlgs != null) _str(lib, handle, CurlOpt.SSL_SIG_HASH_ALGS, sigHashAlgs!);
    if (certCompression != null) _str(lib, handle, CurlOpt.SSL_CERT_COMPRESSION, certCompression!);
    if (extensionOrder != null) _str(lib, handle, CurlOpt.TLS_EXTENSION_ORDER, extensionOrder!);
    if (trustAnchors != null) _str(lib, handle, CurlOpt.TLS_TRUST_ANCHORS, trustAnchors!);
    if (delegatedCredentials != null) _str(lib, handle, CurlOpt.TLS_DELEGATED_CREDENTIALS, delegatedCredentials!);
    if (http2PseudoHeadersOrder != null) _str(lib, handle, CurlOpt.HTTP2_PSEUDO_HEADERS_ORDER, http2PseudoHeadersOrder!);
    if (http2Settings != null) _str(lib, handle, CurlOpt.HTTP2_SETTINGS, http2Settings!);
    if (http2Streams != null) _str(lib, handle, CurlOpt.HTTP2_STREAMS, http2Streams!);
    if (httpHeaderOrder != null) _str(lib, handle, CurlOpt.HTTPHEADER_ORDER, httpHeaderOrder!);
    if (formBoundary != null) _str(lib, handle, CurlOpt.FORM_BOUNDARY, formBoundary!);
    if (http3PseudoHeadersOrder != null) _str(lib, handle, CurlOpt.HTTP3_PSEUDO_HEADERS_ORDER, http3PseudoHeadersOrder!);
    if (http3Settings != null) _str(lib, handle, CurlOpt.HTTP3_SETTINGS, http3Settings!);
    if (quicTransportParameters != null) _str(lib, handle, CurlOpt.QUIC_TRANSPORT_PARAMETERS, quicTransportParameters!);
    if (http3SigHashAlgs != null) _str(lib, handle, CurlOpt.HTTP3_SIG_HASH_ALGS, http3SigHashAlgs!);
    if (http3ExtensionOrder != null) _str(lib, handle, CurlOpt.HTTP3_TLS_EXTENSION_ORDER, http3ExtensionOrder!);
    if (http3HeaderOrder != null) _str(lib, handle, CurlOpt.HTTP3_HTTPHEADER_ORDER, http3HeaderOrder!);
    if (http3EcCurves != null) _str(lib, handle, CurlOpt.HTTP3_SSL_EC_CURVES, http3EcCurves!);
    if (quicCidLength != null) _str(lib, handle, CurlOpt.QUIC_CID_LENGTH, quicCidLength!);
    if (wsHeaderOrder != null) _str(lib, handle, CurlOpt.WS_HTTPHEADER_ORDER, wsHeaderOrder!);
    if (wsCertCompression != null) _str(lib, handle, CurlOpt.WS_SSL_CERT_COMPRESSION, wsCertCompression!);

    // Slist options. These allocate natively, so each is freed immediately
    // after the handle has taken its own reference (curl copies the list).
    _slist(lib, handle, CurlOpt.HTTPBASEHEADER, baseHeaders);
    _slist(lib, handle, CurlOpt.HTTP3_HTTPHEADER, http3Headers);
    _slist(lib, handle, CurlOpt.WS_HTTPHEADER, wsHeaders);
  }

  static void _bool(LibCurl lib, ffi.Pointer<ffi.Void> h, int opt, bool v) =>
      lib.setoptInt(h, opt, v ? 1 : 0);

  static void _int(LibCurl lib, ffi.Pointer<ffi.Void> h, int opt, int v) =>
      lib.setoptInt(h, opt, v);

  static void _str(LibCurl lib, ffi.Pointer<ffi.Void> h, int opt, String v) =>
      lib.setoptString(h, opt, v);

  static void _slist(
    LibCurl lib,
    ffi.Pointer<ffi.Void> h,
    int opt,
    List<String>? lines,
  ) {
    if (lines == null) return;
    var list = ffi.Pointer<ffi.Void>.fromAddress(0);
    try {
      for (final line in lines) {
        final p = line.toNativeUtf8();
        try {
          list = lib.slistAppend(list, p);
        } finally {
          malloc.free(p);
        }
      }
      if (list.address != 0) {
        lib.setoptPtr(h, opt, list);
      }
    } finally {
      if (list.address != 0) lib.slistFreeAll(list);
    }
  }
}