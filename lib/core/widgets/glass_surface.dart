import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A clean "liquid glass" surface: a blurred, translucent panel with a bright
/// rim and a soft drop shadow so it reads as glass even over a flat, light
/// background. Optionally [tint]ed (e.g. with the accent) for primary/active
/// states, and optionally tappable via [onTap].
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.blur = 24,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.tint,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// When set, the glass takes on this colour (used for primary buttons and the
  /// active filter chip) while staying translucent.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final Gradient fill;
    final Color rim;
    if (tint != null) {
      fill = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint!.withValues(alpha: isDark ? 0.42 : 0.34),
          tint!.withValues(alpha: isDark ? 0.24 : 0.18),
        ],
      );
      rim = tint!.withValues(alpha: isDark ? 0.60 : 0.55);
    } else {
      fill = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.06),
              ]
            : [
                // Brighter top-left → subtle bottom-right, but still see-through.
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.18),
              ],
      );
      rim = isDark
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.90);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: fill,
              borderRadius: radius,
              border: Border.all(color: rim, width: 1.2),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill/rounded button rendered as [GlassSurface]. Pass [tint] for the
/// primary action (e.g. the accent) or leave it null for a neutral glass button.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.tint,
    this.borderRadius = 16,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? tint;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = tint != null
        ? (isDark ? Colors.white : AppColors.accent)
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return GlassSurface(
      onTap: onPressed,
      tint: tint,
      borderRadius: borderRadius,
      blur: 18,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 16),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [child],
          ),
        ),
      ),
    );
  }
}
