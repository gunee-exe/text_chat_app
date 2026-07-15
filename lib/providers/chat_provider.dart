import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';

/// Stream of a single chat document.
final chatProvider =
    StreamProvider.family<Chat?, String>((ref, chatId) {
  return ref.watch(firestoreServiceProvider).chatStream(chatId);
});

/// Stream of messages for a chat (newest-first, limit 50).
final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, chatId) {
  return ref.watch(firestoreServiceProvider).messagesStream(chatId);
});

// ── Optimistic message state ───────────────────────────────────────────────

/// Holds in-flight (sending) and failed messages for a given chat,
/// allowing optimistic UI without waiting for Firestore round-trip.
class PendingMessagesNotifier extends StateNotifier<List<Message>> {
  PendingMessagesNotifier() : super([]);

  void addPending(Message message) {
    state = [...state, message];
  }

  void confirmSent(String messageId) {
    state = state.where((m) => m.messageId != messageId).toList();
  }

  void markFailed(String messageId) {
    state = state.map((m) {
      if (m.messageId == messageId) return m.copyWith(status: MessageStatus.failed);
      return m;
    }).toList();
  }

  void removeFailed(String messageId) {
    state = state.where((m) => m.messageId != messageId).toList();
  }
}

final pendingMessagesProvider = StateNotifierProvider.family<
    PendingMessagesNotifier, List<Message>, String>(
  (ref, chatId) => PendingMessagesNotifier(),
);

// ── Send message action ────────────────────────────────────────────────────

/// Sends a message with optimistic UI:
/// 1. Immediately adds a "sending" message to [pendingMessagesProvider].
/// 2. Calls Firestore; on success, removes from pending (stream picks it up).
/// 3. On failure, marks the pending message as failed so a retry icon shows.
Future<void> sendMessageOptimistic({
  required WidgetRef ref,
  required String chatId,
  required String text,
}) async {
  final uid = ref.read(authStateProvider).valueOrNull?.uid;
  if (uid == null) return;

  final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
  final pendingMessage = Message(
    messageId: pendingId,
    senderId: uid,
    text: text.trim(),
    sentAt: DateTime.now(),
    deliveredTo: [],
    readBy: [uid],
    deleted: false,
    status: MessageStatus.sending,
  );

  final notifier = ref.read(pendingMessagesProvider(chatId).notifier);
  notifier.addPending(pendingMessage);

  try {
    await ref.read(firestoreServiceProvider).sendMessage(
          chatId: chatId,
          senderId: uid,
          text: text.trim(),
        );
    notifier.confirmSent(pendingId);
  } catch (_) {
    notifier.markFailed(pendingId);
    rethrow;
  }
}

// ── Load more messages (pagination) ───────────────────────────────────────

final loadMoreMessagesProvider = StateNotifierProvider.family<
    LoadMoreNotifier, LoadMoreState, String>(
  (ref, chatId) => LoadMoreNotifier(
    chatId,
    ref.read(firestoreServiceProvider),
  ),
);

class LoadMoreState {
  final List<Message> olderMessages;
  final bool isLoading;
  final bool hasMore;
  const LoadMoreState({
    this.olderMessages = const [],
    this.isLoading = false,
    this.hasMore = true,
  });
}

class LoadMoreNotifier extends StateNotifier<LoadMoreState> {
  final String chatId;
  final FirestoreService _service;

  LoadMoreNotifier(this.chatId, this._service) : super(const LoadMoreState());

  Future<void> loadMore(Timestamp before) async {
    if (state.isLoading || !state.hasMore) return;
    state = LoadMoreState(
      olderMessages: state.olderMessages,
      isLoading: true,
      hasMore: state.hasMore,
    );
    try {
      final more = await _service.loadMoreMessages(chatId, before: before);
      state = LoadMoreState(
        olderMessages: [...state.olderMessages, ...more],
        isLoading: false,
        hasMore: more.length == 50,
      );
    } catch (_) {
      state = LoadMoreState(
        olderMessages: state.olderMessages,
        isLoading: false,
        hasMore: state.hasMore,
      );
    }
  }
}
