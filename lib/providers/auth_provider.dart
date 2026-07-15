import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Stream of the raw Firebase Auth user — drives auth-gated routing.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Stream of the current app user's Firestore document.
/// Automatically updates when username, fcmTokens, etc. change.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(firestoreServiceProvider).userStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});
