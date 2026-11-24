import '../domain/room_models.dart';

/// User-configurable visual & motion effects quality tiers (Section 18).
enum GameEffectsQuality {
  full('full', 'مؤثرات سينمائية كاملة ✨'),
  balanced('balanced', 'مؤثرات متوازنة (مستحسن) ⚡'),
  reduced('reduced', 'مؤثرات خفيفة للأجهزة الضعيفة 📱'),
  minimal('minimal', 'إيقاف الأنيميشن غير الضروري 🚫');

  const GameEffectsQuality(this.key, this.arabicLabel);
  final String key;
  final String arabicLabel;

  bool get skipHeavyParticles =>
      this == GameEffectsQuality.reduced || this == GameEffectsQuality.minimal;

  bool get isMinimal => this == GameEffectsQuality.minimal;

  double get durationMultiplier {
    switch (this) {
      case GameEffectsQuality.full:
        return 1.0;
      case GameEffectsQuality.balanced:
        return 0.85;
      case GameEffectsQuality.reduced:
        return 0.55;
      case GameEffectsQuality.minimal:
        return 0.0;
    }
  }

  static GameEffectsQuality fromKey(String? raw, {bool reducedMotion = false}) {
    if (reducedMotion) return GameEffectsQuality.minimal;
    for (final q in GameEffectsQuality.values) {
      if (q.key == raw) return q;
    }
    return GameEffectsQuality.full;
  }
}

/// All 8 required expressive Egyptian character avatar states (Section 9).
enum AvatarMotionState {
  idle,
  yourTurn,
  drawing,
  pairMatched,
  suspense,
  victory,
  defeat,
  disconnected,
}

/// Authoritative server-driven visual event types (Section 17).
enum GameAnimationEventType {
  roundShuffleAndDeal,
  cardDrawn,
  pairMatched,
  playerEscaped,
  turnChanged,
  kingRevealCinematic,
  challengeReveal,
  matchVictory,
  roundDefeat,
}

class GameAnimationEvent {
  const GameAnimationEvent({
    required this.eventId,
    required this.roomId,
    required this.roundId,
    required this.turnNumber,
    required this.type,
    required this.timestampMs,
    this.actorUid,
    this.targetUid,
    this.loserUid,
    this.winnerUid,
    this.pairsRemoved = 0,
    this.challengeInstanceId,
  });

  final String eventId;
  final String roomId;
  final String roundId;
  final int turnNumber;
  final GameAnimationEventType type;
  final int timestampMs;
  final String? actorUid;
  final String? targetUid;
  final String? loserUid;
  final String? winnerUid;
  final int pairsRemoved;
  final String? challengeInstanceId;
}

/// Centralized, deterministic animation event coordinator & deduplicator.
/// Maps authoritative Firestore snapshots (`RoomStateModel` + `PublicRoundModel`)
/// to local animation events while guaranteeing:
/// 1. Repeated Firestore snapshots with the same state/version NEVER trigger duplicate animations.
/// 2. Reconnecting mid-round syncs to the current state without replaying old cinematics.
/// 3. Hidden opponent card identities are never required or exposed.
class GameAnimationCoordinator {
  final Set<String> _processedEventIds = <String>{};
  String? _lastSyncedRoomId;
  String? _lastSyncedRoundId;
  int? _lastSyncedVersion;

  Set<String> get processedEventIds => Set<String>.unmodifiable(_processedEventIds);

  void reset() {
    _processedEventIds.clear();
    _lastSyncedRoomId = null;
    _lastSyncedRoundId = null;
    _lastSyncedVersion = null;
  }

