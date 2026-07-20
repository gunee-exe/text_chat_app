import 'package:flutter/material.dart';

/// Central colour palette for Textify.
///
/// Design language: a single #2A8FC0 glow that fades to transparent over the
/// top ~150px of a screen, sitting on a flat background (no full-screen
/// gradient, no residual tint below the fade). Rows are plain — cards are only
/// used for secondary surfaces (settings groups, the contacts list, etc.).
class AppColors {
  AppColors._();

  /// Top glow — fades to transparent over ~150px. Not a full-screen fill.
  static const Color gradientTop = Color.fromARGB(255, 12, 163, 228);

  /// The single accent: active tab pill, send icon, primary buttons.
  static const Color accent = Color.fromARGB(255, 53, 119, 148);

  // ---- Backgrounds (flat, below the fade) ---------------------------------
  static const Color darkBg = Color(0xFF0B0E14);
  static const Color lightBg = Color.fromARGB(255, 202, 211, 231);

  // ---- Secondary surfaces (NOT default row backgrounds) -------------------
  static const Color darkCardFill = Color(0x12FFFFFF); // white @ 0.07
  static const Color lightCardFill = Color(0xFFFFFFFF);

  // Inactive pill / input field fills.
  static const Color darkChip = Color(0x12FFFFFF); // white @ 0.07
  static const Color lightChip = Color(0xFFECEFF3);

  // Incoming message bubble.
  static const Color darkBubbleIn = Color(0x12FFFFFF);
  static const Color lightBubbleIn = Color(0xFFFFFFFF);

  // ---- Text ----------------------------------------------------------------
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0x73FFFFFF); // white @ 0.45
  static const Color textMutedDark = Color(0x59FFFFFF); // white @ 0.35
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  static const Color darkDivider = Color(0x12FFFFFF);
  static const Color lightDivider = Color(0xFFE7EAEF);

  /// Avatar background + initials colour pairs. Rotate deterministically by
  /// hashing the user's id (never random per render). Initials use the darkest
  /// matching shade of the same hue — never pure black.
  static const List<(Color bg, Color fg)> avatarColors = [
    (Color(0xFFF59E0B), Color(0xFF1A1200)), // amber
    (Color(0xFF22C55E), Color(0xFF052E16)), // green
    (Color(0xFFA855F7), Color(0xFF2E1065)), // purple
    (Color(0xFFEC4899), Color(0xFF500724)), // pink
    (Color(0xFF3B82F6), Color(0xFF172554)), // blue
    (Color(0xFF14B8A6), Color(0xFF042F2E)), // teal
  ];

  /// Stable index into [avatarColors] for a given seed (uid).
  static (Color bg, Color fg) avatarColorFor(String seed) {
    var hash = 0;
    for (final c in seed.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return avatarColors[hash % avatarColors.length];
  }
}
