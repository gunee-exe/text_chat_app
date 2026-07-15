import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';

/// All chats for the current user, sorted by lastMessageAt descending.
final chatListProvider = StreamProvider<List<Chat>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).chatListStream(user.uid);
});

/// Chats that have unread messages for the current user.
final unreadChatsProvider = Provider<List<Chat>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final chats = ref.watch(chatListProvider).valueOrNull ?? [];
  return chats.where((c) => c.hasUnreadFor(user.uid)).toList();
});

/// Chats where the current user has not yet sent any message
/// (i.e. initiated by someone else — shown in requests tab).
///
/// This is computed client-side from the chat list; per-chat send checks
/// are done lazily via [hasUserSentMessageProvider].
final requestChatIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Marks a set of chatIds as "requests" (current user never replied).
/// Updated asynchronously when the chat list loads.
final chatListWithRequestsProvider = FutureProvider<_ChatListResult>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const _ChatListResult(inbox: [], requests: []);

  final chats = ref.watch(chatListProvider).valueOrNull ?? [];
  final firestoreService = ref.watch(firestoreServiceProvider);

  final inbox = <Chat>[];
  final requests = <Chat>[];

  for (final chat in chats) {
    if (chat.isMutedBy(user.uid)) {
      inbox.add(chat); // muted chats stay in inbox but appear differently
      continue;
    }
    // A chat is a "request" if: it's a 1:1, the current user is NOT the last sender,
    // and the current user has never sent a message.
    if (!chat.isGroup &&
        chat.lastMessageSenderId != user.uid &&
        chat.lastMessage.isNotEmpty) {
      final hasSent = await firestoreService.hasUserSentMessage(chat.chatId, user.uid);
      if (!hasSent) {
        requests.add(chat);
        continue;
      }
    }
    inbox.add(chat);
  }

  return _ChatListResult(inbox: inbox, requests: requests);
});

class _ChatListResult {
  final List<Chat> inbox;
  final List<Chat> requests;
  const _ChatListResult({required this.inbox, required this.requests});
}
