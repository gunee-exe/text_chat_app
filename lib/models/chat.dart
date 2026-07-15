import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a chat document at chats/{chatId}.
class Chat {
  final String chatId;
  final List<String> participants; // 2 for 1:1, 3+ for group
  final bool isGroup;
  final String? groupName;          // required if isGroup, null otherwise
  final String lastMessage;         // preview, max 60 chars
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final DateTime createdAt;
  final List<String> mutedBy;       // uids who muted this chat
  final Map<String, DateTime> lastReadAt; // {uid: timestamp} for unread tracking

  const Chat({
    required this.chatId,
    required this.participants,
    required this.isGroup,
    this.groupName,
    required this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    required this.createdAt,
    required this.mutedBy,
    required this.lastReadAt,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse lastReadAt map: {uid: Timestamp}
    final rawLastRead = data['lastReadAt'] as Map<String, dynamic>? ?? {};
    final lastReadAt = rawLastRead.map(
      (k, v) => MapEntry(k, (v as Timestamp).toDate()),
    );

    return Chat(
      chatId: doc.id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      isGroup: data['isGroup'] as bool? ?? false,
      groupName: data['groupName'] as String?,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mutedBy: List<String>.from(data['mutedBy'] as List? ?? []),
      lastReadAt: lastReadAt,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'participants': participants,
        'isGroup': isGroup,
        'groupName': groupName,
        'lastMessage': lastMessage,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'lastMessageSenderId': lastMessageSenderId,
        'createdAt': Timestamp.fromDate(createdAt),
        'mutedBy': mutedBy,
        'lastReadAt': lastReadAt.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      };

  bool isMutedBy(String uid) => mutedBy.contains(uid);

  bool hasUnreadFor(String uid) {
    if (lastMessageAt == null) return false;
    if (lastMessageSenderId == uid) return false; // own message, always "read"
    final lastRead = lastReadAt[uid];
    if (lastRead == null) return true;
    return lastMessageAt!.isAfter(lastRead);
  }
}
