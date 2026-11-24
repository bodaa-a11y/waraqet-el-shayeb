import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';
import 'game_animation_coordinator.dart';

/// Expressive Egyptian Café Character Portrait with 8 motion states (Section 9):
/// - Idle: subtle breathing scale & gentle sway
/// - YourTurn: illuminated gold ring & slight forward lean
/// - Drawing: lean toward table center
/// - PairMatched: cheerful celebratory bounce & gold badge
/// - Suspense: curious head tilt
/// - Victory: enlarged portrait & gold crown glow
/// - Defeat: comedic headshake & playful badge
/// - Disconnected: dimmed brightness & connection-lost icon without continuous motion
class AnimatedEgyptianCharacterAvatar extends StatefulWidget {
  const AnimatedEgyptianCharacterAvatar({
    super.key,
    required this.avatarId,
    required this.state,
    this.size = 44,
    this.goldColor = ShayebColors.goldenAccent,
    this.quality = GameEffectsQuality.full,
    this.turnProgress,
  });

  final String avatarId;
  final AvatarMotionState state;
  final double size;
  final Color goldColor;
  final GameEffectsQuality quality;

  /// Optional 0.0..1.0 remaining turn timer progress for the active player.
  final double? turnProgress;

  @override
  State<AnimatedEgyptianCharacterAvatar> createState() =>
      _AnimatedEgyptianCharacterAvatarState();
}

class _AnimatedEgyptianCharacterAvatarState
    extends State<AnimatedEgyptianCharacterAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _syncAnimationLoop();
  }

  @override
  void didUpdateWidget(covariant AnimatedEgyptianCharacterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.quality != widget.quality) {
      _syncAnimationLoop();
    }
  }

  void _syncAnimationLoop() {
    if (widget.quality.isMinimal ||
        widget.state == AvatarMotionState.disconnected) {
      _controller.stop();
      _controller.value = 0.0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = int.tryParse(widget.avatarId.replaceAll('avatar_', ''));
    final hasImageAsset = index != null && index >= 1 && index <= 6;
    final isDisconnected = widget.state == AvatarMotionState.disconnected;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value;
          double scale = 1.0;
          double rotation = 0.0;
          Offset offset = Offset.zero;
          Color ringColor = widget.goldColor;

          switch (widget.state) {
            case AvatarMotionState.idle:
              scale = 1.0 + 0.025 * math.sin(phase * math.pi);
              break;
            case AvatarMotionState.yourTurn:
              scale = 1.05 + 0.04 * math.sin(phase * math.pi);
              offset = Offset(0, 2.0 * math.sin(phase * math.pi));
              ringColor = ShayebColors.softGold;
              break;
            case AvatarMotionState.drawing:
              scale = 1.06;
              offset = const Offset(0, 3.5);
              break;
            case AvatarMotionState.pairMatched:
              scale = 1.08;
              offset = Offset(0, -4.0 * math.sin(phase * math.pi));
              ringColor = ShayebColors.successGreen;
              break;
            case AvatarMotionState.suspense:
              rotation = 0.07 * math.sin(phase * math.pi * 2);
              break;
            case AvatarMotionState.victory:
              scale = 1.10 + 0.04 * math.sin(phase * math.pi);
              ringColor = ShayebColors.softGold;
              break;
            case AvatarMotionState.defeat:
              rotation = 0.11 * math.sin(phase * math.pi * 4);
              ringColor = ShayebColors.richRed;
              break;
            case AvatarMotionState.disconnected:
              scale = 0.96;
              ringColor = Colors.white38;
              break;
          }

          return Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: widget.size + 8,
                  height: widget.size + 8,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.turnProgress != null &&
                          widget.state == AvatarMotionState.yourTurn)
                        CustomPaint(
                          size: Size(widget.size + 6, widget.size + 6),
                          painter: _AvatarCountdownRingPainter(
                            progress: widget.turnProgress!.clamp(0.0, 1.0),
                            color: widget.turnProgress! < 0.25
                                ? ShayebColors.richRed
                                : ShayebColors.softGold,
                          ),
                        ),
                      Container(
                        width: widget.size,
                        height: widget.size,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ringColor,
                            width: widget.state == AvatarMotionState.yourTurn ||
                                    widget.state == AvatarMotionState.victory
                                ? 2.4
                                : 1.6,
                          ),
                          boxShadow: widget.state == AvatarMotionState.yourTurn ||
                                  widget.state == AvatarMotionState.victory
                              ? [
                                  BoxShadow(
                                    color: ringColor.withValues(alpha: 0.55),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                          color: const Color(0xFF1B352D),
                        ),
                        child: Opacity(
                          opacity: isDisconnected ? 0.45 : 1.0,
                          child: ClipOval(
                            child: hasImageAsset
                                ? Image.asset(
                                    'assets/images/avatars/avatar_$index.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _emojiFallback(),
                                  )
                                : _emojiFallback(),
                          ),
                        ),
                      ),
                      if (isDisconnected)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              size: 12,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emojiFallback() {
    return Center(
      child: Text(
        ArEgStrings.avatars[widget.avatarId]?['emoji'] ?? '🧔🏻‍♂️',
        style: TextStyle(fontSize: widget.size * 0.52),
      ),
    );
  }
}

class _AvatarCountdownRingPainter extends CustomPainter {
  const _AvatarCountdownRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarCountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
