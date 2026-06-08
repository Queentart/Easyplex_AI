import 'package:dio/dio.dart';

import '../constants.dart';

/// Builds the configured [Dio] instance used for all backend calls.
///
/// Construction lives in `core/providers.dart` (the [dioProvider]), which wires
/// the [AuthInterceptor] in — keeping this factory free of provider/storage
/// dependencies so it stays trivially testable.
class ApiClient {
  ApiClient._();

  /// Creates a Dio with the base URL, JSON headers, and sensible timeouts.
  /// Interceptors (auth, logging) are attached by the caller.
  static Dio createDio() {
    return Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(milliseconds: ApiTimeouts.connectMs),
        receiveTimeout: const Duration(milliseconds: ApiTimeouts.receiveMs),
        sendTimeout: const Duration(milliseconds: ApiTimeouts.sendMs),
        contentType: 'application/json',
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
        },
      ),
    );
  }
}
