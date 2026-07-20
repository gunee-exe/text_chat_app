import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/message_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../../users/data/user_repository.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import '../domain/message.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input_bar.dart';
import 'widgets/swipe_to_reply.dart';

/// The message being composed as a reply, captured when the user swipes.
class _ReplyDraft {
  const _ReplyDraft({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.snippet,
  });
  final String messageId;
  final String senderId;
  final String senderName;
  final String snippet;

  ReplyRef toRef() =>
      ReplyRef(messageId: messageId, senderName: senderName, snippet: snippet);
}

/// A single conversation: the live message history plus the composer.
class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scrollController = ScrollController();
  final _msgKeys = <String, GlobalKey>{};

  _ReplyDraft? _reply;
  String? _highlightId;

  GlobalKey _keyFor(String id) => _msgKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Mark this chat as the one on screen so we don't notify over it.
      ref.read(openChatIdProvider.notifier).state = widget.chatId;
      ref.read(chatRepositoryProvider)?.markRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    // Clear only if we're still the open chat (guards against races when
    // navigating between conversations).
    final openChat = ref.read(openChatIdProvider.notifier);
    if (openChat.state == widget.chatId) openChat.state = null;
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _displayNameOf(String senderId, String currentUid) {
    if (senderId == currentUid) {
      return ref.read(currentUserProfileProvider).valueOrNull?.displayName ??
          'you';
    }
    return ref.read(userProfileProvider(senderId)).valueOrNull?.displayName ??
        'someone';
  }

  void _startReply(Message msg, String currentUid) {
    final snippet = msg.type == MessageType.text ? msg.text : msg.preview;
    setState(() {
      _reply = _ReplyDraft(
        messageId: msg.id,
        senderId: msg.senderId,
        senderName: _displayNameOf(msg.senderId, currentUid),
        snippet: snippet.length > 90 ? '${snippet.substring(0, 90)}…' : snippet,
      );
    });
  }

  void _goToOriginal(String messageId) {
    final ctx = _msgKeys[messageId]?.currentContext;
    if (ctx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message unavailable')),
      );
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      alignment: 0.3,
      curve: Curves.easeInOut,
    );
    setState(() => _highlightId = messageId);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && _highlightId == messageId) {
        setState(() => _highlightId = null);
      }
    });
  }

  Future<void> _react(Message msg, String currentUid) async {
    final current = msg.reactions[currentUid];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReactionPicker(current: current),
    );
    if (picked == null) return;
    final emoji = picked == current ? null : picked; // tapping again removes
    await ref.read(chatRepositoryProvider)?.setReaction(
          chatId: widget.chatId,
          messageId: msg.id,
          emoji: emoji,
        );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(currentUidProvider) ?? '';
    final chat = ref.watch(chatProvider(widget.chatId)).valueOrNull;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: chat == null
              ? const SizedBox.shrink()
              : _ChatHeader(chat: chat, currentUid: currentUid),
          actions: [
            if (chat != null)
              IconButton(
                icon: Icon(chat.muted
                    ? Icons.notifications_off_rounded
                    : Icons.notifications_none_rounded),
                onPressed: () => ref
                    .read(chatRepositoryProvider)
                    ?.toggleMute(widget.chatId, chat.muted),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('could not load: $e')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return _EmptyConversation(
                      title: chat?.isGroup == true ? chat!.title : 'them',
                    );
                  }
                  _jumpToBottom();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == currentUid;
                      final showDate = i == 0 ||
                          !_sameDay(messages[i - 1].sentAt, msg.sentAt);
                      final isGroup = chat?.isGroup ?? false;
                      final senderName = isGroup && !isMe
                          ? ref
                              .watch(userProfileProvider(msg.senderId))
                              .valueOrNull
                              ?.displayName
                          : null;
                      return Column(
                        children: [
                          if (showDate) _DateChip(date: msg.sentAt),
                          SwipeToReply(
                            isMe: isMe,
                            onReply: () => _startReply(msg, currentUid),
                            child: MessageBubble(
                              key: _keyFor(msg.id),
                              message: msg,
                              isMe: isMe,
                              currentUid: currentUid,
                              senderName: senderName,
                              highlighted: _highlightId == msg.id,
                              onQuoteTap: msg.replyTo == null
                                  ? null
                                  : () => _goToOriginal(msg.replyTo!.messageId),
                              onLongPress: () => _react(msg, currentUid),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_reply != null)
              _ReplyPreviewBar(
                draft: _reply!,
                onCancel: () => setState(() => _reply = null),
              ),
            MessageInputBar(
              onSendText: (text) {
                final c = ref.read(chatProvider(widget.chatId)).valueOrNull;
                if (c == null) return;
                ref.read(chatRepositoryProvider)?.sendText(
                      chatId: widget.chatId,
                      memberIds: c.memberIds,
                      text: text,
                      replyTo: _reply?.toRef(),
                    );
                if (_reply != null) setState(() => _reply = null);
                _jumpToBottom();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ReplyPreviewBar extends StatelessWidget {
  const _ReplyPreviewBar({required this.draft, required this.onCancel});

  final _ReplyDraft draft;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.avatarColorFor(draft.senderId).$1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: GlassSurface(
        borderRadius: 14,
        blur: 16,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('replying to ${draft.senderName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5)),
                      Text(
                        draft.snippet.isEmpty ? 'message' : draft.snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionPicker extends StatelessWidget {
  const _ReactionPicker({this.current});
  final String? current;

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassSurface(
          borderRadius: 26,
          blur: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final e in _emojis)
                InkWell(
                  onTap: () => Navigator.pop(context, e),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e == current
                          ? AppColors.accent.withValues(alpha: 0.22)
                          : Colors.transparent,
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.chat, required this.currentUid});
  final Chat chat;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    String title;
    String seed;
    String subtitle;
    if (chat.isGroup) {
      title = chat.title;
      seed = chat.id;
      subtitle = '${chat.memberIds.length} members';
    } else {
      final otherId = chat.otherMemberId(currentUid);
      seed = otherId;
      final other = ref.watch(userProfileProvider(otherId)).valueOrNull;
      title = other?.displayName ?? '…';
      subtitle = (other?.note.isNotEmpty ?? false)
          ? other!.note
          : '@${other?.username ?? ''}';
    }

    return Row(
      children: [
        UserAvatar(name: title, seed: seed, isGroup: chat.isGroup, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkChip : AppColors.lightChip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        DateFormat('EEE, d MMM').format(date),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.waving_hand_rounded, size: 44, color: secondary),
          const SizedBox(height: 12),
          Text('say hi to $title',
              style: theme.textTheme.titleMedium?.copyWith(color: secondary)),
        ],
      ),
    );
  }
}
