import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../models/message.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A single message bubble.
/// Own messages → right-aligned accent fill.
/// Others → left-aligned translucent with border.
/// Deleted → italic placeholder in same position.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final String? senderName; // shown above bubble in group chats only
  final VoidCallback? onRetry; // shown when status == failed

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.senderName,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: () => _showTimestamp(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          mainAxisAlignment:
              isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwn) ...[
              _buildBubble(theme, isDark),
            ] else ...[
              if (message.status == MessageStatus.failed)
                GestureDetector(
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    child: Icon(
                      TablerIcons.refresh,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              _buildBubble(theme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, bool isDark) {
    final isFailed = message.status == MessageStatus.failed;
    final isSending = message.status == MessageStatus.sending;

    Color bgColor;
    Color textColor;
    Border? border;

    if (isOwn) {
      bgColor = isFailed ? theme.colorScheme.error : AppColors.accentSolid;
      textColor = Colors.white;
    } else {
      bgColor = isDark
          ? Colors.white.withAlpha(18)
          : Colors.black.withAlpha(10);
      textColor = AppColors.textPrimary(theme.brightness);
      border = Border.all(
        color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(20),
        width: 0.8,
      );
    }

    return Opacity(
      opacity: isSending ? 0.6 : 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.messageBubble),
              topRight: const Radius.circular(AppRadius.messageBubble),
              bottomLeft: Radius.circular(isOwn ? AppRadius.messageBubble : 4),
              bottomRight: Radius.circular(isOwn ? 4 : AppRadius.messageBubble),
            ),
            border: border,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null && !isOwn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName!,
                    style: TextStyle(
                      color: AppColors.accentSolid,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (message.deleted)
                Text(
                  'message deleted',
                  style: TextStyle(
                    color: textColor.withAlpha(140),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                )
              else
                Text(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimestamp(BuildContext context) {
    final dt = message.sentAt;
    final formatted =
        '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => _TimestampOverlay(text: formatted),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }
}

class _TimestampOverlay extends StatelessWidget {
  final String text;
  const _TimestampOverlay({required this.text});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
