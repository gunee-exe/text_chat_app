import 'package:flutter/material.dart';

import 'glass_surface.dart';

/// A liquid-glass card. Thin wrapper over [GlassSurface] kept for the many
/// existing call sites (login card, settings groups, contacts list, etc.).
/// Chat-list rows stay plain and do not use this.
class FrostedCard extends StatelessWidget {
  const FrostedCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 22,
    this.blur = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: borderRadius,
      blur: blur,
      padding: padding,
      child: child,
    );
  }
}
