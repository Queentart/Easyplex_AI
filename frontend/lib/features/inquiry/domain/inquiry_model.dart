/// Domain models for the inquiry / ticket + software-license feature.
///
/// These mirror the backend schemas (see `backend/app/schemas/inquiry.py`):
///   - [Inquiry]         ↔ `InquiryOut`
///   - [InquiryMessage]  ↔ `InquiryMessageOut`
///   - [SoftwareLicense] ↔ `LicenseOut` / `LicenseWithKey`
///
/// They hold NO business logic — only JSON (de)serialization and small
/// presentation-friendly accessors.
library;

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
String _asString(Object? v) => v?.toString() ?? '';

DateTime? _asDate(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

List<Map<String, dynamic>> _asAttachments(Object? v) {
  if (v is! List) return const [];
  return v
      .whereType<Map>()
      .map((e) => e.map((k, val) => MapEntry(k.toString(), val)))
      .toList();
}

/// Inquiry/ticket type codes (backend free-form `type`). Used to build the
/// type dropdown on the create form and to label list/detail rows.
enum InquiryType {
  technical('technical', '기술 지원'),
  account('account', '계정/접속'),
  operation('operation', '운영 문의'),
  etc('etc', '기타');

  const InquiryType(this.code, this.label);

  final String code;
  final String label;

  static InquiryType fromCode(String code) => InquiryType.values.firstWhere(
        (t) => t.code == code,
        orElse: () => InquiryType.etc,
      );

  static String labelOf(String code) => fromCode(code).label;
}

/// Inquiry status codes. The detail screen drives status transitions via these.
enum InquiryStatus {
  open('open', '접수'),
  inProgress('in_progress', '처리 중'),
  resolved('resolved', '해결됨'),
  closed('closed', '종료');

  const InquiryStatus(this.code, this.label);

  final String code;
  final String label;

  static InquiryStatus fromCode(String code) => InquiryStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => InquiryStatus.open,
      );

  static String labelOf(String code) => fromCode(code).label;
}

/// Inquiry priority codes.
enum InquiryPriority {
  low('low', '낮음'),
  normal('normal', '보통'),
  high('high', '높음'),
  urgent('urgent', '긴급');

  const InquiryPriority(this.code, this.label);

  final String code;
  final String label;

  static InquiryPriority fromCode(String code) =>
      InquiryPriority.values.firstWhere(
        (p) => p.code == code,
        orElse: () => InquiryPriority.normal,
      );

  static String labelOf(String code) => fromCode(code).label;
}

/// A single inquiry / support ticket (`InquiryOut`).
class Inquiry {
  const Inquiry({
    required this.id,
    required this.authorId,
    required this.type,
    required this.title,
    required this.content,
    required this.status,
    required this.priority,
    required this.attachments,
    required this.createdAt,
    this.cohortId,
    this.assignedTo,
    this.resolvedAt,
  });

  final int id;
  final int? cohortId;
  final int authorId;

  /// Raw backend `type` code (see [InquiryType]).
  final String type;
  final String title;
  final String content;

  /// Raw backend `status` code (see [InquiryStatus]).
  final String status;

  /// Raw backend `priority` code (see [InquiryPriority]).
  final String priority;

  /// Assigned handler user id (null when unassigned).
  final int? assignedTo;
  final List<Map<String, dynamic>> attachments;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  InquiryType get typeEnum => InquiryType.fromCode(type);
  InquiryStatus get statusEnum => InquiryStatus.fromCode(status);
  InquiryPriority get priorityEnum => InquiryPriority.fromCode(priority);

  bool get isClosed =>
      status == InquiryStatus.closed.code || status == InquiryStatus.resolved.code;

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: _asInt(json['id']) ?? 0,
      cohortId: _asInt(json['cohort_id']),
      authorId: _asInt(json['author_id']) ?? 0,
      type: _asString(json['type']),
      title: _asString(json['title']),
      content: _asString(json['content']),
      status: _asString(json['status']).isEmpty
          ? InquiryStatus.open.code
          : _asString(json['status']),
      priority: _asString(json['priority']).isEmpty
          ? InquiryPriority.normal.code
          : _asString(json['priority']),
      assignedTo: _asInt(json['assigned_to']),
      attachments: _asAttachments(json['attachments']),
      resolvedAt: _asDate(json['resolved_at']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// A message in an inquiry thread (`InquiryMessageOut`).
///
/// The chat thread aligns a bubble right when [senderId] matches the current
/// viewer; the detail screen passes the viewer id to decide that.
class InquiryMessage {
  const InquiryMessage({
    required this.id,
    required this.inquiryId,
    required this.senderId,
    required this.content,
    required this.attachments,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final int inquiryId;
  final int senderId;
  final String content;
  final List<Map<String, dynamic>> attachments;
  final DateTime? readAt;
  final DateTime createdAt;

  bool isSentBy(int? viewerId) => viewerId != null && viewerId == senderId;

  factory InquiryMessage.fromJson(Map<String, dynamic> json) {
    return InquiryMessage(
      id: _asInt(json['id']) ?? 0,
      inquiryId: _asInt(json['inquiry_id']) ?? 0,
      senderId: _asInt(json['sender_id']) ?? 0,
      content: _asString(json['content']),
      attachments: _asAttachments(json['attachments']),
      readAt: _asDate(json['read_at']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// License lifecycle status codes.
enum LicenseStatus {
  active('active', '사용 중'),
  expired('expired', '만료'),
  revoked('revoked', '회수됨');

  const LicenseStatus(this.code, this.label);

  final String code;
  final String label;

  static LicenseStatus fromCode(String code) => LicenseStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => LicenseStatus.active,
      );

  static String labelOf(String code) => fromCode(code).label;
}

/// A software license record (`LicenseOut`). The encrypted key is never sent
/// in the list payload — it is fetched on demand via the audited
/// `GET /licenses/{id}/key` endpoint, which returns a `LicenseWithKey` parsed
/// into [licenseKey].
class SoftwareLicense {
  const SoftwareLicense({
    required this.id,
    required this.institutionId,
    required this.serviceName,
    required this.status,
    required this.createdAt,
    this.issuedAt,
    this.expiresAt,
    this.seatCount,
    this.notes,
    this.lastAccessedAt,
    this.licenseKey,
  });

  final int id;
  final int institutionId;
  final String serviceName;

  /// Raw backend `status` code (see [LicenseStatus]).
  final String status;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final int? seatCount;
  final String? notes;
  final DateTime? lastAccessedAt;
  final DateTime createdAt;

  /// Decrypted license key — only populated by the audited key-reveal call.
  final String? licenseKey;

  LicenseStatus get statusEnum => LicenseStatus.fromCode(status);

  factory SoftwareLicense.fromJson(Map<String, dynamic> json) {
    return SoftwareLicense(
      id: _asInt(json['id']) ?? 0,
      institutionId: _asInt(json['institution_id']) ?? 0,
      serviceName: _asString(json['service_name']),
      status: _asString(json['status']).isEmpty
          ? LicenseStatus.active.code
          : _asString(json['status']),
      issuedAt: _asDate(json['issued_at']),
      expiresAt: _asDate(json['expires_at']),
      seatCount: _asInt(json['seat_count']),
      notes: json['notes']?.toString(),
      lastAccessedAt: _asDate(json['last_accessed_at']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
      licenseKey: json['license_key']?.toString(),
    );
  }
}
