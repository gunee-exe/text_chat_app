import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';

/// Raised when a username is already reserved by someone else.
class UsernameTakenException implements Exception {
  UsernameTakenException(this.username);
  final String username;
  @override
  String toString() => 'that username is already taken';
}

/// Reads/writes user profiles and enforces username uniqueness through the
/// `usernames/{username}` index. Usernames are the doc id there, so they double
/// as a uniqueness constraint and an O(1) "find user by username" lookup.
class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  /// Usernames are lowercase, 3–20 chars, letters/digits/._ and no spaces.
  static final RegExp usernamePattern = RegExp(r'^[a-z0-9._]{3,20}$');

  static String normalize(String raw) => raw.trim().toLowerCase();

  static String? validate(String raw) {
    final u = normalize(raw);
    if (u.isEmpty) return 'choose a username';
    if (u.contains(' ')) return 'no spaces allowed';
    if (!usernamePattern.hasMatch(u)) {
      return '3–20 chars: letters, numbers, . or _';
    }
    return null;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _usernames.doc(normalize(username)).get();
    return !doc.exists;
  }

  /// Reserve [username] and create `users/{uid}` atomically. Throws
  /// [UsernameTakenException] if someone grabbed the name first.
  Future<void> createProfile({
    required String uid,
    required String username,
    required String displayName,
    required String email,
  }) async {
    final uname = normalize(username);
    await _db.runTransaction((tx) async {
      final unameRef = _usernames.doc(uname);
      if ((await tx.get(unameRef)).exists) {
        throw UsernameTakenException(uname);
      }
      tx.set(unameRef, {'uid': uid});
      tx.set(_users.doc(uid), {
        'username': uname,
        'displayName': displayName.trim(),
        'email': email,
        'note': '',
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Change username only if the new one is free. Frees the old name.
  Future<void> changeUsername({
    required String uid,
    required String oldUsername,
    required String newUsername,
  }) async {
    final newName = normalize(newUsername);
    final oldName = normalize(oldUsername);
    if (newName == oldName) return;
    await _db.runTransaction((tx) async {
      final newRef = _usernames.doc(newName);
      if ((await tx.get(newRef)).exists) {
        throw UsernameTakenException(newName);
      }
      tx.set(newRef, {'uid': uid});
      if (oldName.isNotEmpty) tx.delete(_usernames.doc(oldName));
      tx.update(_users.doc(uid), {'username': newName});
    });
  }

  /// Find a user by exact username (how people discover each other).
  Future<AppUser?> findByUsername(String username) async {
    final unameDoc = await _usernames.doc(normalize(username)).get();
    if (!unameDoc.exists) return null;
    final uid = unameDoc.data()!['uid'] as String;
    final userDoc = await _users.doc(uid).get();
    return userDoc.exists ? AppUser.fromDoc(userDoc) : null;
  }

  Stream<AppUser?> watchUser(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> getUser(String uid) async {
    final d = await _users.doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Future<void> updateDisplayName(String uid, String displayName) =>
      _users.doc(uid).update({'displayName': displayName.trim()});

  Future<void> updateNote(String uid, String note) =>
      _users.doc(uid).update({'note': note.trim()});
}

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(FirebaseFirestore.instance));

/// The signed-in user's own profile (null while loading or if no profile yet).
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Any user's profile by uid — used to render names/avatars in chats.
final userProfileProvider = StreamProvider.family<AppUser?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchUser(uid),
);

/// Where the app should route the user, derived from auth + profile state.
enum AppAuthStatus { loading, signedOut, needsVerification, needsProfile, ready }

/// Bumped after `reloadUser()` so [appAuthStatusProvider] re-evaluates the
/// (now-updated) `emailVerified` flag — the auth stream doesn't refire on
/// reload, so we nudge it manually.
final authStateVersionProvider = StateProvider<int>((ref) => 0);

final appAuthStatusProvider = Provider<AppAuthStatus>((ref) {
  ref.watch(authStateVersionProvider);
  final auth = ref.watch(authStateProvider);
  return auth.when(
    loading: () => AppAuthStatus.loading,
    error: (_, __) => AppAuthStatus.signedOut,
    data: (user) {
      if (user == null) return AppAuthStatus.signedOut;
      // Read `emailVerified` from the LIVE currentUser, not this stream
      // snapshot: after reloadUser() the snapshot stays stale (the auth stream
      // doesn't refire on reload), so we'd otherwise never leave this gate
      // without an app restart. Google accounts come pre-verified.
      final verified = ref.watch(authRepositoryProvider).isEmailVerified;
      if (!verified) return AppAuthStatus.needsVerification;
      final profile = ref.watch(currentUserProfileProvider);
      return profile.when(
        loading: () => AppAuthStatus.loading,
        error: (_, __) => AppAuthStatus.loading,
        data: (p) =>
            p == null ? AppAuthStatus.needsProfile : AppAuthStatus.ready,
      );
    },
  );
});
