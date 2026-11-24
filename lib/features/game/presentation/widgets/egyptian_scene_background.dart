import 'package:flutter/material.dart';
import '../../domain/game_visual_theme.dart';

/// The two user-approved concept images are *ambience art*, not gameplay
/// hitboxes. Real cards, player names and controls are Flutter widgets layered
/// above the image; an opaque foreground tabletop covers the mock cards.
class EgyptianSceneBackground extends StatelessWidget {
  const EgyptianSceneBackground({super.key, required this.theme});
  final GameVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: Image.asset(
                theme.backgroundImage,
                key: ValueKey(theme.backgroundImage),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => ColoredBox(color: theme.woodColor),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x37000000),
                    Color(0x68000000),
                    Color(0xB9110B09),
                  ],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
