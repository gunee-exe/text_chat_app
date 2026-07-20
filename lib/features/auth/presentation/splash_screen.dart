import 'package:flutter/material.dart';

import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/textify_logo.dart';

/// Shown while Firebase resolves the auth + profile state on launch. The router
/// keeps the user here until [AppAuthStatus] settles.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextifyLogo(size: 88, animate: true),
              const SizedBox(height: 28),
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
