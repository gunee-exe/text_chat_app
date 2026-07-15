import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/message_bubble.dart';

// Cached user lookup for chat participants
final _chatUserProvider =
    FutureProvider.family<AppUser?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  return ref.read(firestoreServiceProvider).getUserByUid(uid);
});

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String? otherUid;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.otherUid,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _canSend = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final v = _textController.text.trim().isNotEmpty;
      if (v != _canSend) setState(() => _canSend = v);
    });
    _markRead();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _markRead() {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      ref.read(firestoreServiceProvider).markAsRead(widget.chatId, uid);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final messages = ref.read(messagesProvider(widget.chatId)).valueOrNull;
      if (messages != null && messages.isNotEmpty) {
        ref.read(loadMoreMessagesProvider(widget.chatId).notifier).loadMore(
              Timestamp.fromDate(messages.last.sentAt),
            );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _canSend = false);
    try {
      await sendMessageOptimistic(ref: ref, chatId: widget.chatId, text: text);
      _markRead();
      setState(() => _isOffline = false);
    } catch (_) {
      setState(() => _isOffline = true);
    }
  }

  Future<void> _retryMessage(String pendingId) async {
    final pending = ref
        .read(pendingMessagesProvider(widget.chatId))
        .firstWhere((m) => m.messageId == pendingId);
    ref.read(pendingMessagesProvider(widget.chatId).notifier).removeFailed(pendingId);
    try {
      await sendMessageOptimistic(
          ref: ref, chatId: widget.chatId, text: pending.text);
    } catch (_) {}
  }

  void _showContactInfo(AppUser user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B24) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(uid: user.uid, username: user.username, photoUrl: user.photoUrl, size: 72),
            const SizedBox(height: 16),
            Text(user.username, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('@${user.usernameLower}',
                style: TextStyle(
                    color: AppColors.textSecondary(Theme.of(context).brightness),
                    fontSize: 14)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final chat = ref.watch(chatProvider(widget.chatId)).valueOrNull;
    final messages = ref.watch(messagesProvider(widget.chatId)).valueOrNull ?? [];
    final pending = ref.watch(pendingMessagesProvider(widget.chatId));
    final older = ref.watch(loadMoreMessagesProvider(widget.chatId)).olderMessages;

    String username = widget.chatName;
    AppUser? otherUser;
    if (chat != null && !chat.isGroup && widget.otherUid != null) {
      otherUser = ref.watch(_chatUserProvider(widget.otherUid!)).valueOrNull;
      if (otherUser != null) username = otherUser.username;
    } else if (chat?.isGroup == true) {
      username = chat?.groupName ?? 'group chat';
    }

    ref.listen(messagesProvider(widget.chatId), (_, __) => _markRead());

    final allMessages = [...pending.reversed, ...messages, ...older];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
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
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _buildHeader(context, username, otherUser, isDark, uid),
              ),
              if (_isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange.withAlpha(40),
                  child: Text(
                    "you're offline — messages will send once you're back online",
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: allMessages.isEmpty
                    ? Center(
                        child: Text(
                          'start the conversation',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted(theme.brightness),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: allMessages.length,
                        itemBuilder: (context, i) {
                          final msg = allMessages[i];
                          final isOwn = msg.senderId == uid;
                          String? senderName;
                          if (chat?.isGroup == true && !isOwn) {
                            senderName = ref.watch(_chatUserProvider(msg.senderId)).valueOrNull?.username;
                          }
                          return MessageBubble(
                            message: msg,
                            isOwn: isOwn,
                            senderName: senderName,
                            onRetry: msg.status == MessageStatus.failed
                                ? () => _retryMessage(msg.messageId)
                                : null,
                          );
                        },
                      ),
              ),
              _buildInputBar(context, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, AppUser? other, bool isDark, String uid) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(TablerIcons.chevron_left,
                color: isDark ? Colors.white : AppColors.textPrimaryLight),
            onPressed: () => context.pop(),
          ),
          if (other != null)
            Avatar(uid: other.uid, username: other.username, photoUrl: other.photoUrl, size: 36)
          else
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentSolid.withAlpha(40),
                borderRadius: BorderRadius.circular(AppRadius.avatar),
              ),
              child: const Icon(Icons.group_rounded, size: 18, color: AppColors.accentSolid),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: other != null ? () => _showContactInfo(other) : null,
              child: Text(name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
            borderRadius: BorderRadius.circular(AppRadius.inputBar),
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 1,
                  maxLength: 2000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: const InputDecoration(
                    hintText: 'message',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  ),
                  style: TextStyle(color: AppColors.textPrimary(theme.brightness), fontSize: 15),
                  onSubmitted: _canSend ? (_) => _sendMessage() : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: AnimatedOpacity(
                  opacity: _canSend ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _canSend ? _sendMessage : null,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _canSend ? AppColors.accentSolid : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(TablerIcons.send_2, size: 18,
                          color: _canSend ? Colors.white : AppColors.textMuted(theme.brightness)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
