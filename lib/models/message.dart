import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a message document at chats/{chatId}/messages/{messageId}.
class Message {
  final String messageId;
  final String senderId;
  final String text;           // 1-2000 chars, never whitespace-only
  final DateTime sentAt;
  final List<String> deliveredTo;
  final List<String> readBy;
  final bool deleted;          // soft delete — render as "message deleted" placeholder

  // Optimistic UI state (not stored in Firestore)
  final MessageStatus status;

  const Message({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.deliveredTo,
    required this.readBy,
    required this.deleted,
    this.status = MessageStatus.sent,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      messageId: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveredTo: List<String>.from(data['deliveredTo'] as List? ?? []),
      readBy: List<String>.from(data['readBy'] as List? ?? []),
      deleted: data['deleted'] as bool? ?? false,
      status: MessageStatus.sent,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'senderId': senderId,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(), // always server timestamp
        'deliveredTo': deliveredTo,
        'readBy': readBy,
        'deleted': deleted,
      };

  Message copyWith({MessageStatus? status, bool? deleted}) => Message(
        messageId: messageId,
        senderId: senderId,
        text: text,
        sentAt: sentAt,
        deliveredTo: deliveredTo,
        readBy: readBy,
        deleted: deleted ?? this.deleted,
        status: status ?? this.status,
      );
}

enum MessageStatus {
  sending,  // optimistic, in-flight
  sent,     // confirmed by Firestore
  failed,   // write failed — show retry
}
