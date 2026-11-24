import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/shayeb_theme.dart';
import 'game_animation_coordinator.dart';
import 'player_reaction_animation.dart';

/// Cinematic Match Victory Sequence (Section 13):
/// Displays gold light rays, confetti particles, enlarged winning avatar,
/// and the Egyptian Arabic celebration: "مبروك يا أسطورة! 👑"
class CinematicVictoryBanner extends StatefulWidget {
  const CinematicVictoryBanner({
    super.key,
    required this.winnerNickname,
    required this.winnerAvatarId,
    required this.totalPoints,
    this.quality = GameEffectsQuality.full,
  });

  final String winnerNickname;
  final String winnerAvatarId;
  final int totalPoints;
  final GameEffectsQuality quality;

  @override
  State<CinematicVictoryBanner> createState() => _CinematicVictoryBannerState();
}

class _CinematicVictoryBannerState extends State<CinematicVictoryBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final ms = (1800 * widget.quality.durationMultiplier).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
      value: widget.quality.isMinimal ? 1.0 : 0.0,
    );
    if (!widget.quality.isMinimal) {
      _controller.forward();
    }
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
          final t = _controller.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3E2B12),
                  Color(0xFF1F493A),
                  Color(0xFF2E2010),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ShayebColors.softGold, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: ShayebColors.softGold.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!widget.quality.skipHeavyParticles)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GoldConfettiPainter(progress: t),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedEgyptianCharacterAvatar(
                      avatarId: widget.winnerAvatarId,
                      state: AvatarMotionState.victory,
                      size: 62,
                      quality: widget.quality,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'مبروك يا أسطورة! 👑',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: ShayebColors.softGold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.winnerNickname} كسب الماتش بـ ${widget.totalPoints} نقطة!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ShayebColors.cardWhite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GoldConfettiPainter extends CustomPainter {
  const _GoldConfettiPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const colors = [
      ShayebColors.softGold,
      ShayebColors.goldenAccent,
      ShayebColors.successGreen,
      ShayebColors.cream,
    ];
    for (var i = 0; i < 18; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.75);
      final x = ((i * 59.3) % size.width);
      final y = ((i * 29.7 + progress * size.height * 0.8) % size.height);
      final r = 2.5 + (i % 3) * 1.4;
      canvas.drawCircle(
        Offset(x + math.sin(progress * math.pi * 2 + i) * 6, y),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoldConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
