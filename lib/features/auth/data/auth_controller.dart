import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../users/data/user_repository.dart';
import 'auth_repository.dart';

/// Orchestrates the multi-step auth actions (create the Firebase user, then the
/// Firestore profile) so the screens stay thin. Reactive state (who's signed
/// in, whether they have a profile) comes from providers in the repositories,
/// not from here — this class only performs actions and surfaces their errors.
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  AuthRepository get _auth => _ref.read(authRepositoryProvider);
  UserRepository get _users => _ref.read(userRepositoryProvider);

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmail(email.trim(), password);
  }

  /// Create the account and reserve the username **atomically**: either the
  /// account + profile both succeed, or nothing is left behind. This guarantees
  /// an email sign-up that supplied a username never lands on the
  /// choose-username screen (which is only for Google first-timers).
  Future<void> registerWithEmail({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) async {
    // Fail early and friendly before creating any account.
    if (!await _users.isUsernameAvailable(username)) {
      throw UsernameTakenException(username);
    }
    final user = await _auth.registerWithEmail(email.trim(), password);
    try {
      await _users.createProfile(
        uid: user.uid,
        username: username,
        displayName: displayName,
        email: user.email ?? email.trim(),
      );
    } catch (_) {
      // Someone grabbed the name in the tiny gap since the check — don't strand
      // a profile-less account (it would fall through to choose-username).
      await _auth.deleteAccount();
      rethrow;
    }
    // Kick off the verification email right away.
    await _auth.sendEmailVerification();
  }

  /// Re-send the verification email (used from the verify-email screen).
  Future<void> resendVerification() => _auth.sendEmailVerification();

  /// Reload the user from the server and re-evaluate routing. Returns whether
  /// the email is now verified.
  Future<bool> refreshVerification() async {
    await _auth.reloadUser();
    _ref.read(authStateVersionProvider.notifier).state++;
    return _auth.isEmailVerified;
  }

  /// Sign in with Google. First-timers land with no Firestore profile; the
  /// router routes them to choose-username, which calls [completeProfile].
  Future<void> signInWithGoogle() async {
    await _auth.signInWithGoogle();
  }

  /// Finish setting up a profile for the currently signed-in user (used by the
  /// choose-username screen for Google first-timers or a failed registration).
  Future<void> completeProfile({
    required String username,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _users.createProfile(
      uid: user.uid,
      username: username,
      // Never fall back to the Google account name — use what they typed.
      displayName: displayName.isEmpty ? username : displayName,
      email: user.email ?? '',
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() => _auth.deleteAccount();
}

final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));
