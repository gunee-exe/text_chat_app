import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferred orientation: portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load persisted theme before first frame
  final savedTheme = await loadSavedThemeMode();

  runApp(
    ProviderScope(
      overrides: [
        // Override theme provider with persisted value
        themeProvider.overrideWith((ref) => ThemeNotifier(savedTheme)),
      ],
      child: const App(),
    ),
  );
}