import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../theme/shayeb_theme.dart';

/// Painted, resolution-independent café tabletop. Decorative only: no gameplay
/// information is duplicated here, and no images need to be fetched remotely.
class CafeTableSurface extends StatelessWidget {
  const CafeTableSurface({
    super.key,
    required this.child,
    this.highlightTurn = false,
    this.reducedMotion = false,
  });

  final Widget child;
  final bool highlightTurn;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: ShayebColors.woodFrameGradient,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: highlightTurn
              ? ShayebColors.softGold
              : ShayebColors.goldenAccent,
          width: highlightTurn ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: highlightTurn
                ? ShayebColors.softGold.withValues(alpha: 0.17)
                : Colors.black54,
            blurRadius: highlightTurn ? 28 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: ShayebColors.feltTableGradient,
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CafeFeltPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 12,
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Low-cost vector art: thread texture, gold seal and a glass of mint tea.
class _CafeFeltPainter extends CustomPainter {
  const _CafeFeltPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = ShayebColors.goldenAccent.withValues(alpha: 0.32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
        const Radius.circular(23),
      ),
      border,
    );

    // A quiet, consistent weave; this never changes with hidden card state.
    final fibers = Paint()
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.035);
    for (var i = 0; i < 125; i++) {
      final x = (i * 73.7) % size.width;
      final y = (i * 47.3 + 19) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x + 5, y + 2), fibers);
    }

    final c = Offset(size.width / 2, size.height / 2);
    final seal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ShayebColors.goldenAccent.withValues(alpha: 0.13);
    final radius = math.min(size.width, size.height) * 0.29;
    canvas.drawCircle(c, radius, seal);
    canvas.drawCircle(c, radius * 0.83, seal);

    // Traditional eight-point ornament in the middle of the café table.
    final ornament = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8 - math.pi / 2;
      final r = i.isEven ? 19.0 : 8.8;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      if (i == 0) {
        ornament.moveTo(p.dx, p.dy);
      } else {
        ornament.lineTo(p.dx, p.dy);
      }
    }
    ornament.close();
    canvas.drawPath(ornament, seal);

    // Small tea-glass silhouette; intentionally faint so actions stay legible.
    final center = Offset(size.width - 39, size.height - 40);
    final tea = Paint()
      ..color = ShayebColors.softGold.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final glass = Path()
      ..moveTo(center.dx - 11, center.dy - 17)
      ..lineTo(center.dx - 7, center.dy + 11)
      ..quadraticBezierTo(center.dx, center.dy + 18, center.dx + 7, center.dy + 11)
      ..lineTo(center.dx + 11, center.dy - 17);
    canvas.drawPath(glass, tea);
    canvas.drawLine(
      Offset(center.dx - 12, center.dy - 17),
      Offset(center.dx + 12, center.dy - 17),
      tea,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 17), width: 28, height: 5),
      tea,
    );
  }

  @override
  bool shouldRepaint(covariant _CafeFeltPainter oldDelegate) => false;
}
