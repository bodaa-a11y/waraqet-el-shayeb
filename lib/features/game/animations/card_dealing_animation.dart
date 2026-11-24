import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../cards/presentation/playing_card_widget.dart';
import '../presentation/widgets/player_seat_layout.dart';
import 'game_animation_coordinator.dart';

/// Batched staggered card-dealing animation from center deck to 2–6 player seats (Section 5).
/// Renders lightweight visual card flights (never 49 heavy widgets simultaneously)
/// and never exposes opponents' card identities.
class CardDealingAnimation extends StatefulWidget {
  const CardDealingAnimation({
    super.key,
    required this.playerCount,
    this.quality = GameEffectsQuality.full,
    this.onCardPacketDealt,
    this.onCompleted,
  });

  final int playerCount;
  final GameEffectsQuality quality;
  final VoidCallback? onCardPacketDealt;
  final VoidCallback? onCompleted;

  @override
  State<CardDealingAnimation> createState() => _CardDealingAnimationState();
}

class _CardDealingAnimationState extends State<CardDealingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _lastTriggeredPacket = -1;

  @override
  void initState() {
    super.initState();
    final safePlayers = widget.playerCount.clamp(2, 6);
    final baseMs = 1350 + safePlayers * 140;
    final ms = (baseMs * widget.quality.durationMultiplier).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..addListener(_checkSoundCue);

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

  void _checkSoundCue() {
    final totalPackets = widget.playerCount.clamp(2, 6) * 2;
    final currentPacket = (_controller.value * totalPackets).floor();
    if (currentPacket > _lastTriggeredPacket && currentPacket < totalPackets) {
      _lastTriggeredPacket = currentPacket;
      widget.onCardPacketDealt?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkSoundCue);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePlayers = widget.playerCount.clamp(2, 6);
    final opponentAlignments = PlayerSeatLayout.positions(safePlayers - 1);
    final allSeatAlignments = <Alignment>[
      const Alignment(0, 0.92), // Local player at bottom
      ...opponentAlignments,
    ];
    final totalPackets = allSeatAlignments.length * 2;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return LayoutBuilder(
            builder: (context, constraints) {
              final halfW =
                  (constraints.maxWidth.isFinite ? constraints.maxWidth : 340) / 2;
              final halfH =
                  (constraints.maxHeight.isFinite ? constraints.maxHeight : 220) / 2;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Center dealer stack
                  if (t < 0.88)
                    const PlayingCardWidget(
                      faceDown: true,
                      width: 58,
                      height: 86,
                    ),
                  for (var i = 0; i < totalPackets; i++)
                    _buildFlyingCard(
                      index: i,
                      total: totalPackets,
                      targetAlignment:
                          allSeatAlignments[i % allSeatAlignments.length],
                      halfW: halfW * 0.72,
                      halfH: halfH * 0.72,
                      globalProgress: t,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFlyingCard({
    required int index,
    required int total,
    required Alignment targetAlignment,
    required double halfW,
    required double halfH,
    required double globalProgress,
  }) {
    final startT = (index / total) * 0.72;
    final endT = startT + 0.28;
    if (globalProgress < startT) return const SizedBox.shrink();

    final localT = ((globalProgress - startT) / (endT - startT)).clamp(0.0, 1.0);
    final curved = Curves.easeOutCubic.transform(localT);

    final dx = targetAlignment.x * halfW * curved;
    final dy = targetAlignment.y * halfH * curved -
        math.sin(curved * math.pi) * 18;
    final rotation = (index.isEven ? 1 : -1) * (1.0 - curved) * 0.45;
    final scale = 1.0 - 0.18 * curved;
    final opacity = localT > 0.85 ? (1.0 - (localT - 0.85) / 0.15) : 1.0;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: const PlayingCardWidget(
              faceDown: true,
              width: 54,
              height: 80,
            ),
          ),
        ),
      ),
    );
  }
}
