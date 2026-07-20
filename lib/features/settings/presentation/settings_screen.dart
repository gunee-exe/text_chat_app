import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/frosted_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../users/data/user_repository.dart';

/// Profile & account settings, backed by Firestore. Username changes go through
/// the uniqueness transaction and surface a "taken" error; display name and
/// note update freely. Sign-out / delete flip the auth state and the router
/// takes the user back to /login.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProfileProvider).valueOrNull;

    if (user == null) {
      return const GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final themeMode = ref.watch(themeControllerProvider);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('settings'),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FrostedCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    UserAvatar(
                        name: user.displayName, seed: user.id, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName,
                              style: theme.textTheme.titleLarge),
                          Text('@${user.username}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: secondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('profile'),
              FrostedCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.alternate_email_rounded,
                      color: const Color(0xFF3B82F6),
                      title: 'username',
                      subtitle: '@${user.username}',
                      onTap: () => _editUsername(context, ref, user),
                    ),
                    const _TileDivider(),
                    _SettingsTile(
                      icon: Icons.badge_rounded,
                      color: const Color(0xFFA855F7),
                      title: 'display name',
                      subtitle: user.displayName,
                      onTap: () => _editText(
                        context,
                        title: 'edit display name',
                        initial: user.displayName,
                        onSave: (v) => ref
                            .read(userRepositoryProvider)
                            .updateDisplayName(user.id, v),
                      ),
                    ),
                    const _TileDivider(),
                    _SettingsTile(
                      icon: Icons.mood_rounded,
                      color: const Color(0xFF14B8A6),
                      title: 'status / note',
                      subtitle: user.note.isEmpty ? 'set a status' : user.note,
                      onTap: () => _editText(
                        context,
                        title: 'edit status',
                        initial: user.note,
                        onSave: (v) => ref
                            .read(userRepositoryProvider)
                            .updateNote(user.id, v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('appearance'),
              FrostedCard(
                child: Column(
                  children: [
                    for (final mode in ThemeMode.values) ...[
                      if (mode != ThemeMode.values.first) const _TileDivider(),
                      _ThemeOption(
                        mode: mode,
                        groupValue: themeMode,
                        onChanged: (m) =>
                            ref.read(themeControllerProvider.notifier).set(m),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('account'),
              FrostedCard(
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      color: const Color(0xFFF59E0B),
                      title: 'sign out',
                      onTap: () => _confirmSignOut(context, ref),
                    ),
                    const _TileDivider(),
                    _SettingsTile(
                      icon: Icons.delete_forever_rounded,
                      color: const Color(0xFFE53935),
                      title: 'delete account',
                      titleColor: const Color(0xFFE53935),
                      onTap: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('textify · v1.0.0',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: secondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String initial,
    String? prefixText,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              InputDecoration(hintText: 'type here', prefixText: prefixText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _promptText(context, title: title, initial: initial);
    if (result == null || result.isEmpty || result == initial) return;
    try {
      await onSave(result);
      messenger.showSnackBar(const SnackBar(content: Text('saved')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('could not save')));
    }
  }

  Future<void> _editUsername(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _promptText(
      context,
      title: 'edit username',
      initial: user.username,
      prefixText: '@',
    );
    if (result == null || result == user.username) return;

    final invalid = UserRepository.validate(result);
    if (invalid != null) {
      messenger.showSnackBar(SnackBar(content: Text(invalid)));
      return;
    }
    try {
      await ref.read(userRepositoryProvider).changeUsername(
            uid: user.id,
            oldUsername: user.username,
            newUsername: result,
          );
      messenger
          .showSnackBar(const SnackBar(content: Text('username updated')));
    } on UsernameTakenException {
      messenger.showSnackBar(
          const SnackBar(content: Text('that username is taken')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('could not update username')));
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('sign out?'),
        content: const Text('you can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('sign out'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider).signOut();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('delete account?'),
        content: const Text(
            'this permanently removes your account. this cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authControllerProvider).deleteAccount();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('please sign in again before deleting')));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: secondary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w500, color: titleColor)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.groupValue,
    required this.onChanged,
  });
  final ThemeMode mode;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, 'system default'),
      ThemeMode.light => (Icons.light_mode_rounded, 'light'),
      ThemeMode.dark => (Icons.dark_mode_rounded, 'dark'),
    };
    final selected = mode == groupValue;
    return ListTile(
      onTap: () => onChanged(mode),
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w400)),
      trailing: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.accent : null,
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).dividerColor,
    );
  }
}
