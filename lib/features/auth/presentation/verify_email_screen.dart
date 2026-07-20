import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_card.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/auth_controller.dart';
import '../data/auth_repository.dart';

/// Gate shown to a signed-in user whose email isn't verified yet. It sends the
/// verification link (already sent at registration), lets them resend, and
/// polls in the background so the app advances automatically once they click
/// the link — no manual refresh needed.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Quietly check every few seconds whether they've verified.
    _poll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => ref.read(authControllerProvider).refreshVerification(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 45);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _resend() async {
    if (_sending || _cooldown > 0) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider).resendVerification();
      messenger.showSnackBar(
        const SnackBar(content: Text('verification email sent')),
      );
      _startCooldown();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('too many attempts, try again shortly')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final verified = await ref.read(authControllerProvider).refreshVerification();
    // If verified, the router redirects and this screen goes away.
    if (!verified && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text("not verified yet — check your inbox")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.read(authRepositoryProvider).currentEmail ?? 'your email';
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
                    Icon(Icons.mark_email_unread_rounded,
                        size: 64, color: AppColors.accent),
                    const SizedBox(height: 16),
                    Text('verify your email',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        text: 'we sent a verification link to\n',
                        style:
                            theme.textTheme.bodyMedium?.copyWith(color: secondary),
                        children: [
                          TextSpan(
                            text: email,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.accent),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FrostedCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'open the link, then come back — this screen updates on its own.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: secondary),
                          ),
                          const SizedBox(height: 16),
                          GlassButton(
                            onPressed: _checkNow,
                            tint: AppColors.accent,
                            child: const Text("i've verified"),
                          ),
                          const SizedBox(height: 12),
                          GlassButton(
                            onPressed: (_sending || _cooldown > 0)
                                ? null
                                : _resend,
                            child: Text(_cooldown > 0
                                ? 'resend in ${_cooldown}s'
                                : 'resend email'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          ref.read(authControllerProvider).signOut(),
                      child: const Text('use a different account',
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
