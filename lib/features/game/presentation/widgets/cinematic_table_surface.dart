import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/game_visual_theme.dart';

/// A fully opaque, illustrated playable surface. In particular it covers the
/// static example cards printed on the reference scene photographs.
class CinematicTableSurface extends StatelessWidget {
  const CinematicTableSurface({
    super.key,
    required this.theme,
    required this.child,
    this.highlightTurn = false,
    this.reducedMotion = false,
  });

  final GameVisualTheme theme;
  final Widget child;
  final bool highlightTurn;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const Key('cinematic_table'),
      duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.isFelt ? 110 : 24),
        boxShadow: [
          BoxShadow(
            blurRadius: highlightTurn ? 32 : 20,
            spreadRadius: highlightTurn ? 4 : 1,
            color: highlightTurn
                ? theme.goldColor.withValues(alpha: 0.35)
                : Colors.black87,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.isFelt ? 110 : 24),
        child: CustomPaint(
          painter: _TablePainting(theme: theme, highlightTurn: highlightTurn),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TablePainting extends CustomPainter {
  _TablePainting({required this.theme, required this.highlightTurn});
  final GameVisualTheme theme;
  final bool highlightTurn;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    // Thick warm wood base for both tables.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9E6838), Color(0xFF563019), Color(0xFF27170E)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    _drawWoodGrain(canvas, size);

    if (theme.isFelt) {
      final rim = Rect.fromLTWH(12, 11, size.width - 24, size.height - 22);
      canvas.drawOval(rim, Paint()..color = const Color(0xFF1B120E));
      final feltRect = rim.deflate(10);
      canvas.drawOval(
        feltRect,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF195B44), Color(0xFF0B3E31), Color(0xFF092A23)],
            stops: [0, 0.6, 1],
          ).createShader(feltRect),
      );
      canvas.drawOval(
        feltRect.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlightTurn ? 3.2 : 2.3
          ..color = theme.goldColor.withValues(alpha: highlightTurn ? 1 : 0.82),
      );
      canvas.drawOval(
        feltRect.deflate(7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = theme.goldColor.withValues(alpha: 0.35),
      );
      _drawSeal(canvas, size, 0.12);
    } else {
      final inner = RRect.fromRectAndRadius(rect.deflate(9), const Radius.circular(17));
      canvas.drawRRect(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlightTurn ? 3 : 1.75
          ..color = theme.goldColor.withValues(alpha: highlightTurn ? 1 : 0.63),
      );
      final inner2 = RRect.fromRectAndRadius(rect.deflate(16), const Radius.circular(12));
      canvas.drawRRect(
        inner2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.65
          ..color = theme.goldColor.withValues(alpha: 0.30),
      );
      _drawSeal(canvas, size, 0.09);
    }
    _drawTea(canvas, Offset(size.width * 0.12, size.height * 0.76),
        math.min(size.width, size.height) * 0.11);
  }

  void _drawWoodGrain(Canvas canvas, Size s) {
    // Reproducible thin wood grain strokes, no random rebuild shimmer.
    for (int i = 0; i < 65; i++) {
      final y = ((i * 37.3) % 100) / 100 * s.height;
      final amp = (i % 7 + 2) * 0.9;
      final path = Path()..moveTo(0, y);
      path.cubicTo(s.width * 0.27, y + amp, s.width * 0.7, y - amp,
          s.width, y + amp * 0.45);
      canvas.drawPath(
        path,
        Paint()
          ..color = (i.isEven ? Colors.black : const Color(0xFFFFCB7D))
              .withValues(alpha: i.isEven ? 0.10 : 0.042)
          ..strokeWidth = i % 4 == 0 ? 2 : 0.7
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawSeal(Canvas canvas, Size s, double opacity) {
    final center = Offset(s.width / 2, s.height / 2);
    final paint = Paint()
      ..color = theme.goldColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final size = math.min(s.width, s.height);
    canvas.drawCircle(center, size * 0.2, paint);
    canvas.drawCircle(center, size * 0.17, paint);
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8 - math.pi / 2;
      final radius = i.isEven ? size * 0.16 : size * 0.08;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) { path.moveTo(point.dx, point.dy); }
      else { path.lineTo(point.dx, point.dy); }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawTea(Canvas canvas, Offset center, double radius) {
    if (radius < 6) return;
    final saucer = Paint()..color = const Color(0xAAE4C088);
    canvas.drawOval(Rect.fromCenter(center: center + Offset(0, radius * 0.95),
      width: radius * 2.7, height: radius * 0.55), saucer);
    final glass = Path()
      ..moveTo(center.dx - radius * 0.75, center.dy - radius)
      ..lineTo(center.dx - radius * 0.5, center.dy + radius * 0.7)
      ..quadraticBezierTo(center.dx, center.dy + radius, center.dx + radius * 0.5, center.dy + radius * 0.7)
      ..lineTo(center.dx + radius * 0.75, center.dy - radius)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0xB16B2C0E));
    canvas.drawPath(glass, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..color = const Color(0xCFFFF0CC));
    canvas.drawOval(Rect.fromCenter(center: center + Offset(0, -radius),
      width: radius * 1.5, height: radius * 0.3),
      Paint()..color = const Color(0x99F0D09A));
  }

  @override
  bool shouldRepaint(covariant _TablePainting old) =>
      old.theme != theme || old.highlightTurn != highlightTurn;
}
