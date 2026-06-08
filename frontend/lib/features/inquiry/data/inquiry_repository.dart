import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/inquiry_model.dart';

/// A page of inquiries plus its pagination metadata.
class InquiryPage {
  const InquiryPage({required this.items, required this.pagination});

  final List<Inquiry> items;
  final Pagination pagination;
}

/// A page of licenses plus its pagination metadata.
class LicensePage {
  const LicensePage({required this.items, required this.pagination});

  final List<SoftwareLicense> items;
  final Pagination pagination;
}

/// Thrown by [InquiryRepository] when an inquiry/license call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that branch on it.
class InquiryException implements Exception {
  const InquiryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls the `/inquiries` and `/licenses` endpoints and parses the backend
/// response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed domain models
/// or throws an [InquiryException] with a clean message.
///
/// Backend reference (source of truth):
///   - `backend/app/api/v1/inquiries.py`
///   - `backend/app/api/v1/licenses.py`
class InquiryRepository {
  InquiryRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  // ── Inquiries ───────────────────────────────────────────────────────────

  /// `GET /inquiries` → a page of inquiries (newest first). The backend scopes
  /// visibility by role (students see only their own). Optional filters mirror
  /// the backend query params.
  Future<InquiryPage> listInquiries({
    String? status,
    String? type,
    String? priority,
    bool assignedToMe = false,
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/inquiries/',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (type != null && type.isNotEmpty) 'type': type,
          if (priority != null && priority.isNotEmpty) 'priority': priority,
          if (assignedToMe) 'assigned_to_me': true,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<Inquiry>>.fromJson(
        response.data ?? const {},
        _parseInquiryList,
      );
      final items = _unwrap(envelope) ?? const <Inquiry>[];
      final meta = envelope.meta;
      return InquiryPage(
        items: items,
        pagination: meta == null
            ? Pagination(page: page, size: size, total: items.length)
            : Pagination.fromMeta(meta),
      );
    });
  }

