import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded-square avatar (11px radius) with a solid, per-user colour and
/// initials in the darkest matching shade. Colour is chosen deterministically
/// from the seed/uid so a person always keeps the same colour.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.seed,
    this.imageUrl,
    this.size = 48,
    this.isGroup = false,
  });

  final String name;

  /// Stable id used to pick a consistent colour. Falls back to [name].
  final String? seed;
  final String? imageUrl;
  final double size;
  final bool isGroup;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AppColors.avatarColorFor(seed ?? name);

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = Image.network(imageUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsChild(bg, fg));
    } else {
      content = _initialsChild(bg, fg);
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: content,
      ),
    );
  }

  Widget _initialsChild(Color bg, Color fg) {
    return ColoredBox(
      color: bg,
      child: Center(
        child: isGroup
            ? Icon(Icons.groups_rounded, color: fg, size: size * 0.5)
            : Text(
                _initials,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w500,
                  fontSize: size * 0.34,
                ),
              ),
      ),
    );
  }
}
