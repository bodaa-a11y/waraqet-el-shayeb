import 'package:flutter/material.dart';
import '../../../theme/shayeb_theme.dart';

/// Playful Defeat Banner (Section 13):
/// Displays "يا خسارة يا معلم! الشايب اختارك 😂" without humiliating the player.
class CinematicDefeatNotice extends StatelessWidget {
  const CinematicDefeatNotice({
    super.key,
    required this.loserNickname,
    required this.isLocalPlayerLoser,
  });

  final String loserNickname;
  final bool isLocalPlayerLoser;

  @override
  Widget build(BuildContext context) {
    final text = isLocalPlayerLoser
        ? 'يا خسارة يا معلم! الشايب اختارك 😂'
        : 'يا خسارة! الشايب اختار $loserNickname في الجولة دي 😂';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ShayebColors.richRed.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShayebColors.goldenAccent, width: 1.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👴😂 ', style: TextStyle(fontSize: 20)),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShayebColors.cream,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
