import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.claimUsername(_usernameController.text.trim());
      // The router will automatically redirect to /chats because currentUserProvider will now emit an AppUser
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('already taken') 
            ? 'That username is already taken.' 
            : 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    TablerIcons.user_circle,
                    size: 80,
                    color: AppColors.accentSolid,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pick a Username',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(theme.brightness),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is how friends will find you on Whispr.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary(theme.brightness),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    style: TextStyle(color: AppColors.textPrimary(theme.brightness)),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'e.g. usman294',
                      prefixIcon: Icon(TablerIcons.at, color: AppColors.textSecondary(theme.brightness)),
                      errorText: _errorMessage,
                    ),
                    validator: (val) {
                      final text = val?.trim() ?? '';
                      if (text.isEmpty) return 'Username cannot be empty';
                      if (text.length < 3) return 'Must be at least 3 characters';
                      if (text.length > 15) return 'Must be less than 15 characters';
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(text)) {
                        return 'Only letters, numbers, and underscores allowed';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
    );
  }
}
