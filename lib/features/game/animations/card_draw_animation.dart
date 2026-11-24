import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../cards/domain/playing_card.dart';
import '../../cards/presentation/playing_card_widget.dart';
import 'game_animation_coordinator.dart';

/// Curved quadratic Bezier card-drawing flight animation (Section 6).
/// - Moves along a smooth curve from `startAlignment` (opponent seat) to `endAlignment` (active player hand).
/// - Reveals the card face ONLY when `revealedForAuthorizedOwner` is non-null (local player's own draw);
///   opponents always see a face-down card transfer.
class CardDrawAnimation extends StatefulWidget {
  const CardDrawAnimation({
    super.key,
    this.startAlignment = const Alignment(0, -0.35),
    this.endAlignment = const Alignment(0, 0.85),
    this.revealedForAuthorizedOwner,
    this.quality = GameEffectsQuality.full,
    this.onCompleted,
  });

  final Alignment startAlignment;
  final Alignment endAlignment;
  final PlayingCardModel? revealedForAuthorizedOwner;
  final GameEffectsQuality quality;
  final VoidCallback? onCompleted;

  @override
  State<CardDrawAnimation> createState() => _CardDrawAnimationState();
}

class _CardDrawAnimationState extends State<CardDrawAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final ms = (520 * widget.quality.durationMultiplier).round();
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

  /// Calculates a point on a quadratic Bezier curve B(t) = (1-t)^2 P0 + 2(1-t)t P1 + t^2 P2.
  static Offset evaluateQuadraticBezier(
    Offset p0,
    Offset p1,
    Offset p2,
    double t,
  ) {
    final u = 1.0 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 340.0;
              final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 240.0;
              final p0 = Offset(
                widget.startAlignment.x * (w * 0.38),
                widget.startAlignment.y * (h * 0.38),
              );
              final p2 = Offset(
                widget.endAlignment.x * (w * 0.38),
                widget.endAlignment.y * (h * 0.38),
              );
              // Control point arches gracefully toward the center-right of the table
              final p1 = Offset(
                (p0.dx + p2.dx) / 2 + 36,
                (p0.dy + p2.dy) / 2 - 28,
              );

              final pos = evaluateQuadraticBezier(p0, p1, p2, t);
              final showFace =
                  widget.revealedForAuthorizedOwner != null && t >= 0.62;
              final rotation = (1.0 - t) * 0.24 * math.sin(t * math.pi);
              final scale = 0.88 + 0.16 * math.sin(t * math.pi);

              return Center(
                child: Transform.translate(
                  offset: pos,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: PlayingCardWidget(
                        card: showFace ? widget.revealedForAuthorizedOwner : null,
                        faceDown: !showFace,
                        width: 68,
                        height: 100,
                        isSelected: showFace,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
