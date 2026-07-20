import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Wraps a message bubble in a horizontal drag that reveals a reply icon and,
/// once dragged past a small threshold, fires [onReply] with haptic feedback —
/// then always snaps back (it never dismisses). Incoming bubbles swipe right;
/// the user's own bubbles swipe left.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.isMe,
    required this.onReply,
  });

  final Widget child;
  final bool isMe;
  final VoidCallback onReply;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 52;
  static const double _maxDrag = 84;

  double _dx = 0;
  bool _triggered = false;

  late final AnimationController _return = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _return.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    var next = _dx + (d.primaryDelta ?? 0);
    // Only allow the reply direction; add mild resistance past the threshold.
    next = widget.isMe ? next.clamp(-_maxDrag, 0.0) : next.clamp(0.0, _maxDrag);
    setState(() => _dx = next);

    if (!_triggered && next.abs() >= _threshold) {
      _triggered = true;
      HapticFeedback.mediumImpact();
      widget.onReply();
    }
  }

  void _onEnd(DragEndDetails d) {
    _triggered = false;
    final anim = Tween<double>(begin: _dx, end: 0)
        .animate(CurvedAnimation(parent: _return, curve: Curves.easeOut));
    void tick() => setState(() => _dx = anim.value);
    anim.addListener(tick);
    _return
      ..reset()
      ..forward().whenComplete(() => anim.removeListener(tick));
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx.abs() / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        alignment:
            widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: Icon(Icons.reply_rounded,
                    color: AppColors.accent, size: 22),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
