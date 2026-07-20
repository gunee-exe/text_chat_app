import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../domain/message.dart';

/// Renders a single message: an optional quoted reply, the payload (text /
/// media / voice), a timestamp, and any emoji reactions. Long-press fires
/// [onLongPress] (react), tapping the quoted strip fires [onQuoteTap], and
/// [highlighted] pulses the bubble when it's the jump-to target of a reply.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUid,
    this.senderName,
    this.highlighted = false,
    this.onQuoteTap,
    this.onLongPress,
  });

  final Message message;
  final bool isMe;
  final String currentUid;
  final String? senderName;
  final bool highlighted;
  final VoidCallback? onQuoteTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isMe
        ? AppColors.accent
        : (isDark ? AppColors.darkBubbleIn : AppColors.lightBubbleIn);
    final fg = isMe
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final metaColor = isMe
        ? Colors.white.withValues(alpha: 0.8)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    final bubble = Container(
      padding: _isMedia
          ? const EdgeInsets.all(5)
          : const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.replyTo != null) _QuotedStrip(
            reply: message.replyTo!,
            isMe: isMe,
            onTap: onQuoteTap,
          ),
          if (senderName != null && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                senderName!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.avatarColorFor(senderName!).$1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          _content(context, fg, metaColor),
          Padding(
            padding: EdgeInsets.only(top: _isMedia ? 4 : 2, right: 2, left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(formatMessageTime(message.sentAt),
                    style: TextStyle(fontSize: 11, color: metaColor)),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.done_rounded, size: 15, color: metaColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onLongPress: onLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                padding: EdgeInsets.all(highlighted ? 3 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(21),
                  color: highlighted
                      ? AppColors.accent.withValues(alpha: 0.22)
                      : Colors.transparent,
                ),
                child: bubble,
              ),
            ),
            if (message.reactions.isNotEmpty)
              _ReactionsRow(
                reactions: message.reactions,
                currentUid: currentUid,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }

  bool get _isMedia =>
      message.type == MessageType.image || message.type == MessageType.video;

  Widget _content(BuildContext context, Color fg, Color metaColor) {
    switch (message.type) {
      case MessageType.text:
        return Text(message.text, style: TextStyle(color: fg, fontSize: 15.5));
      case MessageType.image:
      case MessageType.video:
        return _MediaContent(message: message);
      case MessageType.audio:
        return _VoiceNote(message: message, fg: fg, metaColor: metaColor);
    }
  }
}

class _QuotedStrip extends StatelessWidget {
  const _QuotedStrip({required this.reply, required this.isMe, this.onTap});

  final ReplyRef reply;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nameColor = isMe ? Colors.white : AppColors.accent;
    final snippetColor =
        isMe ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondaryLight;
    final stripBg = isMe
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.accent.withValues(alpha: 0.10);
    final barColor = isMe ? Colors.white : AppColors.accent;
    final snippet =
        reply.snippet.isEmpty ? 'Original message unavailable' : reply.snippet;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: stripBg,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 3, color: barColor),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(reply.senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: nameColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.5)),
                          Text(snippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: snippetColor, fontSize: 13)),
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
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.reactions,
    required this.currentUid,
    required this.isDark,
  });

  final Map<String, String> reactions;
  final String currentUid;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    reactions.forEach(
        (_, emoji) => counts.update(emoji, (v) => v + 1, ifAbsent: () => 1));
    final mine = reactions[currentUid];

    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 6, right: 6, bottom: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final e in counts.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: e.key == mine
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: e.key == mine
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                e.value > 1 ? '${e.key} ${e.value}' : e.key,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaContent extends StatelessWidget {
  const _MediaContent({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final path = message.mediaPath;
    final isVideo = message.type == MessageType.video;

    Widget media;
    if (path != null && !path.startsWith('http') && File(path).existsSync()) {
      media = isVideo
          ? _placeholder(isVideo: true)
          : Image.file(File(path), fit: BoxFit.cover);
    } else if (path != null && path.startsWith('http') && !isVideo) {
      media = Image.network(path, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(isVideo: false));
    } else {
      media = _placeholder(isVideo: isVideo);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            media,
            if (isVideo)
              const Center(
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({required bool isVideo}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          size: 46,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _VoiceNote extends StatelessWidget {
  const _VoiceNote({
    required this.message,
    required this.fg,
    required this.metaColor,
  });
  final Message message;
  final Color fg;
  final Color metaColor;

  @override
  Widget build(BuildContext context) {
    final duration = message.audioDuration ?? Duration.zero;
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          Icon(Icons.play_arrow_rounded, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 22,
              child: CustomPaint(
                painter: _WaveformPainter(color: fg.withValues(alpha: 0.7)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(formatDuration(duration),
              style: TextStyle(color: metaColor, fontSize: 12)),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.color});
  final Color color;

  static const _bars = <double>[
    0.3, 0.6, 0.9, 0.5, 0.8, 1.0, 0.4, 0.7, 0.5, 0.9, 0.6, 0.3, 0.7, 0.5, 0.8,
    0.4, 0.6, 0.9, 0.5, 0.3,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final gap = size.width / _bars.length;
    for (var i = 0; i < _bars.length; i++) {
      final x = gap * i + gap / 2;
      final h = size.height * _bars[i];
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.color != color;
}
