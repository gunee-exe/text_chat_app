import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import 'widgets/chat_tile.dart';

enum _ChatFilter { inbox, unread, requests }

/// The home screen: the live list of conversations from Firestore, styled after
/// the reference mock — flat background with a top glow, filter pills, plain
/// rows. The composer only lives inside a conversation, not here.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  _ChatFilter _filter = _ChatFilter.inbox;

  List<Chat> _applyFilter(List<Chat> chats) {
    return switch (_filter) {
      _ChatFilter.inbox => chats,
      _ChatFilter.unread => chats.where((c) => c.unreadCount > 0).toList(),
      _ChatFilter.requests => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsStreamProvider);
    final unread = ref.watch(unreadTotalProvider);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  onNewChat: () => context.push('/new'),
                  onSettings: () => context.push('/settings'),
                ),
                const SizedBox(height: 18),
                _FilterChips(
                  selected: _filter,
                  unread: unread,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: chatsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorState(message: '$e'),
                    data: (chats) {
                      final visible = _applyFilter(chats);
                      if (visible.isEmpty) return _EmptyState(filter: _filter);
                      return ListView.separated(
                        padding: const EdgeInsets.only(top: 2, bottom: 12),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final chat = visible[i];
                          return ChatTile(
                            chat: chat,
                            onTap: () {
                              ref
                                  .read(chatRepositoryProvider)
                                  ?.markRead(chat.id);
                              context.push('/chat/${chat.id}');
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNewChat, required this.onSettings});
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('chats', style: Theme.of(context).textTheme.headlineSmall),
        const Spacer(),
        _CircleButton(icon: Icons.person_add_alt_1_rounded, onTap: onNewChat),
        const SizedBox(width: 10),
        _CircleButton(icon: Icons.settings_rounded, onTap: onSettings),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkChip : AppColors.lightChip,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.unread,
    required this.onChanged,
  });
  final _ChatFilter selected;
  final int unread;
  final ValueChanged<_ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: 'inbox${unread > 0 ? ' $unread' : ''}',
          active: selected == _ChatFilter.inbox,
          onTap: () => onChanged(_ChatFilter.inbox),
        ),
        const SizedBox(width: 10),
        _Chip(
          label: 'unread',
          active: selected == _ChatFilter.unread,
          onTap: () => onChanged(_ChatFilter.unread),
        ),
        const SizedBox(width: 10),
        _Chip(
          label: 'requests',
          active: selected == _ChatFilter.requests,
          onTap: () => onChanged(_ChatFilter.requests),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final fg = active
        ? (isDark ? Colors.white : AppColors.accent)
        : secondary;

    return GlassSurface(
      borderRadius: 20,
      blur: 16,
      tint: active ? AppColors.accent : null,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _ChatFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final (icon, text) = switch (filter) {
      _ChatFilter.unread => (Icons.done_all_rounded, "you're all caught up"),
      _ChatFilter.requests => (Icons.inbox_rounded, 'no message requests'),
      _ChatFilter.inbox =>
        (Icons.chat_bubble_outline_rounded, 'no chats yet — tap + to start one'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: secondary),
          const SizedBox(height: 12),
          Text(text,
              style: theme.textTheme.titleMedium?.copyWith(color: secondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: secondary),
            const SizedBox(height: 12),
            Text('could not load chats',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: secondary)),
          ],
        ),
      ),
    );
  }
}
