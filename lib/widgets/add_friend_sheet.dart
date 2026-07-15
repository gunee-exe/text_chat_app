import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

/// Modal bottom sheet for adding a friend by their username.
/// Opened from the chat list; handles lookup, confirmation, and chat creation.
class AddFriendSheet extends ConsumerStatefulWidget {
  final void Function(String chatId, String chatName, String otherUid) onChatCreated;

  const AddFriendSheet({super.key, required this.onChatCreated});

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  AppUser? _foundUser;
  String? _errorText;
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
      _foundUser = null;
    });

    try {
      final currentUser = ref.read(currentUserProvider).valueOrNull;
      if (currentUser == null) return;

      if (input.toLowerCase() == currentUser.usernameLower) {
        setState(() {
          _errorText = "that's your own username";
          _isLoading = false;
        });
        return;
      }

      final service = ref.read(firestoreServiceProvider);
      final found = await service.getUserByUsername(input);

      if (found == null) {
        setState(() {
          _errorText = 'no user found with that username';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _foundUser = found;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorText = 'something went wrong, try again';
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat() async {
    if (_foundUser == null || _isCreating) return;

    // Disable immediately to prevent double-tap
    setState(() => _isCreating = true);

    try {
      final currentUid = ref.read(authStateProvider).valueOrNull?.uid;
      if (currentUid == null) return;

      final service = ref.read(firestoreServiceProvider);
      final chatId = await service.getOrCreate1on1Chat(currentUid, _foundUser!.uid);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onChatCreated(chatId, _foundUser!.username, _foundUser!.uid);
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('could not start chat, try again')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B24) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted(theme.brightness).withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'add friend',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'enter their username to start a conversation',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (v) {
                    // Clear confirmation card on edit
                    if (_foundUser != null || _errorText != null) {
                      setState(() {
                        _foundUser = null;
                        _errorText = null;
                      });
                    }
                  },
                  onSubmitted: (_) => _lookup(),
                  decoration: const InputDecoration(
                    hintText: 'enter their username, e.g. usman294',
                    prefixText: '@ ',
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary(theme.brightness),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _isLoading
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _lookup,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(60, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('find'),
                    ),
            ],
          ),

          // Error message
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorText!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],

          // Confirmation card
          if (_foundUser != null) ...[
            const SizedBox(height: 20),
            _ConfirmationCard(
              user: _foundUser!,
              isCreating: _isCreating,
              onConfirm: _startChat,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  final AppUser user;
  final bool isCreating;
  final VoidCallback onConfirm;

  const _ConfirmationCard({
    required this.user,
    required this.isCreating,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardFill : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Avatar(
            uid: user.uid,
            username: user.username,
            photoUrl: user.photoUrl,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: theme.textTheme.titleMedium),
                Text(
                  '@${user.usernameLower}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isCreating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('message'),
                ),
        ],
      ),
    );
  }
}
