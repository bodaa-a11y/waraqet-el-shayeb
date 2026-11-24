import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_shayeb_online/features/game/application/game_visual_theme_provider.dart';
import 'package:el_shayeb_online/features/game/domain/game_visual_theme.dart';
import 'package:el_shayeb_online/features/game/presentation/widgets/cinematic_table_surface.dart';
import 'package:el_shayeb_online/features/game/presentation/widgets/player_seat_layout.dart';
import 'package:el_shayeb_online/features/game/presentation/widgets/theme_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('All opponent seat layouts support rooms of 2-6 players', () {
    for (var players = 2; players <= 6; players++) {
      final positions = PlayerSeatLayout.positions(players - 1);
      expect(positions, hasLength(players - 1));
      expect(positions.toSet().length, positions.length);
      for (final alignment in positions) {
        expect(alignment.x, inInclusiveRange(-1, 1));
        expect(alignment.y, inInclusiveRange(-1, 1));
      }
    }
  });

  test('Official themes have unique IDs and bundled scene paths', () {
    expect(GameVisualTheme.ahwaClassic.title, 'قهوة البلد');
    expect(GameVisualTheme.nileRoyal.title, 'ليالي النيل');
    expect(GameVisualTheme.ahwaClassic.backgroundImage,
        isNot(GameVisualTheme.nileRoyal.backgroundImage));
    expect(GameVisualTheme.fromType(GameVisualThemeType.nileRoyal).isFelt, true);
  });

  testWidgets('Player can switch styles without changing game state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Center(child: ThemeSwitcherWidget())),
      ),
    ));
    expect(find.text('قهوة البلد'), findsOneWidget);
    await tester.tap(find.byKey(const Key('theme_switcher_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ليالي النيل'));
    await tester.pumpAndSettle();
    expect(container.read(gameVisualThemeProvider), GameVisualThemeType.nileRoyal);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('shayeb_visual_theme_v1'), 'nileRoyal');
  });

  testWidgets('The two tabletop renderers can be built', (tester) async {
    for (final theme in [GameVisualTheme.ahwaClassic, GameVisualTheme.nileRoyal]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              height: 230,
              child: CinematicTableSurface(theme: theme, child: const Text('الجولة الأولى')),
            ),
          ),
        ),
      ));
      expect(find.byKey(const Key('cinematic_table')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