  /// Evaluates an incoming `(room, publicRound)` snapshot pair and returns only
  /// NEW animation events that have not yet been played.
  /// If `isReconnectSnapshot` is true (e.g., joining an already-started round at turn > 0),
  /// it marks historical events as seen without replaying past shuffle/deal cinematics.
  List<GameAnimationEvent> deriveNewEvents({
    required RoomStateModel? room,
    required PublicRoundModel? publicRound,
    required String localPlayerUid,
    int? nowMs,
  }) {
    if (room == null || publicRound == null) return const [];
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final events = <GameAnimationEvent>[];

    final isFirstSnapshotForRound = _lastSyncedRoomId != room.roomId ||
        _lastSyncedRoundId != publicRound.id;

    // Reconnection guard: if we attach to a round that is already past turn 0,
    // record the round deal event as already seen so we don't replay the deal animation.
    final dealEventId = '${room.roomId}:${publicRound.id}:deal_r${room.roundNumber}';
    if (isFirstSnapshotForRound && publicRound.turnNumber > 0) {
      _processedEventIds.add(dealEventId);
    }

    // 1. Shuffle & Deal at start of round (turnNumber == 0, status == 'playing')
    if (publicRound.turnNumber == 0 &&
        publicRound.status == 'playing' &&
        _markIfNew(dealEventId)) {
      events.add(
        GameAnimationEvent(
          eventId: dealEventId,
          roomId: room.roomId,
          roundId: publicRound.id,
          turnNumber: 0,
          type: GameAnimationEventType.roundShuffleAndDeal,
          timestampMs: ts,
        ),
      );
    }

    // 2. Turn transition & Draw / Pair Match / Escape events when version advances
    if (!isFirstSnapshotForRound &&
        _lastSyncedVersion != null &&
        publicRound.version > _lastSyncedVersion!) {
      final drawEventId =
          '${room.roomId}:${publicRound.id}:draw_v${publicRound.version}';
      if (_markIfNew(drawEventId)) {
        events.add(
          GameAnimationEvent(
            eventId: drawEventId,
            roomId: room.roomId,
            roundId: publicRound.id,
            turnNumber: publicRound.turnNumber,
            type: GameAnimationEventType.cardDrawn,
            timestampMs: ts,
            actorUid: publicRound.lastMoveActorId,
            targetUid: publicRound.lastMoveTargetId,
            pairsRemoved: publicRound.lastMovePairsRemoved,
          ),
        );
      }

      if (publicRound.lastMovePairsRemoved > 0) {
        final pairEventId =
            '${room.roomId}:${publicRound.id}:pair_v${publicRound.version}';
        if (_markIfNew(pairEventId)) {
          events.add(
            GameAnimationEvent(
              eventId: pairEventId,
              roomId: room.roomId,
              roundId: publicRound.id,
              turnNumber: publicRound.turnNumber,
              type: GameAnimationEventType.pairMatched,
              timestampMs: ts,
              actorUid: publicRound.lastMoveActorId,
              targetUid: publicRound.lastMoveTargetId,
              pairsRemoved: publicRound.lastMovePairsRemoved,
            ),
          );
        }
      }
    }

    // 3. Turn ownership highlight event
    if (publicRound.status == 'playing' && publicRound.currentPlayerId != null) {
      final turnEventId =
          '${room.roomId}:${publicRound.id}:turn_v${publicRound.version}_${publicRound.currentPlayerId}';
      if (_markIfNew(turnEventId)) {
        events.add(
          GameAnimationEvent(
            eventId: turnEventId,
            roomId: room.roomId,
            roundId: publicRound.id,
            turnNumber: publicRound.turnNumber,
            type: GameAnimationEventType.turnChanged,
            timestampMs: ts,
            actorUid: publicRound.currentPlayerId,
            targetUid: publicRound.drawTargetId,
          ),
        );
      }
    }

    // 4. Authoritative Round Completion -> King Reveal Cinematic + Victory / Defeat
    if (publicRound.status == 'finished' && publicRound.loserId != null) {
      final kingEventId =
          '${room.roomId}:${publicRound.id}:king_reveal_${publicRound.loserId}';
      if (_markIfNew(kingEventId)) {
        final winnerUid = publicRound.finishOrder.isNotEmpty
            ? publicRound.finishOrder.first
            : null;
        events.add(
          GameAnimationEvent(
            eventId: kingEventId,
            roomId: room.roomId,
            roundId: publicRound.id,
            turnNumber: publicRound.turnNumber,
            type: GameAnimationEventType.kingRevealCinematic,
            timestampMs: ts,
            loserUid: publicRound.loserId,
            winnerUid: winnerUid,
          ),
        );

        if (publicRound.loserId == localPlayerUid) {
          final defeatId = '${room.roomId}:${publicRound.id}:defeat_$localPlayerUid';
          if (_markIfNew(defeatId)) {
            events.add(
              GameAnimationEvent(
                eventId: defeatId,
                roomId: room.roomId,
                roundId: publicRound.id,
                turnNumber: publicRound.turnNumber,
                type: GameAnimationEventType.roundDefeat,
                timestampMs: ts,
                loserUid: publicRound.loserId,
              ),
            );
          }
        } else if (room.status == 'finished') {
          final standings = MatchStandingRow.computeFromRoom(room);
          if (standings.isNotEmpty && standings.first.uid == localPlayerUid) {
            final victoryId = '${room.roomId}:match_victory_$localPlayerUid';
            if (_markIfNew(victoryId)) {
              events.add(
                GameAnimationEvent(
                  eventId: victoryId,
                  roomId: room.roomId,
                  roundId: publicRound.id,
                  turnNumber: publicRound.turnNumber,
                  type: GameAnimationEventType.matchVictory,
                  timestampMs: ts,
                  winnerUid: localPlayerUid,
                ),
              );
            }
          }
        }
      }
    }

    // 5. Challenge Reveal (idempotent per challengeInstanceId + redrawCount)
    final challenge = room.activeChallenge;
    if (challenge != null) {
      final chEventId =
          '${room.roomId}:challenge_${challenge.instanceId}_r${challenge.redrawCount}';
      if (_markIfNew(chEventId)) {
        events.add(
          GameAnimationEvent(
            eventId: chEventId,
            roomId: room.roomId,
            roundId: publicRound.id,
            turnNumber: publicRound.turnNumber,
            type: GameAnimationEventType.challengeReveal,
            timestampMs: ts,
            loserUid: challenge.loserUid,
            challengeInstanceId: challenge.instanceId,
          ),
        );
      }
    }

    _lastSyncedRoomId = room.roomId;
    _lastSyncedRoundId = publicRound.id;
    _lastSyncedVersion = publicRound.version;
    return events;
  }

