import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_format.dart';
import '../../domain/message.dart';

/// Bottom composer for a conversation.
///
/// Text always works. Photo/video/voice are only available when the parent
/// supplies [onSendMedia] and [onSendAudio] — until the Firebase Storage phase
/// those are omitted, so the media controls are honestly disabled (they explain
/// themselves on tap) rather than being fake buttons that fail.
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.onSendText,
    this.onSendMedia,
    this.onSendAudio,
  });

  final ValueChanged<String> onSendText;
  final void Function(MessageType type, String path)? onSendMedia;
  final ValueChanged<Duration>? onSendAudio;

  bool get mediaEnabled => onSendMedia != null && onSendAudio != null;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  bool _hasText = false;

  bool _recording = false;
  DateTime? _recordStart;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
  }

  void _mediaComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('photos & voice notes arrive with the next update'),
      ),
    );
  }

  Future<void> _pickMedia(MessageType type) async {
    try {
      final XFile? file = type == MessageType.video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) widget.onSendMedia?.call(type, file.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('could not open the picker')),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.camera);
      if (file != null) widget.onSendMedia?.call(MessageType.image, file.path);
    } catch (_) {/* camera unavailable */}
  }

  void _openAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            _AttachTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFFA855F7),
              label: 'photo',
              onTap: () {
                Navigator.pop(context);
                _pickMedia(MessageType.image);
              },
            ),
            _AttachTile(
              icon: Icons.videocam_rounded,
              color: const Color(0xFFEC4899),
              label: 'video',
              onTap: () {
                Navigator.pop(context);
                _pickMedia(MessageType.video);
              },
            ),
            _AttachTile(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF14B8A6),
              label: 'camera',
              onTap: () {
                Navigator.pop(context);
                _capturePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
    });
  }

  void _stopRecording({required bool send}) {
    final start = _recordStart;
    setState(() {
      _recording = false;
      _recordStart = null;
    });
    if (send && start != null) {
      final duration = DateTime.now().difference(start);
      if (duration.inMilliseconds > 500) widget.onSendAudio?.call(duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassFill = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.55);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.7);
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final media = widget.mediaEnabled;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: _recording
            ? _RecordingBar(
                start: _recordStart!,
                onCancel: () => _stopRecording(send: false),
                onSend: () => _stopRecording(send: true),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: glassFill,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: glassBorder, width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                icon:
                                    Icon(Icons.add_rounded, color: secondary),
                                onPressed: media
                                    ? _openAttachSheet
                                    : _mediaComingSoon,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 5,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onSubmitted: (_) => _sendText(),
                                  decoration: const InputDecoration(
                                    hintText: 'message',
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              if (media && !_hasText)
                                IconButton(
                                  icon: Icon(Icons.photo_camera_rounded,
                                      color: secondary),
                                  onPressed: _capturePhoto,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TrailingButton(
                    // Show mic only when media is on and there's no text.
                    showSend: _hasText || !media,
                    onSend: _sendText,
                    onMicStart: _startRecording,
                    onMicStop: () => _stopRecording(send: true),
                    onMicCancel: () => _stopRecording(send: false),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TrailingButton extends StatelessWidget {
  const _TrailingButton({
    required this.showSend,
    required this.onSend,
    required this.onMicStart,
    required this.onMicStop,
    required this.onMicCancel,
  });

  final bool showSend;
  final VoidCallback onSend;
  final VoidCallback onMicStart;
  final VoidCallback onMicStop;
  final VoidCallback onMicCancel;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 48,
      width: 48,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        showSend ? Icons.send_rounded : Icons.mic_rounded,
        color: Colors.white,
      ),
    );

    if (showSend) {
      return GestureDetector(onTap: onSend, child: child);
    }
    return GestureDetector(
      onLongPressStart: (_) => onMicStart(),
      onLongPressEnd: (_) => onMicStop(),
      onLongPressCancel: onMicCancel,
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('hold to record a voice message')),
      ),
      child: child,
    );
  }
}

class _RecordingBar extends StatefulWidget {
  const _RecordingBar({
    required this.start,
    required this.onCancel,
    required this.onSend,
  });
  final DateTime start;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.start);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const _PulsingDot(),
          const SizedBox(width: 10),
          Text('recording  ${formatDuration(elapsed)}',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          TextButton(onPressed: widget.onCancel, child: const Text('cancel')),
          IconButton(
            onPressed: widget.onSend,
            icon: const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        height: 12,
        width: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}
