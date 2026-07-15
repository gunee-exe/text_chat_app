import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';

import '../screens/setup_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUserState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (authState.isLoading || currentUserState.isLoading) return '/splash';

      final userAuth = authState.valueOrNull;
      final appUser = currentUserState.valueOrNull;

      final onSplash = state.uri.path == '/splash';
      final onAuth = state.uri.path == '/auth';
      final onSetup = state.uri.path == '/setup';

      if (userAuth == null && !onAuth && !onSplash) return '/auth';
      
      // If authenticated but no username set (appUser == null), force to /setup
      if (userAuth != null && appUser == null && !onSetup) return '/setup';
      
      // If authenticated AND has username, go to chats
      if (userAuth != null && appUser != null && (onAuth || onSplash || onSetup)) return '/chats';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (_, __) => const SetupProfileScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (_, __) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            chatId: chatId,
            chatName: extra?['chatName'] as String? ?? '',
            otherUid: extra?['otherUid'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
});

