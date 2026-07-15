import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'app_theme_mode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(super.initial);

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, mode.name);
  }
}

/// Loads the persisted theme mode from SharedPreferences.
/// Falls back to [ThemeMode.system] if no preference saved.
Future<ThemeMode> loadSavedThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kThemeKey);
  return switch (saved) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

/// Provider initialized with the persisted theme mode.
/// Must be overridden at app startup after reading SharedPreferences.
final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  // Default to system; overridden in main.dart after SharedPreferences loads.
  return ThemeNotifier(ThemeMode.system);
});
