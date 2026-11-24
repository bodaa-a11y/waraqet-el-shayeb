import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sound/sound_service.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../cards/domain/playing_card.dart';
import '../../cards/presentation/playing_card_widget.dart';
import '../animations/card_dealing_animation.dart';
import '../animations/card_draw_animation.dart';
import '../animations/card_pair_animation.dart';
import '../animations/card_shuffling_animation.dart';
import '../animations/game_animation_coordinator.dart';
import '../animations/player_reaction_animation.dart';
import '../animations/table_ambient_animation.dart';
import '../animations/theme_transition_animation.dart';
import '../animations/turn_highlight_animation.dart';
import '../application/game_controller.dart';
import '../application/game_visual_theme_provider.dart';
import '../domain/game_visual_theme.dart';
import '../domain/room_models.dart';
import 'widgets/animated_card_fan.dart';
import 'widgets/cinematic_table_surface.dart';
import 'widgets/egyptian_scene_background.dart';
import 'widgets/player_seat_layout.dart';
import 'widgets/theme_switcher.dart';

/// Full Cinematic Multiplayer Game Table Screen.
/// Driven by `GameAnimationCoordinator` over authoritative state transitions.
class GameTableScreen extends ConsumerStatefulWidget {
  const GameTableScreen({
    super.key,
    required this.onOpenChat,
    required this.onLeaveMatch,
  });

  final VoidCallback onOpenChat;
  final VoidCallback onLeaveMatch;

