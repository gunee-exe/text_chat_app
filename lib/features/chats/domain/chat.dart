import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'message.dart';

/// A conversation document (`chats/{chatId}`) — either 1:1 or a group.
///
/// Per-user fields (unread, muted) are resolved for the current user when the
/// document is mapped, so the UI can treat [unreadCount] / [muted] as plain
/// values. For 1:1 chats [title] is empty and the UI resolves the other
/// person's display name via their profile (names can change).
@immutable
class Chat {
  const Chat({
    required this.id,
    required this.title,
    required this.memberIds,
    this.isGroup = false,
    this.photoUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.muted = false,
  });

  final String id;
  final String title;
  final List<String> memberIds;
  final bool isGroup;
  final String? photoUrl;
  final Message? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool muted;

  DateTime get sortTime => lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// The other participant in a 1:1 chat (empty for groups / self-only).
  String otherMemberId(String currentUid) => memberIds.firstWhere(
        (m) => m != currentUid,
        orElse: () => currentUid,
      );

  factory Chat.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String currentUid,
  ) {
    final data = doc.data() ?? const {};
    final members = List<String>.from(data['memberIds'] ?? const []);
    final unread = Map<String, dynamic>.from(data['unread'] ?? const {});
    final muted = Map<String, dynamic>.from(data['muted'] ?? const {});
    final lastMap = data['lastMessage'] as Map<String, dynamic>?;
    final lastAt = data['lastMessageAt'];
    final lastDate = lastAt is Timestamp ? lastAt.toDate() : null;

    return Chat(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      isGroup: (data['isGroup'] ?? false) as bool,
      memberIds: members,
      photoUrl: data['photoUrl'] as String?,
      lastMessageAt: lastDate,
      lastMessage: lastMap == null
          ? null
          : Message(
              id: (lastMap['id'] ?? '') as String,
              chatId: doc.id,
              senderId: (lastMap['senderId'] ?? '') as String,
              type: switch (lastMap['type']) {
                'image' => MessageType.image,
                'video' => MessageType.video,
                'audio' => MessageType.audio,
                _ => MessageType.text,
              },
              text: (lastMap['text'] ?? '') as String,
              sentAt: lastDate ?? DateTime.now(),
            ),
      unreadCount: (unread[currentUid] as num?)?.toInt() ?? 0,
      muted: (muted[currentUid] as bool?) ?? false,
    );
  }
}
