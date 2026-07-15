import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

/// Single auth screen toggling between login and signup modes.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isSignup = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _animController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignup = !_isSignup;
      _errorText = null;
    });
    _animController
      ..reset()
      ..forward();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(v.trim())) return 'enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'password is required';
    if (v.length < 8) return 'password must be at least 8 characters';
    return null;
  }


  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      if (_isSignup) {
        await authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      // GoRouter will redirect to /chats via auth state change
    } catch (e) {
      setState(() {
        _errorText = AuthService.friendlyError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _submitGoogle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      // GoRouter will redirect to /chats or /setup via auth state change
    } catch (e) {
      setState(() {
        _errorText = AuthService.friendlyError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient header (top 150px)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: size.height * 0.12),

                      // App name
                      Text(
                        'chats',
                        style: GoogleFonts.fredoka(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSignup ? 'create an account' : 'welcome back',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary(theme.brightness),
                        ),
                      ),
                      SizedBox(height: size.height * 0.06),


                      // Email
                      TextFormField(
                        controller: _emailController,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(hintText: 'email'),
                        style: TextStyle(
                          color: AppColors.textPrimary(theme.brightness),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        validator: _validatePassword,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textMuted(theme.brightness),
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        style: TextStyle(
                          color: AppColors.textPrimary(theme.brightness),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Inline error
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_isSignup ? 'create account' : 'sign in'),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Google Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _submitGoogle,
                          icon: _isLoading 
                            ? const SizedBox.shrink() 
                            : Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                                height: 24,
                              ),
                          label: Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              fontSize: 16,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Toggle login/signup
                      Center(
                        child: TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isSignup
                                ? 'already have an account? sign in'
                                : "don't have an account? sign up",
                            style: TextStyle(
                              color: AppColors.textSecondary(theme.brightness),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
