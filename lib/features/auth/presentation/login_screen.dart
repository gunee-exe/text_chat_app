import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_card.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/textify_logo.dart';
import '../../../core/widgets/typewriter_text.dart';
import '../../users/data/user_repository.dart';
import '../data/auth_controller.dart';

/// Email + Google sign-in / register. On success the router redirects based on
/// the resolved auth/profile state — this screen just performs the action.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    if (e is UsernameTakenException) return 'that username is taken';
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-email' => 'that email looks invalid',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'wrong email or password',
        'email-already-in-use' => 'that email is already registered',
        'weak-password' => 'password is too weak',
        'network-request-failed' => 'network error, check your connection',
        'sign-in-cancelled' => 'sign-in cancelled',
        _ => e.message ?? 'authentication failed',
      };
    }
    return 'something went wrong';
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
      // Success → router redirects automatically.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = ref.read(authControllerProvider);
    await _run(() async {
      if (_isRegister) {
        await auth.registerWithEmail(
          username: _username.text.trim(),
          displayName: _displayName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signInWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

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
                    const Center(child: TextifyLogo(size: 76)),
                    const SizedBox(height: 12),
                    Center(
                      child: TypewriterText(
                        'textify',
                        // weight 600 is reserved for the app name only.
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRegister ? 'create your account' : 'welcome back',
                      textAlign: TextAlign.center,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: secondary),
                    ),
                    const SizedBox(height: 28),
                    FrostedCard(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isRegister) ...[
                              _Field(
                                controller: _username,
                                hint: 'username',
                                icon: Icons.alternate_email_rounded,
                                validator: (v) =>
                                    UserRepository.validate(v ?? ''),
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                controller: _displayName,
                                hint: 'display name',
                                icon: Icons.person_outline_rounded,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'add a display name'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            _Field(
                              controller: _email,
                              hint: 'email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              controller: _password,
                              hint: 'password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'at least 6 characters'
                                  : null,
                              suffix: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            const SizedBox(height: 20),
                            GlassButton(
                              onPressed: _loading ? null : _submitEmail,
                              tint: AppColors.accent,
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(_isRegister ? 'sign up' : 'sign in'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(color: theme.dividerColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text('or',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: secondary)),
                                ),
                                Expanded(
                                    child: Divider(color: theme.dividerColor)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GlassButton(
                              onPressed: _loading
                                  ? null
                                  : () => _run(ref
                                      .read(authControllerProvider)
                                      .signInWithGoogle),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.g_mobiledata_rounded, size: 28),
                                  SizedBox(width: 6),
                                  Text('continue with google'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _isRegister = !_isRegister),
                      child: Text.rich(
                        TextSpan(
                          text: _isRegister
                              ? 'already have an account?  '
                              : 'new here?  ',
                          style: TextStyle(color: secondary),
                          children: [
                            TextSpan(
                              text: _isRegister ? 'sign in' : 'create one',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? AppColors.darkChip : AppColors.lightChip,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

