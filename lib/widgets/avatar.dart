import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Displays either a network image (photoUrl) or colored initials square.
/// Avatar background and text colors are deterministically chosen from uid.
class Avatar extends StatelessWidget {
  final String uid;
  final String username;
  final String? photoUrl;
  final double size;

  const Avatar({
    super.key,
    required this.uid,
    required this.username,
    this.photoUrl,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.avatar),
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialsAvatar(
                  uid: uid,
                  username: username,
                  size: size,
                ),
              )
            : _InitialsAvatar(uid: uid, username: username, size: size),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String uid;
  final String username;
  final double size;

  const _InitialsAvatar({
    required this.uid,
    required this.username,
    required this.size,
  });

  String _initials() {
    final parts = username.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.trim().isNotEmpty
        ? username.trim().substring(0, username.trim().length.clamp(1, 2)).toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.avatarBgForUid(uid);
    final fg = AppColors.avatarTextForUid(uid);
    final fontSize = (size * 0.38).clamp(10.0, 20.0);

    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Text(
        _initials(),
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

/// A compact overlapping avatar cluster for group chat headers.
/// Shows up to 3 mini avatars stacked diagonally.
class GroupAvatarCluster extends StatelessWidget {
  final List<({String uid, String username, String? photoUrl})> members;
  final double size;

  const GroupAvatarCluster({
    super.key,
    required this.members,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final visible = members.take(3).toList();
    final miniSize = size * 0.6;
    final offset = miniSize * 0.45;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (int i = visible.length - 1; i >= 0; i--)
            Positioned(
              left: i * offset,
              top: i * offset * 0.4,
              child: Avatar(
                uid: visible[i].uid,
                username: visible[i].username,
                photoUrl: visible[i].photoUrl,
                size: miniSize,
              ),
            ),
        ],
      ),
    );
  }
}
