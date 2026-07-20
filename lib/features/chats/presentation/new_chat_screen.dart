import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../users/data/user_repository.dart';
import '../data/chat_repository.dart';

/// Start a new conversation by looking someone up by their **username**. Toggle
/// group mode to collect several people into a new group.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _search = TextEditingController();
  final _groupName = TextEditingController();
  final _selected = <AppUser>[];

  bool _groupMode = false;
  bool _searching = false;
  AppUser? _result;
  bool _notFound = false;

  @override
  void dispose() {
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _result = null;
      _notFound = false;
    });
    try {
      final user = await ref.read(userRepositoryProvider).findByUsername(query);
      setState(() {
        _result = user;
        _notFound = user == null;
      });
    } catch (_) {
      setState(() => _notFound = true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openDirect(AppUser user) async {
    final repo = ref.read(chatRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await repo.startDirectChat(user);
      if (mounted) context.pushReplacement('/chat/$id');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('could not start chat: $e')));
    }
  }

  void _addToGroup(AppUser user) {
    if (_selected.any((u) => u.id == user.id)) return;
    setState(() {
      _selected.add(user);
      _search.clear();
      _result = null;
    });
  }

  Future<void> _createGroup() async {
    final repo = ref.read(chatRepositoryProvider);
    if (repo == null || _selected.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await repo.createGroup(
        title: _groupName.text,
        memberIds: _selected.map((u) => u.id).toList(),
      );
      if (mounted) context.pushReplacement('/chat/$id');
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('could not create group: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(currentUidProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.darkChip : AppColors.lightCardFill;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text(_groupMode ? 'new group' : 'new chat'),
          actions: [
            TextButton.icon(
              onPressed: () => setState(() {
                _groupMode = !_groupMode;
                _selected.clear();
                _result = null;
                _notFound = false;
              }),
              icon: Icon(_groupMode
                  ? Icons.person_rounded
                  : Icons.group_add_rounded),
              label: Text(_groupMode ? 'single' : 'group'),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_groupMode) ...[
                  TextField(
                    controller: _groupName,
                    decoration: InputDecoration(
                      hintText: 'group name',
                      prefixIcon: const Icon(Icons.groups_rounded),
                      filled: true,
                      fillColor: fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    hintText: 'find someone by @username',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: _runSearch,
                    ),
                    filled: true,
                    fillColor: fill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_result != null)
                  _ResultTile(
                    user: _result!,
                    isSelf: _result!.id == currentUid,
                    groupMode: _groupMode,
                    onTap: () {
                      if (_result!.id == currentUid) return;
                      if (_groupMode) {
                        _addToGroup(_result!);
                      } else {
                        _openDirect(_result!);
                      }
                    },
                  )
                else if (_notFound)
                  const _Hint(
                    icon: Icons.person_off_rounded,
                    text: 'no one found with that username',
                  ),
                if (_groupMode && _selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('members (${_selected.length})',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FrostedCard(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView(
                        children: [
                          for (final u in _selected)
                            ListTile(
                              leading: UserAvatar(
                                  name: u.displayName, seed: u.id, size: 42),
                              title: Text(u.displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text('@${u.username}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () =>
                                    setState(() => _selected.remove(u)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
        ),
        floatingActionButton: _groupMode && _selected.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _createGroup,
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.check_rounded),
                label: Text('create (${_selected.length})'),
              )
            : null,
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.user,
    required this.isSelf,
    required this.groupMode,
    required this.onTap,
  });
  final AppUser user;
  final bool isSelf;
  final bool groupMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      child: ListTile(
        onTap: isSelf ? null : onTap,
        leading: UserAvatar(name: user.displayName, seed: user.id, size: 46),
        title: Text(user.displayName,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(isSelf ? "that's you" : '@${user.username}'),
        trailing: isSelf
            ? null
            : FilledButton.icon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  groupMode
                      ? Icons.add_rounded
                      : Icons.chat_bubble_rounded,
                  size: 18,
                ),
                label: Text(groupMode ? 'add' : 'chat'),
              ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: secondary),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: secondary)),
        ],
      ),
    );
  }
}
