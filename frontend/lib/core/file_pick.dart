import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A file selected through the platform file picker.
///
/// Exposes everything the upload pipelines need: a [fileName], the raw [bytes]
/// (always populated because the picker is invoked with `withData: true` so the
/// data is available on web), and a best-effort [contentType] derived from the
/// file extension (the picker does not surface a MIME type itself).
class PickedFile {
  const PickedFile({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String contentType;

  int get size => bytes.length;
}

/// Opens the platform file picker and returns the selected file(s) with their
/// bytes loaded.
///
/// - [extensions]: restrict selection to these extensions (without the dot,
///   e.g. `['csv']`). When provided, the picker uses `FileType.custom`.
/// - [multiple]: allow selecting more than one file (defaults to single).
///
/// Returns an empty list when the user cancels the dialog, so callers can treat
/// cancellation as a graceful no-op. `withData: true` guarantees bytes are
/// available on Flutter Web (and keeps mobile/desktop working too); any file
/// the platform fails to load bytes for is skipped.
Future<List<PickedFile>> pickFiles({
  List<String>? extensions,
  bool multiple = false,
}) async {
  final result = await FilePicker.platform.pickFiles(
    withData: true,
    allowMultiple: multiple,
    type: (extensions != null && extensions.isNotEmpty)
        ? FileType.custom
        : FileType.any,
    allowedExtensions:
        (extensions != null && extensions.isNotEmpty) ? extensions : null,
  );

  // Null result => user cancelled the picker.
  if (result == null) return const [];

  final picked = <PickedFile>[];
  for (final file in result.files) {
    final bytes = file.bytes;
    // On web bytes are always present (withData: true); skip anything that
    // somehow came back without data rather than throwing.
    if (bytes == null) continue;
    picked.add(PickedFile(
      fileName: file.name,
      bytes: bytes,
      contentType: contentTypeForExtension(file.extension),
    ));
  }
  return picked;
}

/// Derives a best-effort MIME type from a file [extension] (without the dot).
///
/// file_picker does not provide a MIME type, so we map the common cases the
/// platform handles (documents, images, CSV) and fall back to a generic binary
/// type. The backend re-validates content types, so this only needs to be a
/// reasonable hint for the presigned PUT.
String contentTypeForExtension(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'csv':
      return 'text/csv';
    case 'txt':
      return 'text/plain';
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'zip':
      return 'application/zip';
    case 'hwp':
      return 'application/x-hwp';
    // Video types (course videos) — without these a picked video falls back to
    // octet-stream, which breaks `<video>` playback after upload.
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'mkv':
      return 'video/x-matroska';
    case 'avi':
      return 'video/x-msvideo';
    case 'm4v':
      return 'video/x-m4v';
    default:
      return 'application/octet-stream';
  }
}
