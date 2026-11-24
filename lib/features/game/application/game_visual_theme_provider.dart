import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/game_visual_theme.dart';

const _prefKey = 'shayeb_visual_theme_v1';

class GameVisualThemeNotifier extends StateNotifier<GameVisualThemeType> {
  GameVisualThemeNotifier() : super(GameVisualThemeType.ahwaClassic);

  /// The app boots immediately with the default, then restores the saved
  /// preference without affecting the online session.
  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (!mounted) return;
      state = GameVisualThemeType.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => GameVisualThemeType.ahwaClassic,
      );
    } catch (_) {
      // In a widget test without platform channels the default is safe.
    }
  }

  Future<void> setTheme(GameVisualThemeType type) async {
    state = type;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, type.name);
    } catch (_) {
      // Keep the new local selection even if persistence is unavailable.
    }
  }

  Future<void> toggleTheme() => setTheme(
    state == GameVisualThemeType.ahwaClassic
        ? GameVisualThemeType.nileRoyal
        : GameVisualThemeType.ahwaClassic,
  );
}

final gameVisualThemeProvider =
    StateNotifierProvider<GameVisualThemeNotifier, GameVisualThemeType>(
  (ref) => GameVisualThemeNotifier(),
);

final currentGameVisualThemeProvider = Provider<GameVisualTheme>(
  (ref) => GameVisualTheme.fromType(ref.watch(gameVisualThemeProvider)),
);
