import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Shared rate limiter and HTTP client wrapper for OpenStreetMap Nominatim.
/// Enforces Nominatim's strict usage policy:
/// - Maximum 1 request per second (1000ms spacing between calls)
/// - Custom User-Agent on native platforms (omitted on Web to avoid CORS preflight failures)
/// - Proper client resource cleanup
class NominatimRateLimiter {
  static final NominatimRateLimiter instance = NominatimRateLimiter._();
  NominatimRateLimiter._();

  DateTime _lastRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _pendingRequest;

  static const String userAgent = 'DreamTeam_SD3/1.0 (cebu-softdev-hazard-map)';

  /// Execute an HTTP GET request rate-limited to at most 1 request per second.
  Future<http.Response> get(
    Uri url, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    while (_pendingRequest != null) {
      await _pendingRequest;
    }

    final completer = Completer<void>();
    _pendingRequest = completer.future;

    try {
      final now = DateTime.now();
      final diff = now.difference(_lastRequestTime).inMilliseconds;
      if (diff < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - diff));
      }
      _lastRequestTime = DateTime.now();

      final headers = <String, String>{};
      if (!kIsWeb) {
        headers['User-Agent'] = userAgent;
      }

      final httpClient = client ?? http.Client();
      try {
        final response = await httpClient.get(url, headers: headers).timeout(timeout);
        return response;
      } finally {
        if (client == null) {
          httpClient.close();
        }
      }
    } finally {
      completer.complete();
      if (_pendingRequest == completer.future) {
        _pendingRequest = null;
      }
    }
  }
}