  /// `GET /inquiries/{id}` → a single inquiry.
  Future<Inquiry> getInquiry(int inquiryId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/inquiries/$inquiryId');
      return _unwrapData(
        ApiResponse<Inquiry>.fromJson(response.data ?? const {}, _parseInquiry),
      );
    });
  }

  /// `POST /inquiries` → the created inquiry.
  Future<Inquiry> createInquiry({
    required String type,
    required String title,
    required String content,
    String priority = 'normal',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/inquiries/',
        data: {
          'type': type,
          'title': title,
          'content': content,
          'priority': priority,
          'attachments': attachments,
        },
      );
      return _unwrapData(
        ApiResponse<Inquiry>.fromJson(response.data ?? const {}, _parseInquiry),
      );
    });
  }

  /// `PATCH /inquiries/{id}` → updates status / assignee / priority. Only the
  /// provided fields are sent. Returns the updated inquiry.
  Future<Inquiry> updateInquiry(
    int inquiryId, {
    String? status,
    int? assignedTo,
    String? priority,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/inquiries/$inquiryId',
        data: {
          'status': ?status,
          'assigned_to': ?assignedTo,
          'priority': ?priority,
        },
      );
      return _unwrapData(
        ApiResponse<Inquiry>.fromJson(response.data ?? const {}, _parseInquiry),
      );
    });
  }

  /// `POST /inquiries/{id}/close` → marks the inquiry closed. Returns the
  /// updated inquiry.
  Future<Inquiry> closeInquiry(int inquiryId) async {
    return _guard(() async {
      final response = await _dio
          .post<Map<String, dynamic>>('/inquiries/$inquiryId/close');
      return _unwrapData(
        ApiResponse<Inquiry>.fromJson(response.data ?? const {}, _parseInquiry),
      );
    });
  }

  // ── Inquiry messages (REST; WebSocket chat is F5) ────────────────────────

  /// `GET /inquiries/{id}/messages` → the thread in creation order.
  Future<List<InquiryMessage>> listMessages(
    int inquiryId, {
    int page = 1,
    int size = 50,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/inquiries/$inquiryId/messages',
        queryParameters: {'page': page, 'size': size},
      );
      final envelope = ApiResponse<List<InquiryMessage>>.fromJson(
        response.data ?? const {},
        _parseMessageList,
      );
      return _unwrap(envelope) ?? const <InquiryMessage>[];
    });
  }

  /// `POST /inquiries/{id}/messages` → the created message.
  Future<InquiryMessage> addMessage({
    required int inquiryId,
    required String content,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/inquiries/$inquiryId/messages',
        data: {
          'content': content,
          'attachments': attachments,
        },
      );
      return _unwrapData(
        ApiResponse<InquiryMessage>.fromJson(
            response.data ?? const {}, _parseMessage),
      );
    });
  }

  // ── Software licenses ─────────────────────────────────────────────────────

  /// `GET /licenses` → a page of licenses for the caller's institution
  /// (admin_ops / tech_support only — enforced server-side). The list payload
  /// never includes the key.
  Future<LicensePage> listLicenses({int page = 1, int size = 20}) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/licenses/',
        queryParameters: {'page': page, 'size': size},
      );
      final envelope = ApiResponse<List<SoftwareLicense>>.fromJson(
        response.data ?? const {},
        _parseLicenseList,
      );
      final items = _unwrap(envelope) ?? const <SoftwareLicense>[];
      final meta = envelope.meta;
      return LicensePage(
        items: items,
        pagination: meta == null
            ? Pagination(page: page, size: size, total: items.length)
            : Pagination.fromMeta(meta),
      );
    });
  }

  /// `POST /licenses` → the created license (admin_ops only — enforced
  /// server-side; tech_support gets a 403).
  Future<SoftwareLicense> createLicense({
    required String serviceName,
    required String licenseKey,
    DateTime? issuedAt,
    DateTime? expiresAt,
    int? seatCount,
    String? notes,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/licenses/',
        data: {
          'service_name': serviceName,
          'license_key': licenseKey,
          'issued_at': ?(issuedAt == null ? null : _ymd(issuedAt)),
          'expires_at': ?(expiresAt == null ? null : _ymd(expiresAt)),
          'seat_count': ?seatCount,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return _unwrapData(
        ApiResponse<SoftwareLicense>.fromJson(
            response.data ?? const {}, _parseLicense),
      );
    });
  }

  /// `GET /licenses/{id}/key` → the license WITH its decrypted key.
  ///
  /// AUDITED: the backend writes an `AuditLog` (`license.read`) and bumps
  /// `last_accessed_at` on every call. Callers must gate this behind a
  /// confirmation dialog noting the access is recorded.
  Future<SoftwareLicense> revealLicenseKey(int licenseId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/licenses/$licenseId/key');
      return _unwrapData(
        ApiResponse<SoftwareLicense>.fromJson(
            response.data ?? const {}, _parseLicense),
      );
    });
  }

  // ── Parsers ────────────────────────────────────────────────────────────

  static List<Inquiry> _parseInquiryList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) => Inquiry.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static Inquiry _parseInquiry(Object? json) =>
      Inquiry.fromJson(json as Map<String, dynamic>);

  static List<InquiryMessage> _parseMessageList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          InquiryMessage.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static InquiryMessage _parseMessage(Object? json) =>
      InquiryMessage.fromJson(json as Map<String, dynamic>);

  static List<SoftwareLicense> _parseLicenseList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          SoftwareLicense.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static SoftwareLicense _parseLicense(Object? json) =>
      SoftwareLicense.fromJson(json as Map<String, dynamic>);

  /// Formats a [DateTime] as the `YYYY-MM-DD` string the backend `date` fields
  /// expect.
  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Envelope / error plumbing ───────────────────────────────────────────

  /// Returns [ApiResponse.data] (may be null for empty list payloads) or throws
  /// an [InquiryException] when the envelope carries an error.
  T? _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw InquiryException(response.error!.message,
          code: response.error!.code);
    }
    return response.data;
  }

  /// Like [_unwrap] but for single-object payloads that must not be null.
  T _unwrapData<T>(ApiResponse<T> response) {
    final data = _unwrap(response);
    if (data == null) throw const InquiryException(_fallbackMessage);
    return data;
  }

  /// Runs [action], converting a [DioException] into an [InquiryException]
  /// whose message is taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw InquiryException(
        _messageFromDioException(e),
        code: _codeFromDioException(e),
      );
    }
  }

  String _messageFromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return _networkMessage;
      default:
        break;
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    }
    final status = e.response?.statusCode;
    if (status == 403) return '접근 권한이 없습니다.';
    return _fallbackMessage;
  }

  String? _codeFromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final code = error['code'];
        if (code is String && code.isNotEmpty) return code;
      }
    }
    return null;
  }
}

/// Provides the [InquiryRepository] wired to the shared [dioProvider].
final inquiryRepositoryProvider = Provider<InquiryRepository>(
  (ref) => InquiryRepository(ref.watch(dioProvider)),
);
