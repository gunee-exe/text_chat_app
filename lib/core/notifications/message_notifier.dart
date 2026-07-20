import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/chats/data/chat_repository.dart';
import '../../features/chats/domain/chat.dart';
import '../../features/chats/domain/message.dart';
import '../../features/users/data/user_repository.dart';
import 'notification_service.dart';

/// The chatId currently open on screen (set by ChatDetailScreen). We never
/// notify for the chat the user is already looking at.
final openChatIdProvider = StateProvider<String?>((ref) => null);

/// A chatId from a tapped notification to open once the app is ready (used when
/// the tap arrives before auth/profile have settled).
final pendingChatIdProvider = StateProvider<String?>((ref) => null);

/// Watches the aggregate "all my chats" stream (the same one that powers unread
/// badges) and fires a local notification for each genuinely new message —
/// skipping ones I sent, muted chats, and the chat I'm currently viewing.
/// Deduped on message id against redelivered snapshots. Kept alive by being
/// watched at the app root.
final messageNotifierProvider = Provider<void>((ref) {
  final currentUid = ref.watch(currentUidProvider);
  if (currentUid == null) return; // only while signed in

  final service = ref.watch(notificationServiceProvider);
  final userRepo = ref.watch(userRepositoryProvider);

  final seen = <String>{};
  var seeded = false;

  ref.listen<AsyncValue<List<Chat>>>(chatsStreamProvider, (_, next) {
    final chats = next.valueOrNull;
    if (chats == null) return;

    // The first real snapshot is history — record ids, don't notify.
    if (!seeded) {
      for (final c in chats) {
        final id = c.lastMessage?.id;
        if (id != null && id.isNotEmpty) seen.add(id);
      }
      seeded = true;
      return;
    }

    for (final chat in chats) {
      final last = chat.lastMessage;
      if (last == null || last.id.isEmpty) continue;
      if (seen.contains(last.id)) continue; // dedupe redelivery
      seen.add(last.id);

      if (last.senderId == currentUid) continue; // sent by me
      if (chat.muted) continue; // muted this chat
      if (ref.read(openChatIdProvider) == chat.id) continue; // already viewing

      _fire(
        service: service,
        userRepo: userRepo,
        currentUid: currentUid,
        chat: chat,
        last: last,
      );
    }

    // Cap the dedupe set; the default Set is insertion-ordered, so drop oldest.
    while (seen.length > 300) {
      seen.remove(seen.first);
    }
  }, fireImmediately: true);
});

Future<void> _fire({
  required NotificationService service,
  required UserRepository userRepo,
  required String currentUid,
  required Chat chat,
  required Message last,
}) async {
  final title = await _title(userRepo, currentUid, chat, last.senderId);
  final text = last.type == MessageType.text ? last.text : last.preview;
  final body = text.isEmpty
      ? 'new message'
      : (text.length > 80 ? '${text.substring(0, 80)}…' : text);
  await service.showMessage(chatId: chat.id, title: title, body: body);
}

Future<String> _title(
  UserRepository userRepo,
  String currentUid,
  Chat chat,
  String senderId,
) async {
  if (!chat.isGroup) {
    final sender = await userRepo.getUser(senderId);
    return sender?.displayName ?? 'new message';
  }
  if (chat.title.isNotEmpty) return chat.title;

  // No group name → comma-join other members, truncated to 2 + "and N others".
  final others = chat.memberIds.where((m) => m != currentUid).toList();
  final names = <String>[];
  for (final id in others.take(2)) {
    final u = await userRepo.getUser(id);
    if (u != null) names.add(u.displayName);
  }
  if (others.length <= 2) {
    return names.isEmpty ? 'group chat' : names.join(', ');
  }
  final rest = others.length - 2;
  return '${names.join(', ')} and $rest other${rest == 1 ? '' : 's'}';
}
