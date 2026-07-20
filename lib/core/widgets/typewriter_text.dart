import 'package:flutter/material.dart';

/// Types [text] out character-by-character once, then leaves it in place. A
/// caret blinks while typing and disappears when finished. Reserves the full
/// width up front so nothing reflows as the text grows (stays centered).
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.perCharacter = const Duration(milliseconds: 300),
    this.startDelay = const Duration(milliseconds: 400),
  });

  final String text;
  final TextStyle? style;
  final Duration perCharacter;
  final Duration startDelay;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with TickerProviderStateMixin {
  late final AnimationController _type = AnimationController(
    vsync: this,
    duration: widget.perCharacter * widget.text.length,
  );
  late final AnimationController _caret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    // Run the typewriter exactly once on first build.
    Future.delayed(widget.startDelay, () {
      if (mounted) _type.forward();
    });
  }

  @override
  void dispose() {
    _type.dispose();
    _caret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_type, _caret]),
      builder: (context, _) {
        final total = widget.text.length;
        final count = (_type.value * total).ceil().clamp(0, total);
        final typed = widget.text.substring(0, count);
        final done = _type.isCompleted;
        final showCaret = !done && _caret.value > 0.5;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Invisible full text reserves the final size — no reflow.
            Opacity(
              opacity: 0,
              child: Text('${widget.text} ', style: widget.style, maxLines: 1),
            ),
            Text(
              showCaret ? '$typed|' : typed,
              style: widget.style,
              maxLines: 1,
            ),
          ],
        );
      },
    );
  }
}
