import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Branded loading screen shown on app launch.
/// Minimum 1-second display so it doesn't flash.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  bool _minDelayPassed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _minDelayPassed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Navigate once both the min delay has passed and auth state is resolved
    if (_minDelayPassed && !authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final user = authState.valueOrNull;
        context.go(user != null ? '/chats' : '/auth');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon placeholder (chat bubble icon)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accentSolid,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'chats',
                style: GoogleFonts.fredoka(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
