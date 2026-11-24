import 'package:el_shayeb_online/features/cards/domain/playing_card.dart';
import 'package:el_shayeb_online/features/cards/presentation/playing_card_widget.dart';
import 'package:el_shayeb_online/features/game/presentation/widgets/animated_card_fan.dart';
import 'package:el_shayeb_online/features/game/presentation/widgets/cafe_table_surface.dart';
import 'package:el_shayeb_online/features/results/presentation/widgets/king_reveal_fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cards = [
    PlayingCardModel(id: '3:hearts', rank: '3', suit: CardSuit.hearts),
    PlayingCardModel(id: '8:spades', rank: '8', suit: CardSuit.spades),
  ];

  testWidgets('Local hand fans real card identities and accepts a tap', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 200,
          child: AnimatedCardFan(
            cards: cards,
            selectedIndex: null,
            reducedMotion: true,
            onCardSelected: (index) => tapped = index,
          ),
        ),
      ),
    ));
    expect(find.byType(PlayingCardWidget), findsNWidgets(2));
    await tester.tap(find.byType(PlayingCardWidget).last);
    expect(tapped, 1);
  });

  testWidgets('Target hand contains only face-down cards', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 160,
          child: AnimatedTargetFan(
            count: 4,
            pending: false,
            selectedIndex: null,
            reducedMotion: true,
            onPick: (_) {},
          ),
        ),
      ),
    ));
    final cards = tester.widgetList<PlayingCardWidget>(find.byType(PlayingCardWidget));
    expect(cards.length, 4);
    expect(cards.every((card) => card.faceDown && card.card == null), isTrue);
    expect(find.text('الشايب'), findsNothing);
  });

  testWidgets('Café surface paints its content without blocking taps', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 250,
          child: CafeTableSurface(
            highlightTurn: true,
            child: TextButton(onPressed: () => tapped = true, child: const Text('اسحب')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('اسحب'));
    expect(tapped, isTrue);
  });

  testWidgets('King reveal obeys reduced-motion preference', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: KingRevealCard(reducedMotion: true)),
    ));
    expect(find.byType(PlayingCardWidget), findsOneWidget);
    final revealed = tester.widget<PlayingCardWidget>(find.byType(PlayingCardWidget));
    expect(revealed.card?.isElShayeb, isTrue);
  });
}
