import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/choose_username_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/chats/presentation/chat_detail_screen.dart';
import '../../features/chats/presentation/chats_screen.dart';
import '../../features/chats/presentation/new_chat_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/users/data/user_repository.dart';

/// Bridges a Riverpod provider to [GoRouter]'s `refreshListenable` so the router
/// re-evaluates its redirect whenever the auth/profile status changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(appAuthStatusProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(appAuthStatusProvider);
      final loc = state.matchedLocation;

      switch (status) {
        case AppAuthStatus.loading:
          return loc == '/splash' ? null : '/splash';
        case AppAuthStatus.signedOut:
          return loc == '/login' ? null : '/login';
        case AppAuthStatus.needsVerification:
          return loc == '/verify-email' ? null : '/verify-email';
        case AppAuthStatus.needsProfile:
          return loc == '/choose-username' ? null : '/choose-username';
        case AppAuthStatus.ready:
          // Bounce away from the pre-auth screens once fully signed in.
          if (loc == '/splash' ||
              loc == '/login' ||
              loc == '/verify-email' ||
              loc == '/choose-username') {
            return '/chats';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (c, s) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/choose-username',
        builder: (c, s) => const ChooseUsernameScreen(),
      ),
      GoRoute(path: '/chats', builder: (c, s) => const ChatsScreen()),
      GoRoute(path: '/new', builder: (c, s) => const NewChatScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (c, s) => ChatDetailScreen(chatId: s.pathParameters['id']!),
      ),
    ],
  );
});
