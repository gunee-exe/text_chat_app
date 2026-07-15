import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/message.dart';

// NOTE: All messages are stored as plaintext at rest in Firestore.
// End-to-end encryption is explicitly out of scope for this MVP.
// This is a known security limitation to be addressed in a future version.

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── User queries ──────────────────────────────────────────────────────────

  Future<AppUser?> getUserByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Looks up a user by their username (case-insensitive).
  Future<AppUser?> getUserByUsername(String username) async {
    try {
      var searchName = username.trim().toLowerCase();
      if (searchName.startsWith('@')) {
        searchName = searchName.substring(1);
      }

      // First lookup the uid from the usernames collection
      final usernameDoc = await _db.collection('usernames').doc(searchName).get();
      if (!usernameDoc.exists) return null;

      final uid = usernameDoc.data()?['uid'] as String?;
      if (uid == null) return null;

      // Then fetch the user by uid
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;

      return AppUser.fromFirestore(userDoc);
    } catch (e) {
      return null;
    }
  }

  Stream<AppUser?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _db.collection('users').doc(uid).update({
      'displayName': displayName.trim(),
    });
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  Future<void> removeFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  // ── Chat queries ──────────────────────────────────────────────────────────

  /// Returns the chatId for the 1:1 chat between two users, or creates it.
  /// Chat doc id = sorted uid pair joined by "_" (deterministic).
  Future<String> getOrCreate1on1Chat(String currentUid, String otherUid) async {
    final sortedUids = [currentUid, otherUid]..sort();
    final chatId = sortedUids.join('_');
    final docRef = _db.collection('chats').doc(chatId);

    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'participants': sortedUids,
        'isGroup': false,
        'groupName': null,
        'lastMessage': '',
        'lastMessageAt': null,
        'lastMessageSenderId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'mutedBy': [],
        'lastReadAt': {},
      });
    }
    return chatId;
  }

  /// Creates a group chat with auto-generated id.
  Future<String> createGroupChat({
    required List<String> participantUids,
    required String groupName,
  }) async {
    final docRef = _db.collection('chats').doc();
    await docRef.set({
      'participants': participantUids,
      'isGroup': true,
      'groupName': groupName.trim(),
      'lastMessage': '',
      'lastMessageAt': null,
      'lastMessageSenderId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'mutedBy': [],
      'lastReadAt': {},
    });
    return docRef.id;
  }

  /// Stream of all chats for a user, sorted by lastMessageAt descending.
  Stream<List<Chat>> chatListStream(String uid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Chat.fromFirestore).toList());
  }

  Stream<Chat?> chatStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc);
    });
  }

  // ── Message queries ───────────────────────────────────────────────────────

  /// Stream of the last [limit] messages in a chat, ordered newest-first.
  Stream<List<Message>> messagesStream(String chatId, {int limit = 50}) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Message.fromFirestore).toList());
  }

  /// Loads an older page of messages (before [before]) for pagination.
  Future<List<Message>> loadMoreMessages(
    String chatId, {
    required Timestamp before,
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .startAfter([before])
        .limit(limit)
        .get();
    return snap.docs.map(Message.fromFirestore).toList();
  }

  /// Sends a message and updates the parent chat's lastMessage fields.
  Future<String> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final msgRef =
        _db.collection('chats').doc(chatId).collection('messages').doc();

    final batch = _db.batch();

    batch.set(msgRef, {
      'senderId': senderId,
      'text': text.trim(),
      'sentAt': FieldValue.serverTimestamp(),
      'deliveredTo': [],
      'readBy': [senderId],
      'deleted': false,
    });

    // Update chat's preview fields
    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': text.trim().length > 60
          ? '${text.trim().substring(0, 60)}…'
          : text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
    });

    await batch.commit();
    return msgRef.id;
  }

  /// Soft-deletes a message (only the sender can do this, enforced by rules).
  Future<void> softDeleteMessage(String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'deleted': true});
  }

  /// Toggles mute for a user on a chat.
  Future<void> toggleMute(String chatId, String uid, {required bool muted}) async {
    await _db.collection('chats').doc(chatId).update({
      'mutedBy': muted
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  /// Updates lastReadAt for the current user — called when entering a chat
  /// or receiving new messages while the chat screen is in foreground.
  Future<void> markAsRead(String chatId, String uid) async {
    await _db.collection('chats').doc(chatId).update({
      'lastReadAt.$uid': FieldValue.serverTimestamp(),
    });
  }

  /// Checks if a user has ever sent a message in a chat (used for requests tab).
  Future<bool> hasUserSentMessage(String chatId, String uid) async {
    final snap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
