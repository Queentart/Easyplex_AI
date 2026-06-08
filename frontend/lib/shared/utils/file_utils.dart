/// File-related helpers shared across features.
class FileUtils {
  FileUtils._();

  /// Max upload size in bytes (50 MB), matching the platform limit.
  static const int maxUploadBytes = 50 * 1024 * 1024;

  /// Human-readable size, e.g. `2.3 MB`.
  static String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double size = bytes / 1024;
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(1)} ${units[unit]}';
  }

  /// Lower-cased extension without the dot, or '' when absent.
  static String extension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return '';
    return filename.substring(dot + 1).toLowerCase();
  }

  static bool isWithinSizeLimit(int bytes) => bytes <= maxUploadBytes;
}
