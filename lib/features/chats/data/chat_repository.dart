import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../domain/chat.dart';
import '../domain/message.dart';

/// Reads and writes conversations in Firestore. Scoped to the signed-in user
/// (its [currentUid]) so queries and unread bookkeeping are always "for me".
class ChatRepository {
  ChatRepository(this._db, this.currentUid);

  final FirebaseFirestore _db;
  final String currentUid;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  /// Every chat I'm a member of, newest activity first.
  Stream<List<Chat>> watchChats() => _chats
      .where('memberIds', arrayContains: currentUid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Chat.fromDoc(d, currentUid)).toList());

  Stream<Chat?> watchChat(String chatId) => _chats
      .doc(chatId)
      .snapshots()
      .map((d) => d.exists ? Chat.fromDoc(d, currentUid) : null);

  Stream<List<Message>> watchMessages(String chatId) => _messages(chatId)
      .orderBy('sentAt')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Message.fromDoc(chatId, d)).toList());

  /// Deterministic id for a 1:1 chat so the same pair never gets two chats.
  static String directChatId(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}__${pair[1]}';
  }

  /// Open (or create) the 1:1 chat with [other] and return its id.
  ///
  /// Idempotent write only — no read first. Reading a not-yet-created chat doc
  /// is denied by the rules (membership can't be checked on a null doc), so a
  /// read-before-write would throw. `merge` only touches the stable identity
  /// fields, leaving unread/lastMessageAt to be managed by messaging. The chat
  /// surfaces in the list once the first message sets `lastMessageAt`.
  Future<String> startDirectChat(AppUser other) async {
    final id = directChatId(currentUid, other.id);
    await _chats.doc(id).set({
      'isGroup': false,
      'title': '',
      'memberIds': [currentUid, other.id],
      'createdBy': currentUid,
    }, SetOptions(merge: true));
    return id;
  }

  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final ref = _chats.doc();
    final members = {currentUid, ...memberIds}.toList();
    await ref.set({
      'isGroup': true,
      'title': title.trim().isEmpty ? 'new group' : title.trim(),
      'memberIds': members,
      'createdBy': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unread': {for (final m in members) m: 0},
      'muted': {for (final m in members) m: false},
    });
    return ref.id;
  }

  /// Send a text message: write it, then bump the chat's last-message summary
  /// and increment unread for every member except me — all in one batch.
  Future<void> sendText({
    required String chatId,
    required List<String> memberIds,
    required String text,
    ReplyRef? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final batch = _db.batch();
    final msgRef = _messages(chatId).doc();
    batch.set(msgRef, {
      'senderId': currentUid,
      'type': 'text',
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      // replyTo is only ever written here, at creation.
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    });

    final updates = <String, dynamic>{
      'lastMessage': {
        // id lets the on-device notifier dedupe redelivered snapshots.
        'id': msgRef.id,
        'text': trimmed,
        'senderId': currentUid,
        'type': 'text',
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    for (final m in memberIds) {
      if (m != currentUid) {
        updates['unread.$m'] = FieldValue.increment(1);
      }
    }
    batch.update(_chats.doc(chatId), updates);
    await batch.commit();
  }

  /// Set (or clear, when [emoji] is null) my reaction on a message. Only ever
  /// touches `reactions.{myUid}` — see the message update rule.
  Future<void> setReaction({
    required String chatId,
    required String messageId,
    required String? emoji,
  }) {
    return _messages(chatId).doc(messageId).update({
      'reactions.$currentUid': emoji ?? FieldValue.delete(),
    });
  }

  Future<void> markRead(String chatId) =>
      _chats.doc(chatId).update({'unread.$currentUid': 0});

  Future<void> toggleMute(String chatId, bool current) =>
      _chats.doc(chatId).update({'muted.$currentUid': !current});
}

final chatRepositoryProvider = Provider<ChatRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ChatRepository(FirebaseFirestore.instance, uid);
});

/// My chat list, live.
final chatsStreamProvider = StreamProvider<List<Chat>>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchChats();
});

/// A single chat doc, live (works even before it has any messages).
final chatProvider = StreamProvider.family<Chat?, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watchChat(chatId);
});

/// Messages in a conversation, live and time-ordered.
final chatMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, chatId) {
  final repo = ref.watch(chatRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchMessages(chatId);
});

/// Total unread across all chats — powers the "inbox N" chip.
final unreadTotalProvider = Provider<int>((ref) {
  final chats = ref.watch(chatsStreamProvider).valueOrNull ?? const [];
  return chats.fold<int>(0, (total, c) => total + c.unreadCount);
});
