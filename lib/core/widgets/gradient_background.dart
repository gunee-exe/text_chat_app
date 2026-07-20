import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Flat theme background with a #2A8FC0 glow that fades to transparent over the
/// top ~150px only — never a full-screen gradient, and no colour tint below the
/// fade. Screen content renders on top of the glow.
class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.glowHeight = 150,
  });

  final Widget child;
  final double glowHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return ColoredBox(
      color: bg,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: glowHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.gradientTop.withValues(alpha: isDark ? 0.9 : 0.75),
                    AppColors.gradientTop.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
