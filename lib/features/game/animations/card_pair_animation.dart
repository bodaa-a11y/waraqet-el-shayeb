import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/shayeb_theme.dart';
import '../../cards/presentation/playing_card_widget.dart';
import 'game_animation_coordinator.dart';

/// Automatic Pair Match Animation (Section 7):
/// Lifts two matching cards, converges them toward each other with a golden
/// sparkle burst, settles them onto the center discard area, and displays:
/// "عاش يا معلم! نزلت جوز!"
class CardPairAnimation extends StatefulWidget {
  const CardPairAnimation({
    super.key,
    this.pairsCount = 1,
    this.quality = GameEffectsQuality.full,
    this.onCompleted,
  });

  final int pairsCount;
  final GameEffectsQuality quality;
  final VoidCallback? onCompleted;

  @override
  State<CardPairAnimation> createState() => _CardPairAnimationState();
}

class _CardPairAnimationState extends State<CardPairAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final ms = (740 * widget.quality.durationMultiplier).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    if (widget.quality.isMinimal) {
      _controller.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCompleted?.call();
      });
    } else {
      _controller.forward().whenComplete(() {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.pairsCount > 1
        ? 'عاش يا معلم! نزلت جوزين! ✨'
        : 'عاش يا معلم! نزلت جوز! 🎯';

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final converge = Curves.easeOutBack.transform((t / 0.55).clamp(0.0, 1.0));
          final settle = t > 0.55
              ? Curves.easeInOut.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0))
              : 0.0;
          final spreadX = 48.0 * (1.0 - converge) + 12.0 * settle;
          final liftY = -22.0 * math.sin(t * math.pi);
          final opacity = t > 0.85 ? (1.0 - (t - 0.85) / 0.15) : 1.0;

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: SizedBox(
              width: 240,
              height: 145,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!widget.quality.skipHeavyParticles && t > 0.25 && t < 0.85)
                    CustomPaint(
                      size: const Size(180, 120),
                      painter: _GoldSparkleBurstPainter(
                        progress: ((t - 0.25) / 0.60).clamp(0.0, 1.0),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(-spreadX, liftY),
                    child: Transform.rotate(
                      angle: -0.16,
                      child: const PlayingCardWidget(
                        faceDown: true,
                        width: 54,
                        height: 80,
                        isSelected: true,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(spreadX, liftY),
                    child: Transform.rotate(
                      angle: 0.16,
                      child: const PlayingCardWidget(
                        faceDown: true,
                        width: 54,
                        height: 80,
                        isSelected: true,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE2B1B10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: ShayebColors.softGold,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: ShayebColors.softGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GoldSparkleBurstPainter extends CustomPainter {
  const _GoldSparkleBurstPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = ShayebColors.softGold.withValues(alpha: (1.0 - progress) * 0.85)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 12; i++) {
      final angle = (i * math.pi * 2) / 12;
      final dist = 16.0 + progress * 54.0;
      final pt = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      canvas.drawCircle(pt, (1.0 - progress) * 4.2 + 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GoldSparkleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
