import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_shayeb_online/features/challenges/domain/challenge_model.dart';
import 'package:el_shayeb_online/features/game/animations/card_dealing_animation.dart';
import 'package:el_shayeb_online/features/game/animations/card_draw_animation.dart';
import 'package:el_shayeb_online/features/game/animations/card_pair_animation.dart';
import 'package:el_shayeb_online/features/game/animations/card_shuffling_animation.dart';
import 'package:el_shayeb_online/features/game/animations/challenge_reveal_animation.dart';
import 'package:el_shayeb_online/features/game/animations/defeat_animation.dart';
import 'package:el_shayeb_online/features/game/animations/game_animation_coordinator.dart';
import 'package:el_shayeb_online/features/game/animations/king_reveal_animation.dart';
import 'package:el_shayeb_online/features/game/animations/player_reaction_animation.dart';
import 'package:el_shayeb_online/features/game/animations/victory_animation.dart';
import 'package:el_shayeb_online/features/game/domain/game_visual_theme.dart';

void main() {
  testWidgets('CardShufflingAnimation and CardDealingAnimation render in RTL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Stack(
              children: [
                CardShufflingAnimation(
                  visualTheme: GameVisualTheme.ahwaClassic,
                  quality: GameEffectsQuality.full,
                ),
                CardDealingAnimation(
                  seatCount: 4,
                  visualTheme: GameVisualTheme.ahwaClassic,
                  quality: GameEffectsQuality.full,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('خلط الكوتشينة...'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('CardDrawAnimation and CardPairAnimation complete cleanly without exposing hidden card identity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Stack(
              children: [
                CardDrawAnimation(
                  eventId: 'draw_test_1',
                  fromAlignment: Alignment.topCenter,
                  toAlignment: Alignment.bottomCenter,
                  isLocalActor: false,
                  visualTheme: GameVisualTheme.nileRoyal,
                  quality: GameEffectsQuality.full,
                ),
                CardPairAnimation(
                  eventId: 'pair_test_1',
                  pairsCount: 1,
                  actorNickname: 'أحمد',
                  quality: GameEffectsQuality.full,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('نزلت جوز'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('CinematicKingRevealBanner renders 4-stage reveal and supports Skip button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CinematicKingRevealBanner(
              loserName: 'محمود',
              isCurrentUserLoser: true,
              quality: GameEffectsQuality.full,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تخطي'), findsOneWidget);
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.text('الشايب لبس فيك يا نجم! 👴'), findsOneWidget);
  });

  testWidgets('AnimatedEgyptianCharacterAvatar, Victory, Defeat, and ChallengeReveal render properly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const AnimatedEgyptianCharacterAvatar(
                    avatarId: 'avatar_1',
                    emoji: '☕',
                    motionState: AvatarMotionState.yourTurn,
                    visualTheme: GameVisualTheme.ahwaClassic,
                    turnProgress: 0.75,
                  ),
                  const CinematicVictoryBanner(
                    winnerName: 'أحمد',
                    isCurrentUserWinner: true,
                  ),
                  const CinematicDefeatNotice(
                    loserName: 'محمود',
                    isCurrentUserLoser: true,
                  ),
                  ChallengeRevealAnimation(
                    instanceId: 'ch_inst_1',
                    challenge: kEgyptianChallengesCatalog.first,
                    child: const Text('بطاقة الحكم'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مبروك يا أسطورة! 👑'), findsOneWidget);
    expect(find.text('بطاقة الحكم'), findsOneWidget);
  });
}
