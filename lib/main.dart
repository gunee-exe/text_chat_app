import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/message_notifier.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/users/data/user_repository.dart';

Future<void> main() async {
  // Firebase must be ready before any provider touches Auth/Firestore.
  WidgetsFlutterBinding.ensureInitialized();
  // No firebase_options.dart — Android reads google-services.json and iOS reads
  // GoogleService-Info.plist (added via the Firebase console setup).
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: TextifyApp()));
}

class TextifyApp extends ConsumerStatefulWidget {
  const TextifyApp({super.key});

  @override
  ConsumerState<TextifyApp> createState() => _TextifyAppState();
}

class _TextifyAppState extends ConsumerState<TextifyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = ref.read(notificationServiceProvider);
      service.onOpenChat = _openChat;
      await service.init();
      await service.requestPermissions();
    });
  }

  /// Deep-link from a tapped notification. Only routes once the app is fully
  /// ready; otherwise it's queued and opened when [AppAuthStatus.ready] lands
  /// (same gate the redirect logic uses).
  void _openChat(String chatId) {
    if (ref.read(appAuthStatusProvider) == AppAuthStatus.ready) {
      ref.read(routerProvider).push('/chat/$chatId');
    } else {
      ref.read(pendingChatIdProvider.notifier).state = chatId;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the message → notification listener alive for the app's lifetime.
    ref.watch(messageNotifierProvider);

    // Flush a queued notification-tap once the app becomes ready.
    ref.listen(appAuthStatusProvider, (_, next) {
      if (next == AppAuthStatus.ready) {
        final pending = ref.read(pendingChatIdProvider);
        if (pending != null) {
          ref.read(pendingChatIdProvider.notifier).state = null;
          ref.read(routerProvider).push('/chat/$pending');
        }
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'textify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
