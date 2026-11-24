// Preserved from el_shayeb_engine_parallel_module for backwards compatibility.
// The main production table screen is in lib/features/game/presentation/game_table_screen.dart.

import 'package:flutter/material.dart';
import 'shayeb_game_bridge.dart';

class ShayebTableScreen extends StatefulWidget {
  const ShayebTableScreen({super.key, required this.roomId});
  final String roomId;

  @override
  State<ShayebTableScreen> createState() => _ShayebTableScreenState();
}

class _ShayebTableScreenState extends State<ShayebTableScreen> {
  final ShayebGameBridge api = ShayebGameBridge();
  bool busy = false;

  Future<void> pickCard(int index, int version) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await api.drawCard(
        roomId: widget.roomId,
        cardIndex: index,
        expectedVersion: version,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ط§ظ„ط³ط­ط¨ط© ظ…ط§ ط¸ط¨ط·طھط´. ط¬ط±ظ‘ط¨ طھط§ظ†ظٹ.\n$error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF092B25),
        appBar: AppBar(
          title: const Text('ط§ظ„ط´ط§ظٹط¨ ط£ظˆظ†ظ„ط§ظٹظ†'),
          backgroundColor: const Color(0xFF123B32),
          foregroundColor: const Color(0xFFF5E9D1),
        ),
        body: StreamBuilder<ShayebDocSnapshot<Map<String, dynamic>>>(
          stream: api.watchRoom(widget.roomId),
          builder: (context, roomSnap) {
            if (roomSnap.hasError) return _notice('ظ…ط´ ظ‚ط§ط¯ط±ظٹظ† ظ†ط¬ظٹط¨ ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ‚ط¹ط¯ط©');
            if (!roomSnap.hasData || !roomSnap.data!.exists) {
              return _notice('ط¨ظ†ط¬ظ‡ط² ط§ظ„ظ‚ط¹ط¯ط©...');
            }
            final room = roomSnap.data!.data() ?? {};
            final players = (room['players'] as List<dynamic>? ?? [])
                .whereType<Map>()
                .map((raw) => Map<String, dynamic>.from(raw))
                .toList();
            final names = <String, String>{
              for (final p in players)
                if (p['uid'] is String)
                  p['uid'] as String: (p['nickname'] ?? 'ظ„ط§ط¹ط¨').toString(),
            };
            final roundNumber = room['roundNumber'] ?? 1;
            return StreamBuilder<ShayebDocSnapshot<Map<String, dynamic>>>(
              stream: api.watchPublicRound(widget.roomId),
              builder: (context, publicSnap) {
                if (publicSnap.hasError) return _notice('ظپظٹ ظ…ط´ظƒظ„ط© ظپظٹ ظ…ط²ط§ظ…ظ†ط© ط§ظ„ط¯ظˆط±');
                if (!publicSnap.hasData || !publicSnap.data!.exists) {
                  return _notice('ظ…ط³طھظ†ظٹظٹظ† ط¨ط¯ط§ظٹط© ط§ظ„ظ„ط¹ط¨ط©');
                }
                final game = publicSnap.data!.data() ?? {};
                final counts =
                    Map<String, dynamic>.from(game['handCounts'] as Map? ?? {});
                final targetId = game['drawTargetId'] as String?;
                final myTurn = game['currentPlayerId'] == api.uid;
                final version = (game['version'] as num?)?.toInt() ?? 0;
                final finished = game['status'] == 'finished';
                final playerIds = (game['playerOrder'] as List<dynamic>? ?? [])
                    .map((v) => v.toString())
                    .toList();
                final opponents = playerIds.where((id) => id != api.uid).toList();
                return SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'ط§ظ„ط¬ظˆظ„ط© $roundNumber ظ…ظ† ${room['totalRounds'] ?? 5}',
                        style: const TextStyle(
                          color: Color(0xFFD5AA59),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final opponent in opponents)
                            _playerChip(
                              names[opponent] ?? 'لاعب',
                              (counts[opponent] as num?)?.toInt() ?? 0,
                              opponent == game['currentPlayerId'],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            padding: const EdgeInsets.all(18),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF123B32),
                              border: Border.all(
                                color: const Color(0xFFD5AA59),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(70),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 20),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.style,
                                  color: Color(0xFFD5AA59),
                                  size: 36,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  finished
                                      ? 'ط§ظ„ط´ط§ظٹط¨ ظ„ط¨ط³ ظپظٹ ${names[game['loserId']] ?? 'ظ„ط§ط¹ط¨'}!'
                                      : myTurn
                                          ? 'ط¯ظˆط±ظƒ ظٹط§ ظ…ط¹ظ„ظ…! ط§ط³ط­ط¨ ظˆط±ظ‚ط©'
                                          : 'ط§ط³طھظ†ظ‰ ط¯ظˆط±ظƒ',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFF5E9D1),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                if (myTurn && !finished && targetId != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'ط¨طھط³ط­ط¨ ظ…ظ† ${names[targetId] ?? 'ظ„ط§ط¹ط¨'}',
                                    style: const TextStyle(
                                      color: Color(0xFFF5E9D1),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 105,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      shrinkWrap: true,
                                      itemCount:
                                          (counts[targetId] as num?)?.toInt() ?? 0,
                                      itemBuilder: (_, index) => GestureDetector(
                                        onTap: busy
                                            ? null
                                            : () => pickCard(index, version),
                                        child: Container(
                                          width: 65,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB93B3B),
                                            border: Border.all(
                                              color: const Color(0xFFF5E9D1),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.auto_awesome,
                                            color: Color(0xFFFFF9EF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (busy)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 12),
                                      child: CircularProgressIndicator(),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      StreamBuilder<ShayebDocSnapshot<Map<String, dynamic>>>(
                        stream: api.watchOwnHand(widget.roomId),
                        builder: (context, handSnap) {
                          final cards =
                              (handSnap.data?.data()?['cards'] as List<dynamic>? ??
                                      [])
                                  .whereType<Map>()
                                  .map((raw) => Map<String, dynamic>.from(raw))
                                  .toList();
                          return Column(
                            children: [
                              Text(
                                'ظˆط±ظ‚ظƒ (${cards.length})',
                                style: const TextStyle(
                                  color: Color(0xFFD5AA59),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 115,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  itemCount: cards.length,
                                  itemBuilder: (context, i) {
                                    final card = cards[i];
                                    final suit = card['suit']?.toString() ?? '';
                                    final symbol = {
                                          'hearts': 'â™¥',
                                          'diamonds': 'â™¦',
                                          'clubs': 'â™£',
                                          'spades': 'â™ ',
                                        }[suit] ??
                                        '?';
                                    final isRed =
                                        suit == 'hearts' || suit == 'diamonds';
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      width: 68,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF9EF),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: const Color(0xFFD5AA59),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            card['rank']?.toString() ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 25,
                                              color: isRed
                                                  ? const Color(0xFFB93B3B)
                                                  : Colors.black,
                                            ),
                                          ),
                                          Text(
                                            symbol,
                                            style: TextStyle(
                                              fontSize: 32,
                                              color: isRed
                                                  ? const Color(0xFFB93B3B)
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _playerChip(String name, Object count, bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD5AA59) : const Color(0xFF23453B),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          '$name â€¢ $count ظˆط±ظ‚ط©',
          style: TextStyle(
            color: active ? Colors.black : const Color(0xFFF5E9D1),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _notice(String message) => Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFFF5E9D1)),
        ),
      );
}

