import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Email / Password Auth ───────────────────────────────────────────────────

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // User is authenticated, but no Firestore document is created yet.
    // They must pick a username next.
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── Google Auth ─────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // User canceled

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    await _auth.signInWithCredential(credential);
  }

  // ── Sign Out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Username Management ─────────────────────────────────────────────────────

  /// Checks if the lowercase username is available.
  Future<bool> isUsernameAvailable(String username) async {
    final usernameLower = username.trim().toLowerCase();
    if (usernameLower.isEmpty) return false;

    final doc = await _db.collection('usernames').doc(usernameLower).get();
    return !doc.exists;
  }

  /// Claims a username for the currently authenticated user.
  /// Throws an exception if the username is already taken.
  Future<AppUser> claimUsername(String username) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to claim a username');

    final usernameTrimmed = username.trim();
    final usernameLower = usernameTrimmed.toLowerCase();

    // Use a transaction to ensure atomic username reservation
    return await _db.runTransaction((transaction) async {
      final usernameRef = _db.collection('usernames').doc(usernameLower);
      final usernameDoc = await transaction.get(usernameRef);

      if (usernameDoc.exists) {
        throw Exception('Username is already taken');
      }

      final userRef = _db.collection('users').doc(user.uid);

      final appUser = AppUser(
        uid: user.uid,
        username: usernameTrimmed,
        usernameLower: usernameLower,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
        fcmTokens: [],
      );

      // Reserve the username
      transaction.set(usernameRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create the user document
      transaction.set(userRef, appUser.toFirestore());

      return appUser;
    });
  }

  /// Changes the username of an existing user.
  Future<void> changeUsername(AppUser appUser, String newUsername) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != appUser.uid) {
      throw Exception('Must be logged in to change username');
    }

    final newUsernameTrimmed = newUsername.trim();
    final newUsernameLower = newUsernameTrimmed.toLowerCase();
    final oldUsernameLower = appUser.usernameLower;

    if (newUsernameLower == oldUsernameLower) return;

    await _db.runTransaction((transaction) async {
      final newUsernameRef = _db.collection('usernames').doc(newUsernameLower);
      final newUsernameDoc = await transaction.get(newUsernameRef);

      if (newUsernameDoc.exists) {
        throw Exception('Username is already taken');
      }

      final oldUsernameRef = _db.collection('usernames').doc(oldUsernameLower);
      final userRef = _db.collection('users').doc(user.uid);

      // Reserve new username
      transaction.set(newUsernameRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user doc
      transaction.update(userRef, {
        'username': newUsernameTrimmed,
        'usernameLower': newUsernameLower,
      });

      // Release old username
      transaction.delete(oldUsernameRef);
    });
  }

  // ── Delete Account ──────────────────────────────────────────────────────────

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _db.batch();

    // 1. Fetch user doc to get their username
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final appUser = AppUser.fromFirestore(userDoc);
      // Delete the username reservation
      batch.delete(_db.collection('usernames').doc(appUser.usernameLower));
    }

    // 2. Remove uid from chats
    final chatsSnap = await _db
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .get();

    for (final doc in chatsSnap.docs) {
      batch.update(doc.reference, {
        'participants': FieldValue.arrayRemove([user.uid]),
      });
    }

    // 3. Delete user doc
    batch.delete(_db.collection('users').doc(user.uid));
    await batch.commit();

    await user.delete();
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('No current user');
    final credential =
        EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  // ── Human-readable error mapping ──────────────────────────────────────────

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'weak-password':
          return 'Password must be at least 8 characters.';
        case 'network-request-failed':
          return 'Check your connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts, try again in a bit.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'requires-recent-login':
          return 'Please re-enter your password to continue.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    if (e.toString().contains('already taken')) {
      return 'That username is already taken.';
    }
    return 'Something went wrong. Please try again.';
  }
}