  @override
  ConsumerState<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends ConsumerState<GameTableScreen> {
  final GameAnimationCoordinator _coordinator = GameAnimationCoordinator();
  int? _selectedTargetCardIndex;
  int? _selectedOwnCardIndex;
  Timer? _countdownTimer;
  int _remainingSeconds = 45;
  String? _claimedTimeoutKey;

  // Active non-blocking visual overlays triggered by authoritative events
  bool _showShuffleOverlay = false;
  bool _showDealingOverlay = false;
  bool _showDrawFlightOverlay = false;
  int _activePairAnimationCount = 0;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = ref.read(activeGameSessionProvider);
      final pub = session.publicRound;
      final room = session.room;
      if (room == null || pub == null || pub.status != 'playing') return;
      final deadline = pub.turnDeadlineMs;
      if (deadline == null) return;
      final seconds =
          ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
      final remaining = seconds.clamp(0, 120).toInt();
      if (_remainingSeconds != remaining) {
        setState(() => _remainingSeconds = remaining);
      }
      final key = '${room.roomId}:${room.roundNumber}:${pub.version}';
      if (seconds <= 0 &&
          session.isOnlineFirebase &&
          _claimedTimeoutKey != key) {
        _claimedTimeoutKey = key;
        unawaited(_claimTimeout(room.roomId, pub.version));
      }
    });
  }

  Future<void> _claimTimeout(String roomId, int expectedVersion) async {
    try {
      await ref.read(activeGameSessionProvider.notifier).bridge.claimTurnTimeout(
            roomId: roomId,
            expectedVersion: expectedVersion,
          );
    } catch (_) {}
  }

  void _processNewAnimationEvents(
    RoomStateModel room,
    PublicRoundModel pub,
    PlayerProfile profile,
    GameEffectsQuality quality,
  ) {
    final newEvents = _coordinator.deriveNewEvents(
      room: room,
      publicRound: pub,
      localPlayerUid: profile.uid,
    );
    if (newEvents.isEmpty || quality.isMinimal) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final ev in newEvents) {
        switch (ev.type) {
          case GameAnimationEventType.roundShuffleAndDeal:
            setState(() {
              _showShuffleOverlay = true;
              _showDealingOverlay = false;
            });
            break;
          case GameAnimationEventType.cardDrawn:
            setState(() => _showDrawFlightOverlay = true);
            break;
          case GameAnimationEventType.pairMatched:
            setState(() => _activePairAnimationCount = ev.pairsRemoved);
            break;
          default:
            break;
        }
      }
    });
  }

  Future<void> _leaveAfterConfirmation() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('هتسيب القعدة؟'),
        content: const Text(
          'ممكن ترجع للصفحة الرئيسية، بس القعدة هتكمل حسب قوانينها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لا، هكمل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('أسيب القعدة'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    await ref.read(activeGameSessionProvider.notifier).leaveCurrentRoom();
    if (mounted) widget.onLeaveMatch();
  }

  Future<void> _draw(int cardIndex) async {
    final session = ref.read(activeGameSessionProvider);
    if (session.isActionPending) return;
    unawaited(
      ref.read(soundServiceProvider).trigger(ShayebSoundEvent.cardSelect),
    );
    setState(() => _selectedTargetCardIndex = cardIndex);
    try {
      await ref
          .read(activeGameSessionProvider.notifier)
          .drawCardFromTarget(cardIndex);
    } finally {
      if (mounted) setState(() => _selectedTargetCardIndex = null);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeGameSessionProvider);
    final profile = ref.watch(playerProfileProvider);
    final theme = ref.watch(currentGameVisualThemeProvider);
    final room = session.room;
    final pub = session.publicRound;
    if (room == null || pub == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final quality = GameEffectsQuality.fromKey(
      profile.effectsQualityKey,
      reducedMotion: profile.reducedMotion,
    );
    _processNewAnimationEvents(room, pub, profile, quality);

    final isMyTurn =
        pub.status == 'playing' && pub.currentPlayerId == profile.uid;
    final targetCount = pub.drawTargetId == null
        ? 0
        : (pub.handCounts[pub.drawTargetId] ?? 0);
    final order = pub.playerOrder;
    final myIndex = order.indexOf(profile.uid);
    final opponents = <String>[];
    if (myIndex >= 0) {
      for (int i = 1; i < order.length; i++) {
        opponents.add(order[(myIndex + i) % order.length]);
      }
    } else {
      opponents.addAll(order.where((uid) => uid != profile.uid));
    }

    final totalTimerSecs = room.turnTimerSeconds > 0 ? room.turnTimerSeconds : 45;
    final turnProgress = pub.turnDeadlineMs != null
        ? (_remainingSeconds / totalTimerSecs).clamp(0.0, 1.0)
        : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ThemeTransitionAnimation(
        theme: theme,
        quality: quality,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, viewport) {
              final roomy =
                  viewport.maxWidth >= 760 && viewport.maxHeight >= 560;
              return Stack(
                fit: StackFit.expand,
                children: [
                  EgyptianSceneBackground(theme: theme),
                  Positioned.fill(
                    child: TableAmbientAnimation(
                      theme: theme,
                      quality: quality,
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        _GameTopBar(
                          room: room,
                          theme: theme,
                          remainingSeconds: _remainingSeconds,
                          hasTimer: pub.turnDeadlineMs != null &&
                              pub.status == 'playing',
                          onLeave: _leaveAfterConfirmation,
                          onChat: widget.onOpenChat,
                        ),
                        if (session.bannerNotification != null)
                          _GameBanner(
                            text: session.bannerNotification!,
                            onClose: () => ref
                                .read(activeGameSessionProvider.notifier)
                                .clearBanner(),
                          ),
                        if (!roomy)
                          SizedBox(
                            height: 105,
                            child: ListView.separated(
                              key: const Key('mobile_opponent_strip'),
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              itemCount: opponents.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, i) => _buildSeat(
                                room: room,
                                round: pub,
                                uid: opponents[i],
                                theme: theme,
                                isMyTurn: isMyTurn,
                                quality: quality,
                                turnProgress: turnProgress,
                                reaction: session.activeReactions[opponents[i]],
                                compact: true,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              roomy ? 28 : 8,
                              4,
                              roomy ? 28 : 8,
                              4,
                            ),
                            child: CinematicTableSurface(
                              theme: theme,
                              highlightTurn: isMyTurn,
                              reducedMotion: quality.isMinimal,
                              child: LayoutBuilder(
                                builder: (context, board) => Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (roomy)
                                      ..._buildSeatRing(
                                        opponents,
                                        room,
                                        pub,
                                        theme,
                                        isMyTurn,
                                        quality,
                                        turnProgress,
                                        session.activeReactions,
                                      ),
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 440,
                                        ),
                                        child: SingleChildScrollView(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              top: roomy ? 53 : 0,
                                              bottom: 31,
                                            ),
                                            child: _ActiveTableContent(
                                              room: room,
                                              pub: pub,
                                              isMyTurn: isMyTurn,
                                              targetCount: targetCount,
                                              pending: session.isActionPending,
                                              selectedTargetCardIndex:
                                                  _selectedTargetCardIndex,
                                              reducedMotion: quality.isMinimal,
                                              quality: quality,
                                              remainingSeconds:
                                                  pub.turnDeadlineMs != null
                                                      ? _remainingSeconds
                                                      : null,
                                              onDraw: _draw,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Non-blocking Cinematic Shuffle Overlay
                                    if (_showShuffleOverlay)
                                      IgnorePointer(
                                        child: Center(
                                          child: CardShufflingAnimation(
                                            quality: quality,
                                            onCompleted: () {
                                              if (!mounted) return;
                                              setState(() {
                                                _showShuffleOverlay = false;
                                                _showDealingOverlay = true;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    // Non-blocking Batched Dealing Flight Overlay
                                    if (_showDealingOverlay)
                                      IgnorePointer(
                                        child: Positioned.fill(
                                          child: CardDealingAnimation(
                                            playerCount:
                                                pub.playerOrder.length,
                                            quality: quality,
                                            onCardPacketDealt: () {
                                              ref
                                                  .read(soundServiceProvider)
                                                  .trigger(
                                                    ShayebSoundEvent.cardDeal,
                                                  );
                                            },
                                            onCompleted: () {
                                              if (!mounted) return;
                                              setState(
                                                () =>
                                                    _showDealingOverlay = false,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    // Non-blocking Bezier Draw Flight Overlay
                                    if (_showDrawFlightOverlay)
                                      IgnorePointer(
                                        child: Positioned.fill(
                                          child: CardDrawAnimation(
                                            quality: quality,
                                            revealedForAuthorizedOwner:
                                                pub.lastMoveActorId ==
                                                            profile.uid &&
                                                        session
                                                            .ownHand.isNotEmpty
                                                    ? session.ownHand.last
                                                    : null,
                                            onCompleted: () {
                                              if (!mounted) return;
                                              setState(
                                                () => _showDrawFlightOverlay =
                                                    false,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    // Non-blocking Pair Match Sparkle Overlay
                                    if (_activePairAnimationCount > 0)
                                      IgnorePointer(
                                        child: Center(
                                          child: CardPairAnimation(
                                            pairsCount:
                                                _activePairAnimationCount,
                                            quality: quality,
                                            onCompleted: () {
                                              if (!mounted) return;
                                              setState(
                                                () =>
                                                    _activePairAnimationCount =
                                                        0,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: _QuickReactions(
                                        onSend: (emoji) => ref
                                            .read(
                                              activeGameSessionProvider
                                                  .notifier,
                                            )
                                            .sendChatMessage(
                                              emoji,
                                              type: 'reaction',
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        _OwnPlayerHandPanel(
                          theme: theme,
                          nickname: profile.nickname,
                          avatarId: profile.avatarId,
                          avatarState:
                              GameAnimationCoordinator.resolveAvatarState(
                            room: room,
                            publicRound: pub,
                            playerUid: profile.uid,
                            isCurrentlyDrawing: session.isActionPending,
                          ),
                          turnProgress: isMyTurn ? turnProgress : null,
                          quality: quality,
                          score: room.scores[profile.uid] ?? 0,
                          reaction: session.activeReactions[profile.uid],
                          ownHand: session.ownHand,
                          selectedIndex: _selectedOwnCardIndex,
                          reducedMotion: quality.isMinimal,
                          onSelected: (index) {
                            ref
                                .read(soundServiceProvider)
                                .trigger(ShayebSoundEvent.cardSelect);
                            setState(() {
                              _selectedOwnCardIndex =
                                  _selectedOwnCardIndex == index ? null : index;
                            });
                          },
                          onSort: () => ref
                              .read(activeGameSessionProvider.notifier)
                              .reorderOwnHand(sortByRank: true),
                          onShuffle: () => ref
                              .read(activeGameSessionProvider.notifier)
                              .reorderOwnHand(sortByRank: false),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSeat({
    required RoomStateModel room,
    required PublicRoundModel round,
    required String uid,
    required GameVisualTheme theme,
    required bool isMyTurn,
    required GameEffectsQuality quality,
    required double? turnProgress,
    required String? reaction,
    bool compact = false,
  }) {
    final count = round.handCounts[uid] ?? 0;
    final avatarState = GameAnimationCoordinator.resolveAvatarState(
      room: room,
      publicRound: round,
      playerUid: uid,
    );
    return _OpponentSeat(
      nickname: room.nicknameOf(uid),
      avatarId: room.avatarOf(uid),
      avatarState: avatarState,
      quality: quality,
      turnProgress: round.currentPlayerId == uid ? turnProgress : null,
      count: count,
      score: room.scores[uid] ?? 0,
      isCurrent: round.currentPlayerId == uid,
      isDrawTarget: isMyTurn && round.drawTargetId == uid,
      hasEscaped: count == 0 && round.finishOrder.contains(uid),
      reaction: reaction,
      gold: theme.goldColor,
      compact: compact,
    );
  }

  List<Widget> _buildSeatRing(
    List<String> opponents,
    RoomStateModel room,
    PublicRoundModel round,
    GameVisualTheme theme,
    bool isMyTurn,
    GameEffectsQuality quality,
    double? turnProgress,
    Map<String, String> reactions,
  ) {
    final positions = PlayerSeatLayout.positions(opponents.length);
    return [
      for (int i = 0; i < opponents.length && i < positions.length; i++)
        Align(
          alignment: positions[i],
          child: _buildSeat(
            room: room,
            round: round,
            uid: opponents[i],
            theme: theme,
            isMyTurn: isMyTurn,
            quality: quality,
            turnProgress: turnProgress,
            reaction: reactions[opponents[i]],
          ),
        ),
    ];
  }
}

class _GameTopBar extends StatelessWidget {
  const _GameTopBar({
    required this.room,
    required this.theme,
    required this.remainingSeconds,
    required this.hasTimer,
    required this.onLeave,
    required this.onChat,
  });
  final RoomStateModel room;
  final GameVisualTheme theme;
  final int remainingSeconds;
  final bool hasTimer;
  final VoidCallback onLeave;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xF01E1009), Color(0xE7291C0F), Color(0xF01E1009)],
        ),
        border: Border(bottom: BorderSide(color: Color(0x88D5AA59))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _RoundAction(
            icon: Icons.logout_rounded,
            tooltip: 'سيب القعدة',
            color: theme.goldColor,
            onTap: onLeave,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ArEgStrings.gameTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.goldColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'الجولة ${room.roundNumber} / ${room.totalRounds}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (hasTimer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: remainingSeconds <= 10
                    ? const Color(0xFF9B3434)
                    : Colors.black45,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '⏱ $remainingSeconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 136),
            child: const ThemeSwitcherWidget(),
          ),
          const SizedBox(width: 5),
          _RoundAction(
            icon: Icons.chat_bubble_rounded,
            tooltip: 'شات القعدة',
            color: theme.goldColor,
            onTap: onChat,
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      visualDensity: VisualDensity.compact,
      icon: Container(
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
          border: Border.all(color: color, width: 1.3),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _GameBanner extends StatelessWidget {
  const _GameBanner({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xDE3D2A1B),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE7BE70),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            InkWell(
              onTap: onClose,
              child: const Icon(Icons.close, color: Colors.white70, size: 17),
            ),
          ],
        ),
      );
}

class _OpponentSeat extends StatelessWidget {
  const _OpponentSeat({
    required this.nickname,
    required this.avatarId,
    required this.avatarState,
    required this.quality,
    required this.count,
    required this.score,
    required this.isCurrent,
    required this.isDrawTarget,
    required this.hasEscaped,
    required this.gold,
    this.turnProgress,
    this.reaction,
    this.compact = false,
  });

  final String nickname;
  final String avatarId;
  final AvatarMotionState avatarState;
  final GameEffectsQuality quality;
  final double? turnProgress;
  final int count;
  final int score;
  final bool isCurrent;
  final bool isDrawTarget;
  final bool hasEscaped;
  final String? reaction;
  final Color gold;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '$nickname، $count ورقة، $score نقطة${isDrawTarget ? '، اسحب منه' : ''}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: compact ? 132 : 138,
        height: compact ? 88 : 108,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDrawTarget
              ? const Color(0xDF5A371B)
              : const Color(0xE520160F),
          border: Border.all(
            color: hasEscaped ? Colors.greenAccent : gold,
            width: isDrawTarget || isCurrent ? 2.6 : 1.2,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
                  isDrawTarget ? gold.withValues(alpha: 0.5) : Colors.black38,
              blurRadius: isDrawTarget ? 17 : 7,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedEgyptianCharacterAvatar(
                  avatarId: avatarId,
                  state: avatarState,
                  size: compact ? 32 : 38,
                  goldColor: gold,
                  quality: quality,
                  turnProgress: turnProgress,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nickname,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        hasEscaped
                            ? 'فلت منها ✨'
                            : '$count ورقة • $score نقطة',
                        maxLines: 1,
                        style: TextStyle(fontSize: 10, color: gold),
                      ),
                      if (reaction != null)
                        Text(reaction!, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 3),
              if (hasEscaped)
                const Text('🎉', style: TextStyle(fontSize: 14))
              else
                SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (int i = 0; i < (count < 3 ? count : 3); i++)
                        Transform.translate(
                          offset: Offset((i - 1) * 13.0, 0),
                          child: Transform.rotate(
                            angle: (i - 1) * 0.14,
                            child: const IgnorePointer(
                              child: PlayingCardWidget(
                                faceDown: true,
                                width: 18,
                                height: 26,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveTableContent extends StatelessWidget {
  const _ActiveTableContent({
    required this.room,
    required this.pub,
    required this.isMyTurn,
    required this.targetCount,
    required this.pending,
    required this.selectedTargetCardIndex,
    required this.reducedMotion,
    required this.quality,
    required this.onDraw,
    this.remainingSeconds,
  });
  final RoomStateModel room;
  final PublicRoundModel pub;
  final bool isMyTurn;
  final int targetCount;
  final bool pending;
  final int? selectedTargetCardIndex;
  final bool reducedMotion;
  final GameEffectsQuality quality;
  final int? remainingSeconds;
  final ValueChanged<int> onDraw;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xC315140D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x70E5BB70)),
          ),
          child: AnimatedSwitcher(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 360),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '${ArEgStrings.discardPileLabel}: ${pub.discardCount ~/ 2} جوز',
              key: ValueKey(pub.discardCount),
              style: const TextStyle(
                color: Color(0xFFF1D39D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        CinematicTurnIndicator(
          isMyTurn: isMyTurn,
          activePlayerName: room.nicknameOf(pub.currentPlayerId),
          targetPlayerName: room.nicknameOf(pub.drawTargetId),
          remainingSeconds: remainingSeconds,
          quality: quality,
        ),
        const SizedBox(height: 8),
        if (isMyTurn && targetCount > 0) ...[
          const Text(
            'اختار ورقة مقلوبة من اللي قدامك',
            style: TextStyle(color: Color(0xFFFFEAC6), fontSize: 11.5),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 116,
            child: AnimatedTargetFan(
              count: targetCount,
              pending: pending,
              selectedIndex: selectedTargetCardIndex,
              reducedMotion: reducedMotion,
              onPick: onDraw,
            ),
          ),
        ] else
          SizedBox(
            height: 83,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < targetCount.clamp(0, 4); i++)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: PlayingCardWidget(
                      faceDown: true,
                      width: 41,
                      height: 62,
                    ),
                  ),
                if (targetCount == 0)
                  const Text(
                    '☕ القعدة مكملة',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickReactions extends StatelessWidget {
  const _QuickReactions({required this.onSend});
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        children: [
          for (final emoji in ArEgStrings.quickReactions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSend(emoji),
                child: Container(
                  alignment: Alignment.center,
                  width: 33,
                  decoration: BoxDecoration(
                    color: const Color(0xC020110C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x60E7BE70)),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OwnPlayerHandPanel extends StatelessWidget {
  const _OwnPlayerHandPanel({
    required this.theme,
    required this.nickname,
    required this.avatarId,
    required this.avatarState,
    required this.quality,
    required this.score,
    required this.reaction,
    required this.ownHand,
    required this.selectedIndex,
    required this.reducedMotion,
    required this.onSelected,
    required this.onSort,
    required this.onShuffle,
    this.turnProgress,
  });

  final GameVisualTheme theme;
  final String nickname;
  final String avatarId;
  final AvatarMotionState avatarState;
  final GameEffectsQuality quality;
  final double? turnProgress;
  final int score;
  final String? reaction;
  final List<PlayingCardModel> ownHand;
  final int? selectedIndex;
  final bool reducedMotion;
  final ValueChanged<int> onSelected;
  final VoidCallback onSort;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 166),
      decoration: BoxDecoration(
        color: const Color(0xF328190D),
        border: Border(top: BorderSide(color: theme.goldColor, width: 2)),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, -3)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnimatedEgyptianCharacterAvatar(
                avatarId: avatarId,
                state: avatarState,
                size: 32,
                goldColor: theme.goldColor,
                quality: quality,
                turnProgress: turnProgress,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$nickname • ${ownHand.length} ورقة • $score نقطة ${reaction ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.goldColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'رتب ورقك',
                onPressed: ownHand.length > 1 ? onSort : null,
                icon: const Icon(Icons.sort_by_alpha_rounded, size: 19),
              ),
              IconButton(
                tooltip: 'لخبط ترتيب الورق',
                onPressed: ownHand.length > 1 ? onShuffle : null,
                icon: const Icon(Icons.shuffle_rounded, size: 19),
              ),
            ],
          ),
          if (ownHand.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                '🎉 فلتّ من الشايب! اتفرج على اللي لسه بيلعبوا',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFF1D39D), fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 132,
              child: AnimatedCardFan(
                cards: ownHand,
                selectedIndex: selectedIndex,
                reducedMotion: reducedMotion,
                onCardSelected: onSelected,
              ),
            ),
        ],
      ),
    );
  }
}
