import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../users/data/user_repository.dart';
import '../../domain/chat.dart';
import '../../domain/message.dart';

/// A single row in the chats list — a plain row (no card/border/shadow). For a
/// 1:1 chat it resolves the other person's display name/avatar from their
/// profile; groups use the stored title.
class ChatTile extends ConsumerWidget {
  const ChatTile({super.key, required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final muted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final currentUid = ref.watch(currentUidProvider) ?? '';

    // Resolve the display title + avatar seed.
    String title;
    String seed;
    if (chat.isGroup) {
      title = chat.title;
      seed = chat.id;
    } else {
      final otherId = chat.otherMemberId(currentUid);
      seed = otherId;
      title = ref.watch(userProfileProvider(otherId)).valueOrNull?.displayName ??
          '…';
    }

    final preview = chat.lastMessage?.preview ??
        (chat.isGroup ? 'group created' : 'say hi 👋');
    final time = chat.lastMessageAt;
    final hasUnread = chat.unreadCount > 0;
    final isMediaPreview = chat.lastMessage != null &&
        chat.lastMessage!.type != MessageType.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            UserAvatar(
              name: title,
              seed: seed,
              imageUrl: chat.photoUrl,
              isGroup: chat.isGroup,
              size: 50,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isMediaPreview) ...[
                        Icon(_iconForPreview(), size: 15, color: secondary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null)
                  Text(
                    formatChatTimestamp(time),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasUnread ? AppColors.accent : muted,
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${chat.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Icon(
                    chat.muted
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_none_rounded,
                    size: 18,
                    color: muted,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForPreview() {
    return switch (chat.lastMessage?.type) {
      MessageType.image => Icons.photo_rounded,
      MessageType.video => Icons.videocam_rounded,
      MessageType.audio => Icons.mic_rounded,
      _ => Icons.chat_bubble_outline_rounded,
    };
  }
}
