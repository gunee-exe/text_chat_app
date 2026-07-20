import 'package:intl/intl.dart';

/// Formats a timestamp the way a chat list does: "2m", "08:24", "yday",
/// or a date for anything older.
String formatChatTimestamp(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';

  final isSameDay = now.year == time.year &&
      now.month == time.month &&
      now.day == time.day;
  if (isSameDay) return DateFormat('HH:mm').format(time);

  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday = yesterday.year == time.year &&
      yesterday.month == time.month &&
      yesterday.day == time.day;
  if (isYesterday) return 'yday';

  if (diff.inDays < 7) return DateFormat('EEE').format(time); // Mon, Tue…
  return DateFormat('dd/MM/yy').format(time);
}

/// Clock time for a message bubble ("08:24").
String formatMessageTime(DateTime time) => DateFormat('HH:mm').format(time);

/// mm:ss for a voice note duration.
String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