  /// Resolves the current expressive animation state for a player's portrait.
  static AvatarMotionState resolveAvatarState({
    required RoomStateModel room,
    required PublicRoundModel publicRound,
    required String playerUid,
    bool isCurrentlyDrawing = false,
  }) {
    final player = room.players.where((p) => p.uid == playerUid).firstOrNull;
    if (player != null && !player.isConnected) {
      return AvatarMotionState.disconnected;
    }
    if (publicRound.status == 'finished') {
      if (publicRound.loserId == playerUid) {
        return AvatarMotionState.defeat;
      }
      return AvatarMotionState.victory;
    }
    final remainingCards = publicRound.handCounts[playerUid] ?? 0;
    if (remainingCards == 0 && publicRound.finishOrder.contains(playerUid)) {
      return AvatarMotionState.victory;
    }
    if (isCurrentlyDrawing && publicRound.currentPlayerId == playerUid) {
      return AvatarMotionState.drawing;
    }
    if (publicRound.lastMoveActorId == playerUid &&
        publicRound.lastMovePairsRemoved > 0) {
      return AvatarMotionState.pairMatched;
    }
    if (publicRound.currentPlayerId == playerUid) {
      return AvatarMotionState.yourTurn;
    }
    if (publicRound.drawTargetId == playerUid || remainingCards == 1) {
      return AvatarMotionState.suspense;
    }
    return AvatarMotionState.idle;
  }

  bool _markIfNew(String eventId) {
    if (_processedEventIds.contains(eventId)) return false;
    _processedEventIds.add(eventId);
    return true;
  }
}
