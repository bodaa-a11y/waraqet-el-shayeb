import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';
import '../../game/application/game_controller.dart';
import '../../game/domain/room_models.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({
    super.key,
    required this.onLeaveLobby,
    required this.onOpenChat,
  });

  final VoidCallback onLeaveLobby;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeGameSessionProvider);
    final profile = ref.watch(playerProfileProvider);
    final room = session.room;

    if (room == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isHost = room.hostId == profile.uid;
    final me = room.players.firstWhere(
      (p) => p.uid == profile.uid,
      orElse: () => room.players.first,
    );
    final allReady =
        room.players.length >= 2 && room.players.every((p) => p.ready || p.uid == room.hostId);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: ArEgStrings.leaveRoom,
            icon: const Icon(Icons.exit_to_app_rounded),
            onPressed: () async {
              await ref.read(activeGameSessionProvider.notifier).leaveCurrentRoom();
              onLeaveLobby();
            },
          ),
          title: Text(room.title),
          actions: [
            IconButton(
              tooltip: ArEgStrings.roomChatTitle,
              onPressed: onOpenChat,
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: ShayebColors.goldenAccent,
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: ShayebColors.feltTableGradient),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Room Code Banner with Copy & Native Share
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: ShayebColors.woodFrameGradient,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ShayebColors.goldenAccent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              ArEgStrings.roomCodePrefix,
                              style: TextStyle(
                                color: ShayebColors.cream,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              room.code,
                              style: const TextStyle(
                                fontSize: 32,
                                letterSpacing: 6,
                                fontWeight: FontWeight.w900,
                                color: ShayebColors.goldenAccent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: room.code));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(ArEgStrings.codeCopied),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  label: const Text(ArEgStrings.copyCode),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Share.share(
                                      'تعالى العب معايا ورقة الشايب! 👴🃏\nكود القعدة: ${room.code}',
                                    );
                                  },
                                  icon: const Icon(Icons.share_rounded, size: 18),
                                  label: const Text(ArEgStrings.shareRoom),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Settings Summary Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            _settingBadge(
                              Icons.people_alt_rounded,
                              '${room.players.length} / ${room.maxPlayers} لعيبة',
                            ),
                            _settingBadge(
                              Icons.repeat_rounded,
                              '${room.totalRounds} جولات',
                            ),
                            _settingBadge(
                              Icons.rotate_right_rounded,
                              room.direction == 'clockwise' ? 'سحب يمين' : 'سحب شمال',
                            ),
                            _settingBadge(
                              Icons.gavel_rounded,
                              room.challengeMode == 'every_round'
                                  ? 'حكم كل جولة'
                                  : (room.challengeMode == 'end_of_match'
                                      ? 'حكم آخر الماتش'
                                      : 'بدون أحكام'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Realtime Players List
                      Expanded(
                        child: ListView.separated(
                          itemCount: room.maxPlayers,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index < room.players.length) {
                              final p = room.players[index];
                              return _buildPlayerTile(
                                context,
                                ref,
                                room,
                                p,
                                isHostView: isHost,
                                isMe: p.uid == profile.uid,
                              );
                            }
                            return _buildEmptySeatTile(index + 1);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Ready & Host Start Controls
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ref
                                    .read(activeGameSessionProvider.notifier)
                                    .toggleReady();
                              },
                              icon: Icon(
                                me.ready
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                              ),
                              label: Text(
                                me.ready
                                    ? ArEgStrings.unreadyBtn
                                    : ArEgStrings.readyBtn,
                              ),
                            ),
                          ),
                          if (isHost) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: allReady && !session.isActionPending
                                    ? () {
                                        ref
                                            .read(activeGameSessionProvider.notifier)
                                            .startMatch();
                                      }
                                    : null,
                                icon: const Icon(Icons.style_rounded),
                                label: const Text(ArEgStrings.startGameBtn),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!allReady)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            ArEgStrings.waitingForPlayersReady,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: ShayebColors.softGold,
                            ),
                          ),
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

  Widget _settingBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: ShayebColors.goldenAccent),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: ShayebColors.cream,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerTile(
    BuildContext context,
    WidgetRef ref,
    RoomStateModel room,
    RoomPlayerModel player, {
    required bool isHostView,
    required bool isMe,
  }) {
    final emoji = ArEgStrings.avatars[player.avatarId]?['emoji'] ?? '🧔🏻‍♂️';
    final isRoomHost = player.uid == room.hostId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ShayebColors.primaryDarkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: player.ready ? ShayebColors.successGreen : ShayebColors.goldenAccent,
          width: isMe ? 2.2 : 1.2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: ShayebColors.warmWoodBrown,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${player.nickname}${isMe ? " (إنت)" : ""}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: ShayebColors.cream,
                        ),
                      ),
                    ),
                    if (isRoomHost) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ShayebColors.goldenAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          ArEgStrings.hostBadge,
                          style: TextStyle(
                            fontSize: 11,
                            color: ShayebColors.softGold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (player.temporaryTitle != null)
                  Text(
                    player.temporaryTitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ShayebColors.softGold,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: player.ready
                  ? ShayebColors.successGreen.withValues(alpha: 0.22)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              player.ready ? ArEgStrings.readyBadge : ArEgStrings.notReadyBadge,
              style: TextStyle(
                color: player.ready ? ShayebColors.successGreen : Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
          if (isHostView && !isMe && ref.read(activeGameSessionProvider).isOnlineFirebase)
            IconButton(
              tooltip: 'استبعاد من القعدة',
              onPressed: () {
                ref
                    .read(activeGameSessionProvider.notifier)
                    .bridge
                    .kickPlayer(roomId: room.roomId, targetUid: player.uid);
              },
              icon: const Icon(
                Icons.person_remove_rounded,
                color: ShayebColors.richRed,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySeatTile(int seatNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white12,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            child: Icon(Icons.chair_alt_rounded, color: Colors.white38),
          ),
          const SizedBox(width: 12),
          Text(
            'كرسي فاضي ($seatNumber) — مستنيين صاحبك يدخل...',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
