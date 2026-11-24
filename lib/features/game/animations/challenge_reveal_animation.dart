import 'package:flutter/material.dart';
import '../../../theme/shayeb_theme.dart';
import '../domain/room_models.dart';
import 'card_flip_animation.dart';
import 'game_animation_coordinator.dart';

/// Animated Challenge Reveal Card (Section 14):
/// 1. Appears sealed face-down -> 2. Flips open with 3D motion ->
/// 3. Reveals the server-assigned Egyptian Arabic challenge and action buttons.
class ChallengeRevealAnimation extends StatelessWidget {
  const ChallengeRevealAnimation({
    super.key,
    required this.challengeInstance,
    required this.revealedBody,
    this.quality = GameEffectsQuality.full,
  });

  final ActiveChallengeModel challengeInstance;
  final Widget revealedBody;
  final GameEffectsQuality quality;

  @override
  Widget build(BuildContext context) {
    return CardFlipAnimation(
      key: ValueKey(
        'challenge_flip_${challengeInstance.instanceId}_${challengeInstance.redrawCount}',
      ),
      quality: quality,
      duration: const Duration(milliseconds: 680),
      isFaceUp: true,
      backBuilder: (_) => Container(
        height: 190,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: ShayebColors.woodFrameGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ShayebColors.softGold, width: 2.2),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⚖️📜', style: TextStyle(fontSize: 38)),
              SizedBox(height: 8),
              Text(
                'بنفتح ظرف الحكم...',
                style: TextStyle(
                  color: ShayebColors.softGold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
      frontBuilder: (_) => revealedBody,
    );
  }
}
