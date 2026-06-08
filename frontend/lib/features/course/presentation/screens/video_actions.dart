import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/course_repository.dart';
import '../../domain/course_model.dart';
import 'web_video_player.dart';

/// Shared play / download actions for a [CourseVideo], used by both the
/// instructor and student day-detail screens.
///
/// Playback uses a web-native `<video>` element ([buildVideoPlayer]); download
/// resolves an attachment-disposition presigned URL and hands it to the browser
/// via [triggerDownload]. Both resolve the presigned URL through the repository
/// at the moment of the action (URLs are short-lived).
class VideoActions {
  const VideoActions._();

  /// Resolves the inline (range-capable) URL then shows a full-screen dialog
  /// containing the player. Handles the async URL fetch with a loading dialog
  /// and surfaces failures via a snackbar.
  static Future<void> play(
    BuildContext context,
    WidgetRef ref,
    CourseVideo video,
  ) async {
    String url;
    try {
      url = await ref.read(courseRepositoryProvider).videoUrl(video.fileKey);
    } on CourseException catch (e) {
      if (context.mounted) _snack(context, e.message);
      return;
    } catch (_) {
      if (context.mounted) _snack(context, '영상을 불러오지 못했습니다.');
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _PlayerDialog(title: video.displayTitle, url: url),
    );
  }

  /// Resolves an attachment URL (Content-Disposition) then triggers a browser
  /// download with a friendly filename.
  static Future<void> download(
    BuildContext context,
    WidgetRef ref,
    CourseVideo video,
  ) async {
    final filename =
        video.title ?? video.originalFilename ?? 'video.mp4';
    try {
      final url = await ref.read(courseRepositoryProvider).videoUrl(
            video.fileKey,
            download: true,
            filename: filename,
          );
      triggerDownload(url, filename);
    } on CourseException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (_) {
      if (context.mounted) _snack(context, '다운로드를 시작하지 못했습니다.');
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Full-screen dialog: a 16:9 web-native player with the title bar + close.
class _PlayerDialog extends StatelessWidget {
  const _PlayerDialog({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSm,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Colors.black,
                  child: buildVideoPlayer(url),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
