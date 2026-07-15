import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_user.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_list_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/chat_row.dart';
import '../widgets/pill_tab_bar.dart';

enum _ChatTab { inbox, unread, requests }

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  _ChatTab _activeTab = _ChatTab.inbox;

  void _openAddFriendSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFriendSheet(
        onChatCreated: (chatId, chatName, otherUid) {
          context.push('/chat/$chatId', extra: {
            'chatName': chatName,
            'otherUid': otherUid,
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final allChats = ref.watch(chatListProvider).valueOrNull ?? [];
    final unreadChats = ref.watch(unreadChatsProvider);
    final chatResult = ref.watch(chatListWithRequestsProvider).valueOrNull;

    final inboxChats = chatResult?.inbox ?? allChats;
    final requestChats = chatResult?.requests ?? [];

    final displayedChats = switch (_activeTab) {
      _ChatTab.inbox => inboxChats,
      _ChatTab.unread => unreadChats,
      _ChatTab.requests => requestChats,
    };

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        children: [
          // Top gradient overlay (150px, not full-screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.gradientTop, Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: "chats" + add-friend icon
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        'chats',
                        style: GoogleFonts.fredoka(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
                      // Settings icon
                      IconButton(
                        icon: Icon(
                          TablerIcons.dots_vertical,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        onPressed: () => context.push('/settings'),
                      ),
                      // Add friend icon
                      _AddFriendButton(onTap: _openAddFriendSheet),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Pill tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PillTabBar(
                    selectedIndex: _activeTab.index,
                    labels: const ['inbox', 'unread', 'requests'],
                    counts: [
                      inboxChats.isNotEmpty ? inboxChats.length : null,
                      null,
                      null,
                    ],
                    onTabSelected: (i) =>
                        setState(() => _activeTab = _ChatTab.values[i]),
                  ),
                ),

                const SizedBox(height: 12),

                // Chat list
                Expanded(
                  child: _buildChatList(
                    context,
                    displayedChats,
                    currentUser,
                    isDark,
                  ),
                ),
              ],
            ),
          ),

          // Bottom pill bar
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _BottomPillBar(onNewTap: _openAddFriendSheet),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(
    BuildContext context,
    List<Chat> chats,
    AppUser? currentUser,
    bool isDark,
  ) {
    final uid = currentUser?.uid ?? '';
    final isLoading = ref.watch(chatListProvider).isLoading;

    if (isLoading && chats.isEmpty) {
      return _ShimmerList();
    }

    if (chats.isEmpty) {
      return _EmptyState(onAddFriend: _openAddFriendSheet);
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final chat = chats[i];
        return _ChatRowWrapper(
          chat: chat,
          currentUid: uid,
          onTap: () {
            // Get the other user's uid for 1:1 chats
            final otherUid = chat.isGroup
                ? null
                : chat.participants.firstWhere(
                    (p) => p != uid,
                    orElse: () => '',
                  );
            context.push('/chat/${chat.chatId}', extra: {
              'chatName': chat.isGroup
                  ? (chat.groupName ?? 'group chat')
                  : '', // populated from stream in chat screen
              'otherUid': otherUid,
            });
          },
        );
      },
    );
  }
}

/// Wraps ChatRow with async other-user fetch for 1:1 chats.
class _ChatRowWrapper extends ConsumerWidget {
  final Chat chat;
  final String currentUid;
  final VoidCallback onTap;

  const _ChatRowWrapper({
    required this.chat,
    required this.currentUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppUser? otherUser;

    if (!chat.isGroup) {
      final otherUid = chat.participants.firstWhere(
        (p) => p != currentUid,
        orElse: () => '',
      );
      // We don't await here — use a FutureProvider family for caching
      // TODO: For large chat lists, batch user lookups with a user cache provider
      otherUser = ref
          .watch(_otherUserProvider(otherUid))
          .valueOrNull;
    }

    return ChatRow(
      chat: chat,
      otherUser: otherUser,
      currentUid: currentUid,
      onTap: onTap,
      onToggleMute: () {
        final isMuted = chat.isMutedBy(currentUid);
        ref.read(firestoreServiceProvider).toggleMute(
              chat.chatId,
              currentUid,
              muted: isMuted,
            );
      },
    );
  }
}

final _otherUserProvider =
    FutureProvider.family<AppUser?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  return ref.read(firestoreServiceProvider).getUserByUid(uid);
});

class _AddFriendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFriendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accentSolid.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          TablerIcons.user_plus,
          size: 18,
          color: isDark ? Colors.white : AppColors.accentSolid,
        ),
      ),
    );
  }
}

class _BottomPillBar extends StatelessWidget {
  final VoidCallback onNewTap;
  const _BottomPillBar({required this.onNewTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(12)
            : Colors.black.withAlpha(8),
        borderRadius: BorderRadius.circular(AppRadius.inputBar),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // New button
          GestureDetector(
            onTap: onNewTap,
            child: Row(
              children: [
                Icon(
                  TablerIcons.plus,
                  size: 18,
                  color: AppColors.textSecondary(theme.brightness),
                ),
                const SizedBox(width: 6),
                Text(
                  'new',
                  style: TextStyle(
                    color: AppColors.textSecondary(theme.brightness),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Mic icon (coming soon placeholder per spec)
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('voice messages coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Icon(
                  TablerIcons.microphone,
                  size: 22,
                  color: AppColors.textSecondary(theme.brightness),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddFriend;
  const _EmptyState({required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TablerIcons.message_circle,
              size: 64,
              color: AppColors.textMuted(theme.brightness),
            ),
            const SizedBox(height: 20),
            Text(
              'no chats yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'add a friend by their id to start chatting',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onAddFriend,
              child: const Text('add friend'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor =
        isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(AppRadius.avatar),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
