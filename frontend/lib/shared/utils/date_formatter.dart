import 'package:intl/intl.dart';

/// Date / time formatting helpers (KST-oriented, Korean locale strings).
class DateFormatter {
  DateFormatter._();

  static final DateFormat _date = DateFormat('yyyy.MM.dd');
  static final DateFormat _dateTime = DateFormat('yyyy.MM.dd HH:mm');
  static final DateFormat _time = DateFormat('HH:mm');

  static String date(DateTime dt) => _date.format(dt.toLocal());
  static String dateTime(DateTime dt) => _dateTime.format(dt.toLocal());
  static String time(DateTime dt) => _time.format(dt.toLocal());

  /// Parses an ISO-8601 string from the backend, returning null on failure.
  static DateTime? tryParse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  /// Relative "n분 전 / n시간 전 / n일 전" label for recent timestamps.
  static String relative(DateTime dt, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return date(dt);
  }
}
