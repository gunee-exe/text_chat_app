import 'dart:ui';
import 'package:flutter/material.dart';

/// All design tokens for the text chat app.
/// Every color has explicit dark and light variants — never hardcode single-mode colors.
abstract final class AppColors {
  // ── Gradient ──────────────────────────────────────────────────────────────
  static const Color gradientTop = Color(0xFF2A8FC0);

  // ── Accent ────────────────────────────────────────────────────────────────
  static const Color accentSolid = Color(0xFF406D80);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0B0E14);
  static const Color lightBg = Color(0xFFF7F8FA);

  // ── Card / Surface fills ──────────────────────────────────────────────────
  static const Color darkCardFill = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const Color lightCardFill = Color(0xFFFFFFFF);

  // ── Text — Dark mode ──────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0x73FFFFFF); // rgba(255,255,255,0.45)
  static const Color textMutedDark = Color(0x59FFFFFF);     // rgba(255,255,255,0.35)

  // ── Text — Light mode ─────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // ── Avatar background palette (deterministic, rotate by uid hash) ─────────
  static const List<Color> avatarBackgrounds = [
    Color(0xFFF59E0B), // amber
    Color(0xFF22C55E), // green
    Color(0xFFA855F7), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF3B82F6), // blue
    Color(0xFF14B8A6), // teal
  ];

  /// Matching foreground text for each avatar background (darkest shade, not pure black).
  static const List<Color> avatarTextColors = [
    Color(0xFF1A1200), // on amber
    Color(0xFF052E16), // on green
    Color(0xFF3B0764), // on purple
    Color(0xFF500724), // on pink
    Color(0xFF1E3A8A), // on blue
    Color(0xFF042F2E), // on teal
  ];

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the avatar background color deterministically from a uid.
  /// Hashing guarantees the same uid always maps to the same color.
  static Color avatarBgForUid(String uid) {
    final hash = uid.codeUnits.fold(0, (prev, e) => prev + e);
    return avatarBackgrounds[hash % avatarBackgrounds.length];
  }

  /// Returns the avatar text color paired to a background from [avatarBgForUid].
  static Color avatarTextForUid(String uid) {
    final hash = uid.codeUnits.fold(0, (prev, e) => prev + e);
    return avatarTextColors[hash % avatarTextColors.length];
  }

  /// Returns the correct background depending on [Brightness].
  static Color bg(Brightness brightness) =>
      brightness == Brightness.dark ? darkBg : lightBg;

  /// Returns the correct primary text color depending on [Brightness].
  static Color textPrimary(Brightness brightness) =>
      brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;

  /// Returns the correct secondary text color depending on [Brightness].
  static Color textSecondary(Brightness brightness) =>
      brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;

  /// Returns the correct muted text color depending on [Brightness].
  static Color textMuted(Brightness brightness) =>
      brightness == Brightness.dark ? textMutedDark : textMutedLight;

  /// Returns the correct surface fill depending on [Brightness].
  static Color cardFill(Brightness brightness) =>
      brightness == Brightness.dark ? darkCardFill : lightCardFill;
}
