import 'package:flutter/material.dart';

/// Local visual preference only. It never changes room state, card identities,
/// turns or other authoritative multiplayer rules.
enum GameVisualThemeType { ahwaClassic, nileRoyal }

@immutable
class GameVisualTheme {
  const GameVisualTheme({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.backgroundImage,
    required this.tableColor,
    required this.woodColor,
    required this.goldColor,
    required this.isFelt,
  });

  final GameVisualThemeType type;
  final String title;
  final String subtitle;
  final String backgroundImage;
  final Color tableColor;
  final Color woodColor;
  final Color goldColor;
  final bool isFelt;

  static const ahwaClassic = GameVisualTheme(
    type: GameVisualThemeType.ahwaClassic,
    title: 'قهوة البلد',
    subtitle: 'دفا الخشب ولمّة الصحاب',
    backgroundImage: 'assets/images/themes/ahwa_classic_bg.jpg',
    tableColor: Color(0xFF764220),
    woodColor: Color(0xFF573018),
    goldColor: Color(0xFFD7AD61),
    isFelt: false,
  );

  static const nileRoyal = GameVisualTheme(
    type: GameVisualThemeType.nileRoyal,
    title: 'ليالي النيل',
    subtitle: 'غروب القاهرة والقعدة الملكي',
    backgroundImage: 'assets/images/themes/nile_royal_bg.jpg',
    tableColor: Color(0xFF0B4637),
    woodColor: Color(0xFF512D1B),
    goldColor: Color(0xFFE7BE70),
    isFelt: true,
  );

  static GameVisualTheme fromType(GameVisualThemeType type) {
    switch (type) {
      case GameVisualThemeType.ahwaClassic:
        return ahwaClassic;
      case GameVisualThemeType.nileRoyal:
        return nileRoyal;
    }
  }
}
