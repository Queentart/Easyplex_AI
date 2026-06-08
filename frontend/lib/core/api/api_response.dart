/// Typed wrapper around the backend response envelope.
///
/// Every endpoint returns `{ "data": ..., "meta": ..., "error": ... }`
/// (see backend `app/schemas/common.py`). [ApiResponse] decodes that envelope
/// and parses `data` with a caller-supplied [JsonParser].
library;

/// Parses the `data` field of an envelope into a typed value.
typedef JsonParser<T> = T Function(Object? json);

/// Decoded backend envelope.
class ApiResponse<T> {
  const ApiResponse({this.data, this.meta, this.error});

  final T? data;
  final ApiMeta? meta;
  final ApiError? error;

  bool get isSuccess => error == null;

  /// Builds an [ApiResponse] from a decoded JSON map.
  ///
  /// [dataParser] is applied to the raw `data` value (which may be a map, a
  /// list, or null depending on the endpoint).
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    JsonParser<T> dataParser,
  ) {
    final rawData = json['data'];
    return ApiResponse<T>(
      data: rawData == null ? null : dataParser(rawData),
      meta: json['meta'] is Map<String, dynamic>
          ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      error: json['error'] is Map<String, dynamic>
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// `meta` block. Carries pagination when the endpoint is a list.
class ApiMeta {
  const ApiMeta({this.page, this.size, this.total});

  final int? page;
  final int? size;
  final int? total;

  /// Total number of pages, when [size] and [total] are present.
  int? get totalPages {
    if (size == null || total == null || size == 0) return null;
    return (total! / size!).ceil();
  }

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return ApiMeta(
      page: asInt(json['page']),
      size: asInt(json['size']),
      total: asInt(json['total']),
    );
  }
}

/// `error` block: `{ "code": "...", "message": "..." }`.
class ApiError {
  const ApiError({required this.code, required this.message});

  final String code;
  final String message;

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: (json['code'] ?? 'unknown').toString(),
      message: (json['message'] ?? 'An unexpected error occurred.').toString(),
    );
  }

  @override
  String toString() => 'ApiError($code): $message';
}

/// Convenience pagination view over [ApiMeta] for list UIs.
class Pagination {
  const Pagination({
    required this.page,
    required this.size,
    required this.total,
  });

  final int page;
  final int size;
  final int total;

  int get totalPages => size == 0 ? 0 : (total / size).ceil();
  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;

  factory Pagination.fromMeta(ApiMeta meta) => Pagination(
        page: meta.page ?? 1,
        size: meta.size ?? 0,
        total: meta.total ?? 0,
      );
}
