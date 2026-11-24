import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../cards/domain/playing_card.dart';
import '../../../cards/presentation/playing_card_widget.dart';

/// Responsive, accessible fanned hand. The card IDs come ONLY from the
/// authenticated player's private hand; never pass an opponent's hidden hand.
class AnimatedCardFan extends StatelessWidget {
  const AnimatedCardFan({
    super.key,
    required this.cards,
    required this.selectedIndex,
    required this.onCardSelected,
    this.reducedMotion = false,
  });

  final List<PlayingCardModel> cards;
  final int? selectedIndex;
  final ValueChanged<int> onCardSelected;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const width = 72.0;
      const height = 108.0;
      final count = cards.length;
      final visible = constraints.maxWidth.isFinite ? constraints.maxWidth : 380.0;
      final step = count <= 1 ? 0.0 : math.min(49.0, math.max(23.0, (visible - width - 8) / (count - 1)));
      final naturalWidth = count == 0 ? 0.0 : width + (count - 1) * step;
      final surfaceWidth = math.max(visible, naturalWidth + 12);
      final leftInset = (surfaceWidth - naturalWidth) / 2;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: surfaceWidth,
          height: 132,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < cards.length; index++)
                AnimatedPositioned(
                  key: ValueKey('hand_pos_${cards[index].id}'),
                  duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: leftInset + index * step,
                  top: 11 + (count <= 1 ? 0 : math.pow((index - (count - 1) / 2) / (count / 2), 2).toDouble() * 9),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('hand_appear_${cards[index].id}'),
                    tween: Tween<double>(begin: reducedMotion ? 1.0 : 0.0, end: 1.0),
                    duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 360),
                    curve: Curves.easeOutBack,
                    builder: (context, progress, child) => Transform.translate(
                      offset: Offset(0, (1 - progress) * 25),
                      child: Opacity(opacity: progress.clamp(0.0, 1.0).toDouble(), child: child),
                    ),
                    child: Transform.rotate(
                      angle: count <= 1 ? 0 : ((index - (count - 1) / 2) / math.max(1, (count - 1) / 2)) * 0.09,
                      child: PlayingCardWidget(
                        card: cards[index],
                        width: width,
                        height: height,
                        isSelected: selectedIndex == index,
                        onTap: () => onCardSelected(index),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// All cards are deliberately face-down. Only the number of cards and
/// selection index are known to the client.
class AnimatedTargetFan extends StatelessWidget {
  const AnimatedTargetFan({
    super.key,
    required this.count,
    required this.pending,
    required this.selectedIndex,
    required this.onPick,
    this.reducedMotion = false,
  });

  final int count;
  final bool pending;
  final int? selectedIndex;
  final ValueChanged<int> onPick;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const width = 64.0;
      final visible = constraints.maxWidth.isFinite ? constraints.maxWidth : 350.0;
      final step = count <= 1 ? 0.0 : math.min(48.0, math.max(27.0, (visible - width - 8) / (count - 1)));
      final naturalWidth = count == 0 ? 0.0 : width + (count - 1) * step;
      final surfaceWidth = math.max(visible, naturalWidth + 12);
      final inset = (surfaceWidth - naturalWidth) / 2;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: surfaceWidth,
          height: 116,
          child: Stack(children: [
            for (var i = 0; i < count; i++)
              AnimatedPositioned(
                key: ValueKey('draw_${i}_of_$count'),
                duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 240),
                left: inset + step * i,
                top: i == selectedIndex ? 0 : 9,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: reducedMotion ? 1.0 : 0.75, end: 1.0),
                  duration: reducedMotion ? Duration.zero : Duration(milliseconds: 180 + i * 24),
                  builder: (context, progress, child) => Transform.scale(
                    scale: progress,
                    child: child,
                  ),
                  child: PlayingCardWidget(
                    faceDown: true,
                    width: width,
                    height: 94,
                    isInteractive: !pending,
                    isSelected: i == selectedIndex,
                    onTap: pending ? null : () => onPick(i),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}
