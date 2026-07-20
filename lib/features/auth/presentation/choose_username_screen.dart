import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_card.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../users/data/user_repository.dart';
import '../data/auth_controller.dart';

/// Shown to a signed-in user who has no Firestore profile yet (Google
/// first-timers, or an email sign-up whose username reservation lost a race).
/// Collects a unique username + a display name, then creates the profile.
class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() =>
      _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider).completeProfile(
            username: _username.text.trim(),
            displayName: _displayName.text.trim(),
          );
      // On success the profile stream fires and the router moves to /chats.
    } on UsernameTakenException {
      setState(() => _serverError = 'that username is taken, try another');
    } catch (e) {
      setState(() => _serverError = 'something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('pick a username',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text('this is how people find you on textify',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    FrostedCard(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _username,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'username',
                                prefixText: '@',
                              ),
                              validator: (v) =>
                                  UserRepository.validate(v ?? ''),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _displayName,
                              decoration: const InputDecoration(
                                hintText: 'display name',
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'add a display name'
                                      : null,
                            ),
                            if (_serverError != null) ...[
                              const SizedBox(height: 12),
                              Text(_serverError!,
                                  style: const TextStyle(
                                      color: Color(0xFFE53935))),
                            ],
                            const SizedBox(height: 20),
                            GlassButton(
                              onPressed: _loading ? null : _submit,
                              tint: AppColors.accent,
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('continue'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => ref.read(authControllerProvider).signOut(),
                      child: const Text('cancel and sign out',
                          style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
