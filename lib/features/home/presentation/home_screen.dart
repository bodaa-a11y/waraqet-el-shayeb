import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';
import '../../cards/domain/playing_card.dart';
import '../../cards/presentation/playing_card_widget.dart';
import '../../game/application/game_controller.dart';
import '../../splash/presentation/creative_splash_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onCreateRoom,
    required this.onJoinByCode,
    required this.onBrowsePublicRooms,
    required this.onStartQuickPractice,
    required this.onOpenHowToPlay,
    required this.onOpenChallenges,
    required this.onOpenSettings,
    required this.onEditProfile,
  });

  final VoidCallback onCreateRoom;
  final VoidCallback onJoinByCode;
  final VoidCallback onBrowsePublicRooms;
  final VoidCallback onStartQuickPractice;
  final VoidCallback onOpenHowToPlay;
  final VoidCallback onOpenChallenges;
  final VoidCallback onOpenSettings;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final avatarEmoji =
        ArEgStrings.avatars[profile.avatarId]?['emoji'] ?? '🧔🏻‍♂️';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: ShayebColors.feltTableGradient,
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Player badge + Sound & Settings
                      Row(
                        children: [
                          InkWell(
                            onTap: onEditProfile,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: ShayebColors.warmWoodBrown,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: ShayebColors.goldenAccent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(avatarEmoji, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Text(
                                    profile.nickname,
                                    style: const TextStyle(
                                      color: ShayebColors.cream,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: ShayebColors.goldenAccent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'الصوت',
                            onPressed: () {
                              ref
                                  .read(playerProfileProvider.notifier)
                                  .updateProfile(soundEnabled: !profile.soundEnabled);
                            },
                            icon: Icon(
                              profile.soundEnabled
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              color: ShayebColors.goldenAccent,
                            ),
                          ),
                          IconButton(
                            tooltip: ArEgStrings.settings,
                            onPressed: onOpenSettings,
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: ShayebColors.goldenAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Brand Hero Card: Illustrated Egyptian Café Table
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: ShayebColors.woodFrameGradient,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: ShayebColors.goldenAccent, width: 2.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 22,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: ShayebColors.feltTableGradient,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ShayebColors.goldenAccent.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Column(
                            children: [
                              const BrandLogoBadge(size: 112),
                              const SizedBox(height: 10),
                              const Text(
                                ArEgStrings.gameTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: ShayebColors.goldenAccent,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                ArEgStrings.gameSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: ShayebColors.cream,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Illustrated fanned cards featuring the King of Hearts ("الشايب")
                              SizedBox(
                                height: 124,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(56, 8),
                                      child: Transform.rotate(
                                        angle: 0.22,
                                        child: const PlayingCardWidget(
                                          faceDown: true,
                                          width: 72,
                                          height: 106,
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(-56, 8),
                                      child: Transform.rotate(
                                        angle: -0.22,
                                        child: const PlayingCardWidget(
                                          card: PlayingCardModel(
                                            id: '7:spades',
                                            rank: '7',
                                            suit: CardSuit.spades,
                                          ),
                                          width: 72,
                                          height: 106,
                                        ),
                                      ),
                                    ),
                                    const PlayingCardWidget(
                                      card: PlayingCardModel(
                                        id: 'K:hearts',
                                        rank: 'K',
                                        suit: CardSuit.hearts,
                                      ),
                                      width: 80,
                                      height: 116,
                                      isSelected: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '٤٩ ورقة • ٢ لـ ٦ لعيبة • ٣٠ حكم مصري يموت من الضحك',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: ShayebColors.softGold,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Primary CTA: Create Room ("اعمل قعدة")
                      ElevatedButton.icon(
                        onPressed: onCreateRoom,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                        label: const Text(
                          '${ArEgStrings.createRoom} (أونلاين أو مع الشلة)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Row: Join by Code + Public Rooms
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onJoinByCode,
                              icon: const Icon(Icons.vpn_key_rounded),
                              label: const Text(ArEgStrings.joinRoomByCode),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onBrowsePublicRooms,
                              icon: const Icon(Icons.groups_rounded),
                              label: const Text(ArEgStrings.publicRooms),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Instant Practice / Local Demo Match button
                      FilledButton.tonalIcon(
                        onPressed: onStartQuickPractice,
                        style: FilledButton.styleFrom(
                          backgroundColor: ShayebColors.warmWoodBrown,
                          foregroundColor: ShayebColors.cream,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: ShayebColors.goldenAccent),
                          ),
                        ),
                        icon: const Icon(Icons.bolt_rounded, color: ShayebColors.softGold),
                        label: const Text(
                          'قعدة سريعة على القهوة (تجربة فورية ٤ لعيبة ☕)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Secondary Row: How to Play + 30 Challenges + Settings
                      Row(
                        children: [
                          Expanded(
                            child: _SecondaryActionTile(
                              icon: Icons.menu_book_rounded,
                              label: ArEgStrings.howToPlay,
                              onTap: onOpenHowToPlay,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SecondaryActionTile(
                              icon: Icons.gavel_rounded,
                              label: ArEgStrings.challengesLibrary,
                              onTap: onOpenChallenges,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionTile extends StatelessWidget {
  const _SecondaryActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: ShayebColors.primaryDarkGreen,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ShayebColors.goldenAccent.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ShayebColors.goldenAccent, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ShayebColors.cream,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
