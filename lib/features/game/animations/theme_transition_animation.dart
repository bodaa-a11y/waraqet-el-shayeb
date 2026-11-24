import 'package:flutter/material.dart';
import '../domain/game_visual_theme.dart';
import 'game_animation_coordinator.dart';

/// Smooth Theme Crossfade Wrapper (Section 2 & 3):
/// Animates visual theme transitions (`قهوة البلد` <-> `ليالي النيل`) smoothly
/// without rebuilding or resetting the active multiplayer game session.
class ThemeTransitionAnimation extends StatelessWidget {
  const ThemeTransitionAnimation({
    super.key,
    required this.theme,
    required this.child,
    this.quality = GameEffectsQuality.full,
  });

  final GameVisualTheme theme;
  final Widget child;
  final GameEffectsQuality quality;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration:
          quality.isMinimal ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      color: theme.woodColor,
      child: child,
    );
  }
}
