import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _usernameController;
  bool _usernameSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).valueOrNull;
    _usernameController = TextEditingController(text: user?.username ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final trimmed = _usernameController.text.trim();
    if (trimmed.isEmpty || trimmed.length < 3 || trimmed.length > 15) return;
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) return;
    
    setState(() => _usernameSaving = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        await ref.read(authServiceProvider).changeUsername(user, trimmed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('username updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('already taken') 
              ? 'That username is already taken.' 
              : 'could not save, try again')
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _usernameSaving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('sign out'),
        content: const Text('are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('sign out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/auth');
  }

  Future<void> _deleteAccount() async {
    final theme = Theme.of(context);
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('delete account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'this action is permanent. type "delete" below to confirm.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(hintText: 'type delete'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
            TextButton(
              onPressed: confirmController.text.trim().toLowerCase() == 'delete'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text('delete account',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Prompt password for re-auth
    final passwordController = TextEditingController();
    // ignore: use_build_context_synchronously
    final password = await showDialog<String>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('confirm your password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('confirm'),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty) return;

    // Capture context-dependent refs before async gap
    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final router = GoRouter.of(context);

    try {
      await ref.read(authServiceProvider).reauthenticate(password);
      await ref.read(authServiceProvider).deleteAccount();
      if (mounted) router.go('/auth');
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(AuthService.friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.gradientTop, Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(TablerIcons.chevron_left,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight),
                        onPressed: () => context.pop(),
                      ),
                      Text('settings', style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    children: [
                      // ── Your Username ──
                      _Section(
                        label: 'username',
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. usman294',
                                  prefixText: '@ ',
                                ),
                                style: TextStyle(
                                    color: AppColors.textPrimary(theme.brightness)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _usernameSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : TextButton(
                                    onPressed: _saveUsername,
                                    child: const Text('save'),
                                  ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // ── Theme ──
                      _Section(
                        label: 'appearance',
                        child: Column(
                          children: [
                            for (final mode in ThemeMode.values)
                              RadioListTile<ThemeMode>(
                                title: Text(
                                  mode.name,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                value: mode,
                                groupValue: themeMode,
                                activeColor: AppColors.accentSolid,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) {
                                  if (v != null) {
                                    ref.read(themeProvider.notifier).setTheme(v);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Sign out ──
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.textSecondary(theme.brightness)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'sign out',
                            style: TextStyle(
                                color: AppColors.textSecondary(theme.brightness)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Delete account ──
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _deleteAccount,
                          child: Text(
                            'delete account',
                            style: TextStyle(
                                color: theme.colorScheme.error, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted(theme.brightness),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
