import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/shayeb_theme.dart';
import '../../cards/domain/playing_card.dart';
import '../../cards/presentation/playing_card_widget.dart';
import 'game_animation_coordinator.dart';
import 'player_reaction_animation.dart';

/// 4-Stage Cinematic King of Hearts (K♥ — الشايب) Reveal Sequence (Section 8):
/// - Stage 1 (0.00–0.22): Suspense — background darkens, spotlight focuses on loser.
/// - Stage 2 (0.22–0.58): Reveal — remaining card lifts into center and rotates in 3D
///   to reveal the King of Hearts (K♥) with golden sparks.
/// - Stage 3 (0.58–0.80): Reaction — losing player's avatar shakes head in comedic defeat.
/// - Stage 4 (0.80–1.00): Announcement — "الشايب لبس فيك يا نجم! 👴" with loser's nickname.
/// Includes a skip button and never mounts before authoritative round completion.
class CinematicKingRevealBanner extends StatefulWidget {
  const CinematicKingRevealBanner({
    super.key,
    required this.loserUid,
    required this.loserNickname,
    required this.loserAvatarId,
    required this.isLocalPlayerLoser,
    this.firstFinisherNickname,
    this.quality = GameEffectsQuality.full,
    this.onSkipped,
  });

  final String loserUid;
  final String loserNickname;
  final String loserAvatarId;
  final bool isLocalPlayerLoser;
  final String? firstFinisherNickname;
  final GameEffectsQuality quality;
  final VoidCallback? onSkipped;

  @override
  State<CinematicKingRevealBanner> createState() =>
      _CinematicKingRevealBannerState();
}

class _CinematicKingRevealBannerState extends State<CinematicKingRevealBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const PlayingCardModel kOfficialKingOfHearts = PlayingCardModel(
    id: 'K:hearts',
    rank: 'K',
    suit: CardSuit.hearts,
  );

  @override
  void initState() {
    super.initState();
    final ms = (2600 * widget.quality.durationMultiplier).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
      value: widget.quality.isMinimal ? 1.0 : 0.0,
    );
    if (!widget.quality.isMinimal) {
      _controller.forward();
    }
  }

  void _skipCinematic() {
    _controller.value = 1.0;
    widget.onSkipped?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcement = widget.isLocalPlayerLoser
        ? 'الشايب لبس فيك يا نجم! 👴'
        : 'الشايب لبس في ${widget.loserNickname} يا نجم! 👴';

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final flipProgress =
              Curves.easeInOutCubic.transform(((t - 0.18) / 0.44).clamp(0.0, 1.0));
          final showFace = flipProgress >= 0.5;
          final flipMatrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0017)
            ..rotateY(math.pi * flipProgress);

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: ShayebColors.woodFrameGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: ShayebColors.goldenAccent,
                width: 2.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: ShayebColors.richRed.withValues(alpha: 0.35 * flipProgress),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // 3D Rotating King of Hearts (K♥) Card
                    Transform(
                      alignment: Alignment.center,
                      transform: flipMatrix,
                      child: showFace
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: const PlayingCardWidget(
                                card: kOfficialKingOfHearts,
                                width: 78,
                                height: 114,
                                isSelected: true,
                              ),
                            )
                          : const PlayingCardWidget(
                              faceDown: true,
                              width: 78,
                              height: 114,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AnimatedEgyptianCharacterAvatar(
                                avatarId: widget.loserAvatarId,
                                state: AvatarMotionState.defeat,
                                size: 42,
                                quality: widget.quality,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  announcement,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: ShayebColors.goldenAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isLocalPlayerLoser
                                ? 'يا خسارة يا معلم! الشايب اختارك 😂 (شايب القلوب K♥)'
                                : 'شايب القلوب (K♥) قفل الجولة على ${widget.loserNickname}!',
                            style: const TextStyle(
                              color: ShayebColors.cream,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.firstFinisherNickname != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'أول واحد فلت في الجولة دي: ${widget.firstFinisherNickname} ⚡',
                              style: const TextStyle(
                                color: ShayebColors.softGold,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (t < 0.98)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('skip_king_reveal_button'),
                      onPressed: _skipCinematic,
                      icon: const Icon(Icons.fast_forward_rounded, size: 16),
                      label: const Text(
                        'تخطي العرض',
                        style: TextStyle(fontSize: 12),
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
}
