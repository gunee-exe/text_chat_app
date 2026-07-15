import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user in Firestore at users/{uid}.
class AppUser {
  final String uid;
  final String username;
  final String usernameLower;
  final String? photoUrl;
  final DateTime createdAt;
  final List<String> fcmTokens;

  const AppUser({
    required this.uid,
    required this.username,
    required this.usernameLower,
    this.photoUrl,
    required this.createdAt,
    required this.fcmTokens,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      username: data['username'] as String? ?? '',
      usernameLower: data['usernameLower'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmTokens: List<String>.from(data['fcmTokens'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'username': username,
        'usernameLower': usernameLower,
        'photoUrl': photoUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'fcmTokens': fcmTokens,
      };

  AppUser copyWith({
    String? username,
    String? usernameLower,
    String? photoUrl,
    List<String>? fcmTokens,
  }) =>
      AppUser(
        uid: uid,
        username: username ?? this.username,
        usernameLower: usernameLower ?? this.usernameLower,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt,
        fcmTokens: fcmTokens ?? this.fcmTokens,
      );
}
