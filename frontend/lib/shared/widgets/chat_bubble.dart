import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Chat message bubble for the AI co-pilot surfaces.
///
///  - user (instructor) : teal fill, white text, right-aligned, tail top-right
///  - agent (AI)        : pale-sand fill, teal left-accent border, left-aligned
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.child,
    required this.isUser,
  });

  /// Convenience for plain-text messages.
  factory ChatBubble.text(String text, {required bool isUser}) {
    return ChatBubble(
      isUser: isUser,
      child: Builder(
        builder: (context) => Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isUser ? AppColors.onPrimary : AppColors.onSurface,
              ),
        ),
      ),
    );
  }

  final Widget child;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isUser ? AppRadius.lg : 0),
      topRight: Radius.circular(isUser ? 0 : AppRadius.lg),
      bottomLeft: const Radius.circular(AppRadius.lg),
      bottomRight: const Radius.circular(AppRadius.lg),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md - 4),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : AppColors.paleSand,
            borderRadius: radius,
            border: isUser
                ? null
                : const Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                  ),
            boxShadow: isUser ? null : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
