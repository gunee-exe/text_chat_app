import 'package:flutter/material.dart';

/// The Textify brand mark: a glossy blue speech bubble (with a tail) holding a
/// white "T". Drawn with [CustomPaint] so it stays crisp at any size, with the
/// letter composed on top for clean typography.
class TextifyLogo extends StatelessWidget {
  const TextifyLogo({super.key, this.size = 76, this.animate = false});

  final double size;

  /// Kept for call-site compatibility (e.g. the splash). The mark is static.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _BubblePainter())),
          // The letter sits in the body, above the tail.
          Align(
            alignment: const Alignment(0, -0.16),
            child: Text(
              'T',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.46,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    // Body and tail as separate paths, then a real boolean union so the tail
    // merges seamlessly into the body (winding-order differences would
    // otherwise punch a white hole where they overlap).
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s * 0.82),
        Radius.circular(s * 0.30),
      ));
    final tailPath = Path()
      ..moveTo(s * 0.22, s * 0.64)
      ..lineTo(s * 0.04, s * 0.99)
      ..lineTo(s * 0.48, s * 0.74)
      ..close();
    final bubble = Path.combine(PathOperation.union, bodyPath, tailPath);

    // Azure gradient fill.
    final fill = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF41B9F0), Color(0xFF1E8FD6)],
      ).createShader(Rect.fromLTWH(0, 0, s, s));
    canvas.drawPath(bubble, fill);

    // Glossy highlight over the top, clipped to the bubble.
    canvas.save();
    canvas.clipPath(bubble);
    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, s, s * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s * 0.5), gloss);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) => false;
}
