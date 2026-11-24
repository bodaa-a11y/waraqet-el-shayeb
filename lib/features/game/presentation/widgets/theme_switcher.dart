import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/game_visual_theme_provider.dart';
import '../../domain/game_visual_theme.dart';

/// Compact in-game switcher. Both themes share the same game controller.
class ThemeSwitcherWidget extends ConsumerWidget {
  const ThemeSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(gameVisualThemeProvider);
    final theme = GameVisualTheme.fromType(current);
    return PopupMenuButton<GameVisualThemeType>(
      key: const Key('visual_theme_switcher'),
      tooltip: 'غيّر شكل القعدة',
      initialValue: current,
      onSelected: (next) {
        ref.read(gameVisualThemeProvider.notifier).setTheme(next);
      },
      color: const Color(0xFF2B211B),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.goldColor.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(16),
      ),
      itemBuilder: (context) => [
        for (final type in GameVisualThemeType.values)
          PopupMenuItem<GameVisualThemeType>(
            value: type,
            child: Row(
              children: [
                Icon(
                  type == GameVisualThemeType.ahwaClassic
                      ? Icons.local_cafe_rounded
                      : Icons.nights_stay_rounded,
                  color: GameVisualTheme.fromType(type).goldColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(GameVisualTheme.fromType(type).title),
                ),
                if (current == type)
                  const Icon(Icons.check_rounded, color: Color(0xFFE7BE70)),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: 'غيّر المنظر، الشكل الحالي ${theme.title}',
        child: Container(
          key: const Key('theme_switcher_button'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xE8261A13),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.goldColor, width: 1.25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                current == GameVisualThemeType.ahwaClassic
                    ? Icons.local_cafe_rounded
                    : Icons.nights_stay_rounded,
                size: 16,
                color: theme.goldColor,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  theme.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.goldColor,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down, size: 15, color: theme.goldColor),
            ],
          ),
        ),
      ),
    );
  }
}
