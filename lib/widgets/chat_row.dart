import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../models/chat.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import 'avatar.dart';

/// A single row in the chat list.
/// No border, no card, no shadow — matches design spec exactly.
class ChatRow extends StatelessWidget {
  final Chat chat;
  final AppUser? otherUser;   // null for group chats
  final String currentUid;
  final VoidCallback onTap;
  final VoidCallback onToggleMute;

  const ChatRow({
    super.key,
    required this.chat,
    required this.otherUser,
    required this.currentUid,
    required this.onTap,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMuted = chat.isMutedBy(currentUid);
    final hasUnread = chat.hasUnreadFor(currentUid);

    final name = chat.isGroup
        ? (chat.groupName ?? 'group chat')
        : (otherUser?.username ?? '…');

    final preview = chat.lastMessage.isEmpty
        ? 'start the conversation'
        : chat.lastMessage;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(name),
            const SizedBox(width: 12),

            // Name + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasUnread
                          ? AppColors.textPrimary(theme.brightness)
                          : AppColors.textSecondary(theme.brightness),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp + mute icon
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(chat.lastMessageAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasUnread
                        ? AppColors.accentSolid
                        : AppColors.textMuted(theme.brightness),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onToggleMute,
                  child: Icon(
                    isMuted ? TablerIcons.bell_off : TablerIcons.bell,
                    size: 16,
                    color: AppColors.textMuted(theme.brightness),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    if (chat.isGroup) {
      // Group: show initials square with group uid hash
      return Avatar(
        uid: chat.chatId,
        username: name,
        size: 46,
      );
    }
    if (otherUser != null) {
      return Avatar(
        uid: otherUser!.uid,
        username: otherUser!.username,
        photoUrl: otherUser!.photoUrl,
        size: 46,
      );
    }
    return Avatar(uid: chat.chatId, username: '?', size: 46);
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) {
      // Today: show time if > 1hr ago, else relative
      final mins = now.difference(dt).inMinutes;
      if (mins < 1) return 'now';
      if (mins < 60) return '${mins}m';
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return 'yday';
    if (diff < 7) return _weekday(dt.weekday);
    return '${dt.day}/${dt.month}';
  }

  String _weekday(int w) => const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][w - 1];
}
