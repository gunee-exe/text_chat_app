import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A Textify user profile, backed by `users/{uid}` in Firestore.
///
/// [username] is globally unique and has no spaces (enforced via the
/// `usernames/{username}` index). [displayName] is free text and may be shared
/// by several users.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    this.note = '',
    this.photoUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String email;

  /// The user's status / note shown around the app (e.g. "omw, 10 mins").
  final String note;
  final String? photoUrl;

  /// Build from a Firestore document.
  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      id: doc.id,
      username: (data['username'] ?? '') as String,
      displayName: (data['displayName'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      note: (data['note'] ?? '') as String,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  /// Serialize for writing to `users/{uid}`. [id] is the doc id, not a field.
  Map<String, dynamic> toMap() => {
        'username': username,
        'displayName': displayName,
        'email': email,
        'note': note,
        'photoUrl': photoUrl,
      };

  AppUser copyWith({
    String? username,
    String? displayName,
    String? note,
    String? photoUrl,
  }) {
    return AppUser(
      id: id,
      email: email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      note: note ?? this.note,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.username == username &&
      other.displayName == displayName &&
      other.email == email &&
      other.note == note &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode =>
      Object.hash(id, username, displayName, email, note, photoUrl);
}
