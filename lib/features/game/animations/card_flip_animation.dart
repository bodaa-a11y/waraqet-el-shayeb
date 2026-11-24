import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_animation_coordinator.dart';

/// Reusable 3D Y-axis perspective flip widget for playing cards and challenge cards.
class CardFlipAnimation extends StatefulWidget {
  const CardFlipAnimation({
    super.key,
    required this.frontBuilder,
    required this.backBuilder,
    this.isFaceUp = true,
    this.duration = const Duration(milliseconds: 620),
    this.quality = GameEffectsQuality.full,
    this.onFlipCompleted,
  });

  final WidgetBuilder frontBuilder;
  final WidgetBuilder backBuilder;
  final bool isFaceUp;
  final Duration duration;
  final GameEffectsQuality quality;
  final VoidCallback? onFlipCompleted;

  @override
  State<CardFlipAnimation> createState() => _CardFlipAnimationState();
}

class _CardFlipAnimationState extends State<CardFlipAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final ms =
        (widget.duration.inMilliseconds * widget.quality.durationMultiplier).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
      value: widget.quality.isMinimal ? (widget.isFaceUp ? 1.0 : 0.0) : 0.0,
    );
    if (!widget.quality.isMinimal && widget.isFaceUp) {
      _controller.forward().whenComplete(() {
        if (mounted) widget.onFlipCompleted?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CardFlipAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFaceUp != oldWidget.isFaceUp) {
      if (widget.quality.isMinimal) {
        _controller.value = widget.isFaceUp ? 1.0 : 0.0;
        widget.onFlipCompleted?.call();
      } else if (widget.isFaceUp) {
        _controller.forward().whenComplete(() {
          if (mounted) widget.onFlipCompleted?.call();
        });
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final showBack = t < 0.5;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0017)
          ..rotateY(math.pi * t);

        return Transform(
          alignment: Alignment.center,
          transform: matrix,
          child: showBack
              ? widget.backBuilder(context)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: widget.frontBuilder(context),
                ),
        );
      },
    );
  }
}
