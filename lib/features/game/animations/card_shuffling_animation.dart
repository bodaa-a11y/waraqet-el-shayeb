import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/shayeb_theme.dart';
import '../../cards/presentation/playing_card_widget.dart';
import 'game_animation_coordinator.dart';

/// 7-stage cinematic riffle/interleave card shuffle animation (Section 4):
/// 1. Gather at center -> 2. Lift -> 3. Split into two stacks ->
/// 4. Interleave -> 5. Align into one deck -> 6. Subtle bounce -> 7. Complete.
/// Purely visual; never reveals hidden card faces or alters server deck order.
class CardShufflingAnimation extends StatefulWidget {
  const CardShufflingAnimation({
    super.key,
    this.quality = GameEffectsQuality.full,
    this.onCompleted,
  });

  final GameEffectsQuality quality;
  final VoidCallback? onCompleted;

  @override
  State<CardShufflingAnimation> createState() => _CardShufflingAnimationState();
}

class _CardShufflingAnimationState extends State<CardShufflingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final ms = (1750 * widget.quality.durationMultiplier).round();
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
    const visualStackCount = 10;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return SizedBox(
            width: 240,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < visualStackCount; i++)
                  _buildShufflePacket(i, visualStackCount, t),
                Positioned(
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ShayebColors.goldenAccent.withValues(alpha: 0.7),
                      ),
                    ),
                    child: const Text(
                      'تفنيط الكوتشينة (٤٩ ورقة)... 🃏',
                      style: TextStyle(
                        color: ShayebColors.softGold,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShufflePacket(int index, int total, double t) {
    final isLeftHalf = index.isEven;
    final sideSign = isLeftHalf ? -1.0 : 1.0;
    final layerOffset = (index - total / 2) * 1.2;

    double dx = 0;
    double dy = layerOffset;
    double angle = 0;
    double scale = 1.0;

    if (t < 0.20) {
      // Stage 1 & 2: Gather and lift slightly
      final p = Curves.easeOut.transform(t / 0.20);
      dy = layerOffset - 10 * p;
      scale = 1.0 + 0.05 * p;
    } else if (t < 0.48) {
      // Stage 3: Split into left & right stacks
      final p = Curves.easeInOutCubic.transform((t - 0.20) / 0.28);
      dx = sideSign * 54 * p;
      dy = layerOffset - 10 + 4 * p;
      angle = sideSign * 0.16 * p;
      scale = 1.05;
    } else if (t < 0.78) {
      // Stage 4: Interleave stacks one by one
      final rawP = ((t - 0.48) / 0.30) * 1.35 - (index / total) * 0.35;
      final p = Curves.easeInOutBack.transform(rawP.clamp(0.0, 1.0));
      dx = sideSign * 54 * (1.0 - p);
      dy = layerOffset - 12 * math.sin(p * math.pi);
      angle = sideSign * 0.16 * (1.0 - p);
      scale = 1.05 - 0.03 * p;
    } else {
      // Stage 5 & 6: Align into one deck with final subtle bounce
      final p = Curves.elasticOut.transform(((t - 0.78) / 0.22).clamp(0.0, 1.0));
      dx = 0;
      dy = (1.0 - p) * -8;
      scale = 1.0 + (1.0 - p) * 0.04;
    }

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: const PlayingCardWidget(
            faceDown: true,
            width: 62,
            height: 92,
          ),
        ),
      ),
    );
  }
}
