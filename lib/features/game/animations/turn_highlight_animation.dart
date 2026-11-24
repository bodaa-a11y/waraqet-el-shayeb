import 'package:flutter/material.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';
import 'game_animation_coordinator.dart';

/// Cinematic Turn Indicator Banner (Section 10):
/// - Local player's turn: "دورك يا معلم!" with directional draw-target badge
/// - Other player's turn: "استنى دورك" with active drawer -> target indicator
class CinematicTurnIndicator extends StatelessWidget {
  const CinematicTurnIndicator({
    super.key,
    required this.isMyTurn,
    required this.activePlayerName,
    required this.targetPlayerName,
    this.remainingSeconds,
    this.quality = GameEffectsQuality.full,
  });

  final bool isMyTurn;
  final String activePlayerName;
  final String targetPlayerName;
  final int? remainingSeconds;
  final GameEffectsQuality quality;

  @override
  Widget build(BuildContext context) {
    final headline =
        isMyTurn ? '🔥 دورك يا معلم!' : '⏳ ${ArEgStrings.waitingTurn}';
    final subline = isMyTurn
        ? 'اسحب ورقة مقلوبة من $targetPlayerName'
        : '$activePlayerName بيسحب من $targetPlayerName';

    return AnimatedContainer(
      duration:
          quality.isMinimal ? Duration.zero : const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isMyTurn
            ? const LinearGradient(
                colors: [
                  Color(0xEE4A2D12),
                  Color(0xEE6B421B),
                  Color(0xEE4A2D12),
                ],
              )
            : const LinearGradient(
                colors: [
                  Color(0xCC1A130E),
                  Color(0xCC261D15),
                ],
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isMyTurn ? ShayebColors.softGold : Colors.white24,
          width: isMyTurn ? 2.0 : 1.1,
        ),
        boxShadow: isMyTurn
            ? [
                BoxShadow(
                  color: ShayebColors.softGold.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headline,
                style: TextStyle(
                  color: isMyTurn ? ShayebColors.softGold : Colors.white,
                  fontSize: isMyTurn ? 15.5 : 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (remainingSeconds != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: remainingSeconds! <= 10
                        ? ShayebColors.richRed
                        : Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⏱️ $remainingSecondsث',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 14,
                color: Color(0xFFFFEAC6),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  subline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFEAC6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
