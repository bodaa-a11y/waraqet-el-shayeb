import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../cards/domain/playing_card.dart';
import '../../../cards/presentation/playing_card_widget.dart';

/// One-time cinematic King flip for the publicly known round result.
/// This must never be mounted for an opponent's hidden card during gameplay.
class KingRevealCard extends StatefulWidget {
  const KingRevealCard({super.key, this.reducedMotion = false});

  final bool reducedMotion;

  @override
  State<KingRevealCard> createState() => _KingRevealCardState();
}

class _KingRevealCardState extends State<KingRevealCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reducedMotion) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant KingRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion && !oldWidget.reducedMotion) {
      _controller.value = 1;
    } else if (!widget.reducedMotion && oldWidget.reducedMotion) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const king = PlayingCardModel(
      id: 'K:hearts',
      rank: 'K',
      suit: CardSuit.hearts,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.reducedMotion
            ? 1.0
            : Curves.easeInOutCubic.transform(_controller.value);
        final back = t < 0.5;
        final rotation = Matrix4.identity()
          ..setEntry(3, 2, 0.0016)
          ..rotateY(math.pi * t);
        return Transform(
          alignment: Alignment.center,
          transform: rotation,
          child: back
              ? const PlayingCardWidget(
                  faceDown: true,
                  width: 72,
                  height: 106,
                )
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: const PlayingCardWidget(
                    card: king,
                    width: 72,
                    height: 106,
                    isSelected: true,
                  ),
                ),
        );
      },
    );
  }
}
