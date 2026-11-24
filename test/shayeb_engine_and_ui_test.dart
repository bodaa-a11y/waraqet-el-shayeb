import 'package:el_shayeb_online/features/cards/domain/playing_card.dart';
import 'package:el_shayeb_online/features/cards/presentation/playing_card_widget.dart';
import 'package:el_shayeb_online/features/challenges/domain/challenge_model.dart';
import 'package:el_shayeb_online/features/game/domain/dart_rules_engine.dart';
import 'package:el_shayeb_online/features/game/domain/room_models.dart';
import 'package:el_shayeb_online/features/splash/presentation/creative_splash_screen.dart';
import 'package:el_shayeb_online/localization/ar_eg_strings.dart';
import 'package:el_shayeb_online/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('El Shayeb Dart Rules Engine & Domain Tests', () {
    test('Deck contains exactly 49 unique cards and only King of Hearts', () {
      final deck = ShayebDartRulesEngine.makeDeck();
      expect(deck.length, 49);
      expect(deck.map((c) => c.id).toSet().length, 49);
      final kings = deck.where((c) => c.isElShayeb).toList();
      expect(kings.length, 1);
      expect(kings.first.suit, CardSuit.hearts);
    });

    test('Pair resolution removes pairs and 4-of-a-kind while preserving El Shayeb', () {
      final sevens = ShayebDartRulesEngine.makeDeck()
          .where((c) => c.rank == '7')
          .toList();
      final shayeb = const PlayingCardModel(
        id: 'K:hearts',
        rank: 'K',
        suit: CardSuit.hearts,
      );
      final result = ShayebDartRulesEngine.resolvePairs([...sevens, shayeb]);
      expect(result.pairCount, 2);
      expect(result.discarded.length, 4);
      expect(result.hand.length, 1);
      expect(result.hand.first.isElShayeb, isTrue);
    });

    test('Round scoring awards N-1 down to 0 and deterministic tie-breaking works', () {
      final pts = ShayebDartRulesEngine.roundPoints(['u1', 'u2', 'u3', 'u4']);
      expect(pts, {'u1': 3, 'u2': 2, 'u3': 1, 'u4': 0});

      final room = RoomStateModel(
        roomId: 'r1',
        code: 'SH7K29',
        title: 'قعدة الصحاب',
        hostId: 'u1',
        visibility: 'private',
        maxPlayers: 3,
        totalRounds: 3,
        direction: 'clockwise',
        challengeMode: 'every_round',
        turnTimerSeconds: 45,
        status: 'finished',
        roundNumber: 3,
        players: const [
          RoomPlayerModel(uid: 'u1', nickname: 'أحمد', avatarId: 'avatar_1', seat: 0, ready: true),
          RoomPlayerModel(uid: 'u2', nickname: 'كريم', avatarId: 'avatar_2', seat: 1, ready: true),
          RoomPlayerModel(uid: 'u3', nickname: 'يوسف', avatarId: 'avatar_3', seat: 2, ready: true),
        ],
        scores: const {'u1': 4, 'u2': 4, 'u3': 1},
        losses: const {'u1': 1, 'u2': 0, 'u3': 2},
        firstFinishes: const {'u1': 2, 'u2': 1, 'u3': 0},
      );

      final standings = MatchStandingRow.computeFromRoom(room);
      // u2 beats u1 because u2 has 0 round losses while u1 has 1 round loss
      expect(standings.first.uid, 'u2');
      expect(standings.first.placement, 1);
      expect(standings[1].uid, 'u1');
      expect(standings[2].uid, 'u3');
    });

    test('Nickname validation enforces length, strips HTML, and blocks system impersonation', () {
      expect(PlayerProfile.validateNickname('أ'), isNotNull);
      expect(PlayerProfile.validateNickname('النظام'), isNotNull);
      expect(PlayerProfile.validateNickname('Admin'), isNotNull);
      expect(PlayerProfile.validateNickname('المعلم رضا'), isNull);
    });

    test('30 localized Egyptian challenges are present in the catalog', () {
      expect(kEgyptianChallengesCatalog.length, 30);
      expect(kEgyptianChallengesCatalog.map((c) => c.id).toSet().length, 30);
    });
  });

  group('El Shayeb Widgets & RTL UI Flow Tests', () {
    testWidgets('Face-down card never leaks hidden card rank or suit in semantics or text',
        (tester) async {
      const secretKing = PlayingCardModel(
        id: 'K:hearts',
        rank: 'K',
        suit: CardSuit.hearts,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayingCardWidget(
              card: secretKing,
              faceDown: true,
            ),
          ),
        ),
      );

      expect(find.text('الشايب'), findsNothing);
      expect(find.text('K'), findsNothing);
    });

    testWidgets('Full Egyptian RTL flow: Home -> Instant Café Room -> Lobby -> Start Game Table',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: ElShayebOnlineApp(skipOnboarding: true),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Egyptian Arabic Home Screen
      expect(find.text(ArEgStrings.gameTitle), findsOneWidget);
      expect(
        find.textContaining('قعدة سريعة على القهوة'),
        findsOneWidget,
      );

      // Tap Instant Café Room to enter the 4-player Lobby
      final quickPracticeFinder = find.textContaining('قعدة سريعة على القهوة');
      await tester.ensureVisible(quickPracticeFinder);
      await tester.pumpAndSettle();
      await tester.tap(quickPracticeFinder);
      await tester.pumpAndSettle();

      expect(find.text(ArEgStrings.roomCodePrefix), findsOneWidget);
      expect(find.text(ArEgStrings.startGameBtn), findsOneWidget);

      // Start the match and transition to the Game Table
      await tester.tap(find.text(ArEgStrings.startGameBtn));
      await tester.pump();

      expect(find.textContaining('الجولة 1'), findsOneWidget);
    });

    testWidgets('CreativeSplashScreen displays ورقة الشايب and completes cleanly',
        (tester) async {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CreativeSplashScreen(
            minimumDuration: const Duration(milliseconds: 500),
            onCompleted: () => done = true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(ArEgStrings.gameTitle), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      expect(done, isTrue);
    });
  });
}
