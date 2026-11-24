import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/game_visual_theme.dart';
import 'game_animation_coordinator.dart';

/// Dynamic Table Atmosphere Layer (Section 11):
/// - Ahwa Classic (`قهوة البلد`): Warm lantern glow variation & rising mint-tea steam wisps.
/// - Nile Royal (`ليالي النيل`): Soft Nile water sunset reflections & golden shimmer motes.
/// Respects `GameEffectsQuality` and `reducedMotion`.
class TableAmbientAnimation extends StatefulWidget {
  const TableAmbientAnimation({
    super.key,
    required this.theme,
    this.quality = GameEffectsQuality.full,
  });

  final GameVisualTheme theme;
  final GameEffectsQuality quality;

  @override
  State<TableAmbientAnimation> createState() => _TableAmbientAnimationState();
}

class _TableAmbientAnimationState extends State<TableAmbientAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _syncLoop();
  }

  @override
  void didUpdateWidget(covariant TableAmbientAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quality != widget.quality) {
      _syncLoop();
    }
  }

  void _syncLoop() {
    if (widget.quality.skipHeavyParticles) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quality.skipHeavyParticles) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _AmbientAtmospherePainter(
                theme: widget.theme,
                phase: _controller.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmbientAtmospherePainter extends CustomPainter {
  const _AmbientAtmospherePainter({
    required this.theme,
    required this.phase,
  });

  final GameVisualTheme theme;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    if (theme.type == GameVisualThemeType.ahwaClassic) {
      // 1. Warm amber lantern flicker at top corners
      final flicker = 0.08 + 0.04 * math.sin(phase * math.pi * 4);
      final lanternPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB74D).withValues(alpha: flicker),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.85, size.height * 0.15),
            radius: size.width * 0.45,
          ),
        );
      canvas.drawRect(Offset.zero & size, lanternPaint);

      // 2. Subtle mint-tea steam wisps rising above the tea glass position
      final teaOrigin = Offset(size.width * 0.12, size.height * 0.72);
      final steamPaint = Paint()
        ..color = const Color(0xFFF9E7C2).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      for (var w = 0; w < 2; w++) {
        final localP = (phase + w * 0.5) % 1.0;
        final path = Path();
        final startY = teaOrigin.dy - localP * 26;
        path.moveTo(teaOrigin.dx + (w - 0.5) * 6, startY);
        path.quadraticBezierTo(
          teaOrigin.dx + math.sin(localP * math.pi * 2) * 8,
          startY - 12,
          teaOrigin.dx - math.sin(localP * math.pi * 2) * 5,
          startY - 24,
        );
        canvas.drawPath(path, steamPaint);
      }
    } else {
      // Nile Royal: Soft sunset water reflections & golden dust motes
      final shimmerPaint = Paint()
        ..color = const Color(0xFFE0B85A).withValues(alpha: 0.14)
        ..style = PaintingStyle.fill;

      for (var i = 0; i < 8; i++) {
        final p = (phase + i * 0.125) % 1.0;
        final x = size.width * (0.15 + 0.7 * ((i * 0.37) % 1.0)) +
            math.sin(p * math.pi * 2) * 10;
        final y = size.height * (0.85 - p * 0.7);
        final alpha = math.sin(p * math.pi) * 0.18;
        shimmerPaint.color = const Color(0xFFE0B85A).withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), 2.2 + (i % 2), shimmerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientAtmospherePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.theme != theme;
}
