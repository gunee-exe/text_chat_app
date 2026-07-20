import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// The kind of payload a [Message] carries. Only [text] is sent for now; the
/// media types render if present but sending them waits on the Storage phase.
enum MessageType { text, image, video, audio }

MessageType _typeFromName(String? name) => switch (name) {
      'image' => MessageType.image,
      'video' => MessageType.video,
      'audio' => MessageType.audio,
      _ => MessageType.text,
    };

/// A snapshot of the message being replied to, denormalized onto the reply so
/// the quote still renders even if the original is later deleted. Set only at
/// message creation — never mutated afterwards (enforced in the rules).
@immutable
class ReplyRef {
  const ReplyRef({
    required this.messageId,
    required this.senderName,
    required this.snippet,
  });

  final String messageId;
  final String senderName;
  final String snippet;

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderName': senderName,
        'snippet': snippet,
      };

  factory ReplyRef.fromMap(Map<String, dynamic> m) => ReplyRef(
        messageId: (m['messageId'] ?? '') as String,
        senderName: (m['senderName'] ?? '') as String,
        snippet: (m['snippet'] ?? '') as String,
      );
}

@immutable
class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.sentAt,
    this.text = '',
    this.mediaPath,
    this.audioDuration,
    this.replyTo,
    this.reactions = const {},
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final DateTime sentAt;
  final String text;

  /// Remote url / local path of an attachment (media phase only).
  final String? mediaPath;
  final Duration? audioDuration;

  /// The quoted message this one replies to, if any.
  final ReplyRef? replyTo;

  /// uid → emoji. Each user has at most one reaction on a message.
  final Map<String, String> reactions;

  factory Message.fromDoc(
    String chatId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    final ts = data['sentAt'];
    final reply = data['replyTo'];
    final reacts = data['reactions'];
    return Message(
      id: doc.id,
      chatId: chatId,
      senderId: (data['senderId'] ?? '') as String,
      type: _typeFromName(data['type'] as String?),
      text: (data['text'] ?? '') as String,
      mediaPath: data['mediaUrl'] as String?,
      audioDuration: data['audioDurationMs'] == null
          ? null
          : Duration(milliseconds: (data['audioDurationMs'] as num).toInt()),
      sentAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      replyTo: reply is Map
          ? ReplyRef.fromMap(Map<String, dynamic>.from(reply))
          : null,
      reactions: reacts is Map
          ? reacts.map((k, v) => MapEntry(k as String, '$v'))
          : const {},
    );
  }

  /// A short preview used in the chat list and reply snippets.
  String get preview => switch (type) {
        MessageType.text => text,
        MessageType.image => 'photo',
        MessageType.video => 'video',
        MessageType.audio => 'voice message',
      };
}
