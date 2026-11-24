import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/sound/sound_service.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../shayeb_game_bridge.dart';
import '../../cards/domain/playing_card.dart';
import '../../challenges/domain/challenge_model.dart';
import '../domain/dart_rules_engine.dart';
import '../domain/room_models.dart';

final soundServiceProvider = Provider<ShayebSoundService>((ref) {
  final service = ShayebSoundService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final playerProfileProvider =
    StateNotifierProvider<PlayerProfileNotifier, PlayerProfile>((ref) {
  return PlayerProfileNotifier(ref);
});

class PlayerProfileNotifier extends StateNotifier<PlayerProfile> {
  PlayerProfileNotifier(this._ref)
      : super(
          const PlayerProfile(
            uid: 'local_player',
            nickname: 'معلم القهوة',
            avatarId: 'avatar_1',
          ),
        );

  final Ref _ref;

  Future<void> loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('shayeb_uid') ??
          'player_${100000 + Random().nextInt(899999)}';
      await prefs.setString('shayeb_uid', uid);
      final nickname = prefs.getString('shayeb_nickname') ?? 'معلم القهوة';
      final avatarId = prefs.getString('shayeb_avatar') ?? 'avatar_1';
      final sound = prefs.getBool('shayeb_sound') ?? true;
      final soundVolume = prefs.getDouble('shayeb_sound_volume') ?? 0.78;
      final haptics = prefs.getBool('shayeb_haptics') ?? true;
      final reducedMotion = prefs.getBool('shayeb_reduced_motion') ?? false;
      final effectsQualityKey =
          prefs.getString('shayeb_effects_quality') ?? 'full';

      state = PlayerProfile(
        uid: uid,
        nickname: nickname,
        avatarId: avatarId,
        soundEnabled: sound,
        soundVolume: soundVolume,
        hapticsEnabled: haptics,
        reducedMotion: reducedMotion,
        effectsQualityKey: effectsQualityKey,
      );
      final soundSvc = _ref.read(soundServiceProvider);
      soundSvc.soundEnabled = sound;
      soundSvc.volume = soundVolume;
      soundSvc.hapticsEnabled = haptics;
    } catch (_) {
      // Fallback for test environments without platform channels
    }
  }

  Future<void> updateProfile({
    String? uid,
    String? nickname,
    String? avatarId,
    bool? soundEnabled,
    double? soundVolume,
    bool? hapticsEnabled,
    bool? reducedMotion,
    String? effectsQualityKey,
  }) async {
    state = state.copyWith(
      uid: uid,
      nickname: nickname,
      avatarId: avatarId,
      soundEnabled: soundEnabled,
      soundVolume: soundVolume,
      hapticsEnabled: hapticsEnabled,
      reducedMotion: reducedMotion,
      effectsQualityKey: effectsQualityKey,
    );
    final soundSvc = _ref.read(soundServiceProvider);
    soundSvc.soundEnabled = state.soundEnabled;
    soundSvc.volume = state.soundVolume;
    soundSvc.hapticsEnabled = state.hapticsEnabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (uid != null) await prefs.setString('shayeb_uid', uid);
      if (nickname != null) await prefs.setString('shayeb_nickname', nickname);
      if (avatarId != null) await prefs.setString('shayeb_avatar', avatarId);
      if (soundEnabled != null) await prefs.setBool('shayeb_sound', soundEnabled);
      if (soundVolume != null) {
        await prefs.setDouble('shayeb_sound_volume', soundVolume);
      }
      if (hapticsEnabled != null) await prefs.setBool('shayeb_haptics', hapticsEnabled);
      if (reducedMotion != null) {
        await prefs.setBool('shayeb_reduced_motion', reducedMotion);
      }
      if (effectsQualityKey != null) {
        await prefs.setString('shayeb_effects_quality', effectsQualityKey);
      }
    } catch (_) {}
  }

  Future<void> resetPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
    await updateProfile(
      nickname: 'معلم القهوة',
      avatarId: 'avatar_1',
      soundEnabled: true,
      soundVolume: 0.78,
      hapticsEnabled: true,
      reducedMotion: false,
      effectsQualityKey: 'full',
    );
  }
}

/// Active multiplayer session state combining Room, PublicRound, PrivateHand, and Chat.
class ActiveGameSessionState {
  const ActiveGameSessionState({
    this.isOnlineFirebase = true,
    this.isConnecting = false,
    this.isActionPending = false,
    this.errorMessage,
    this.bannerNotification,
    this.room,
    this.publicRound,
    this.ownHand = const [],
    this.messages = const [],
    this.activeReactions = const {},
  });

  final bool isOnlineFirebase;
  final bool isConnecting;
  final bool isActionPending;
  final String? errorMessage;
  final String? bannerNotification;
  final RoomStateModel? room;
  final PublicRoundModel? publicRound;
  final List<PlayingCardModel> ownHand;
  final List<ChatMessageModel> messages;
  final Map<String, String> activeReactions;

  ActiveGameSessionState copyWith({
    bool? isOnlineFirebase,
    bool? isConnecting,
    bool? isActionPending,
    String? errorMessage,
    bool clearError = false,
    String? bannerNotification,
    bool clearBanner = false,
    RoomStateModel? room,
    PublicRoundModel? publicRound,
    bool clearPublicRound = false,
    List<PlayingCardModel>? ownHand,
    List<ChatMessageModel>? messages,
    Map<String, String>? activeReactions,
  }) {
    return ActiveGameSessionState(
      isOnlineFirebase: isOnlineFirebase ?? this.isOnlineFirebase,
      isConnecting: isConnecting ?? this.isConnecting,
      isActionPending: isActionPending ?? this.isActionPending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      bannerNotification:
          clearBanner ? null : (bannerNotification ?? this.bannerNotification),
      room: room ?? this.room,
      publicRound: clearPublicRound ? null : (publicRound ?? this.publicRound),
      ownHand: ownHand ?? this.ownHand,
      messages: messages ?? this.messages,
      activeReactions: activeReactions ?? this.activeReactions,
    );
  }
}

final activeGameSessionProvider =
    StateNotifierProvider<ActiveGameSessionController, ActiveGameSessionState>((ref) {
  return ActiveGameSessionController(ref);
});

class ActiveGameSessionController extends StateNotifier<ActiveGameSessionState> {
  ActiveGameSessionController(this._ref) : super(const ActiveGameSessionState());

  final Ref _ref;
  ShayebGameBridge? _bridge;
  StreamSubscription<dynamic>? _roomSub;
  StreamSubscription<dynamic>? _roundSub;
  StreamSubscription<dynamic>? _handSub;
  StreamSubscription<dynamic>? _chatSub;
  Timer? _botTimer;

  // Authoritative secret state used ONLY when in explicit Local Practice / Widget Test mode
  Map<String, List<PlayingCardModel>> _localSecretHands = {};
  List<PlayingCardModel> _localDiscarded = [];
  final Set<String> _localUsedChallenges = {};

  ShayebGameBridge get bridge => _bridge ??= ShayebGameBridge();

  PlayerProfile get _profile => _ref.read(playerProfileProvider);

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearBanner() {
    state = state.copyWith(clearBanner: true);
  }

  /// Creates an online Firebase room via Cloud Functions v2 (`createRoom`),
  /// or initializes an explicit local practice room if `localPracticeMode` is true.
  Future<String?> createRoom({
    required String title,
    required int maxPlayers,
    required int totalRounds,
    required String direction,
    required String visibility,
    required String challengeMode,
    required int turnTimerSeconds,
    bool localPracticeMode = false,
  }) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    await _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.buttonTap);

    if (localPracticeMode) {
      return _createLocalPracticeRoom(
        title: title,
        maxPlayers: maxPlayers,
        totalRounds: totalRounds,
        direction: direction,
        visibility: visibility,
        challengeMode: challengeMode,
        turnTimerSeconds: turnTimerSeconds,
      );
    }

    try {
      final uid = await bridge.ensureAnonymousLogin();
      await _ref.read(playerProfileProvider.notifier).updateProfile(uid: uid);
      final response = await bridge.createRoom(
        nickname: _profile.nickname,
        avatarId: _profile.avatarId,
        title: title,
        maxPlayers: maxPlayers,
        totalRounds: totalRounds,
        direction: direction,
        visibility: visibility,
        challengeMode: challengeMode,
        turnTimerSeconds: turnTimerSeconds,
      );
      final roomId = response['roomId'] as String;
      _subscribeToRoom(roomId);
      state = state.copyWith(isConnecting: false, isOnlineFirebase: true);
      return roomId;
    } catch (error) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage:
            'تعذر الاتصال بسيرفر اللعبة (${error.toString()}). تقدر تراجع إعدادات الاتصال أو تجرب قعدة التدريب المحلية.',
      );
      return null;
    }
  }

  /// Joins an online room by 6-char code or roomId.
  Future<String?> joinOnlineRoom({String? code, String? roomId}) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    await _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.buttonTap);

    // If the user enters the code of an active local room in the current session
    if (code != null &&
        !state.isOnlineFirebase &&
        state.room != null &&
        state.room!.code.toUpperCase() == code.trim().toUpperCase()) {
      state = state.copyWith(isConnecting: false);
      return state.room!.roomId;
    }

    try {
      final uid = await bridge.ensureAnonymousLogin();
      await _ref.read(playerProfileProvider.notifier).updateProfile(uid: uid);
      final joinedRoomId = await bridge.joinRoom(
        code: code,
        roomId: roomId,
        nickname: _profile.nickname,
        avatarId: _profile.avatarId,
      );
      _subscribeToRoom(joinedRoomId);
      state = state.copyWith(isConnecting: false, isOnlineFirebase: true);
      return joinedRoomId;
    } catch (error) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: 'مش قادرين ندخل القعدة: $error',
      );
      return null;
    }
  }

  void _subscribeToRoom(String roomId) {
    _cancelSubscriptions();
    _roomSub = bridge.watchRoom(roomId).listen(
      (snap) {
        if (!snap.exists || snap.data() == null) return;
        final room = RoomStateModel.fromMap(roomId, snap.data()!);
        state = state.copyWith(room: room);
      },
      onError: (Object err) {
        state = state.copyWith(errorMessage: ArEgStrings.connectionLost);
      },
    );

    _roundSub = bridge.watchPublicRound(roomId).listen((snap) {
      if (!snap.exists || snap.data() == null) {
        state = state.copyWith(clearPublicRound: true);
        return;
      }
      final pub = PublicRoundModel.fromMap(snap.data()!);
      final prevVersion = state.publicRound?.version;
      state = state.copyWith(publicRound: pub);
      if (prevVersion != null && pub.version != prevVersion) {
        if (pub.lastMovePairsRemoved > 0) {
          _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.pairMatched);
        } else {
          _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.cardDraw);
        }
        if (pub.status == 'playing' && pub.currentPlayerId == _profile.uid) {
          _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.yourTurn);
        }
      }
    });

    _handSub = bridge.watchOwnHand(roomId).listen((snap) {
      if (!snap.exists || snap.data() == null) {
        state = state.copyWith(ownHand: const []);
        return;
      }
      final rawCards = (snap.data()!['cards'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => PlayingCardModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      state = state.copyWith(ownHand: rawCards);
    });

    _chatSub = bridge.watchRoomMessages(roomId).listen((snap) {
      final msgs = snap.docs
          .where((d) => d.data() != null)
          .map((d) => ChatMessageModel.fromMap(d.data()!))
          .toList();
      state = state.copyWith(messages: msgs);
    });
  }

  /// Creates an explicit local café room with realistic Egyptian friends so the full
  /// 2–6 player loop can be tested offline or in automated widget tests.
  String _createLocalPracticeRoom({
    required String title,
    required int maxPlayers,
    required int totalRounds,
    required String direction,
    required String visibility,
    required String challengeMode,
    required int turnTimerSeconds,
  }) {
    _cancelSubscriptions();
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    final code = List.generate(6, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
    final roomId = 'local_room_${DateTime.now().millisecondsSinceEpoch}';

    const botPool = [
      (uid: 'bot_mahmoud', name: 'محمود الحريف', avatar: 'avatar_2'),
      (uid: 'bot_karim', name: 'كريم القهوجي', avatar: 'avatar_3'),
      (uid: 'bot_youssef', name: 'يوسف البرنس', avatar: 'avatar_5'),
      (uid: 'bot_salma', name: 'سلمى السلطانة', avatar: 'avatar_4'),
      (uid: 'bot_hassan', name: 'عم حسن', avatar: 'avatar_6'),
    ];

    final players = <RoomPlayerModel>[
      RoomPlayerModel(
        uid: _profile.uid,
        nickname: _profile.nickname,
        avatarId: _profile.avatarId,
        seat: 0,
        ready: true,
      ),
    ];

    for (var i = 0; i < maxPlayers - 1 && i < botPool.length; i++) {
      players.add(
        RoomPlayerModel(
          uid: botPool[i].uid,
          nickname: botPool[i].name,
          avatarId: botPool[i].avatar,
          seat: i + 1,
          ready: true,
        ),
      );
    }

    final scores = {for (final p in players) p.uid: 0};
    final losses = {for (final p in players) p.uid: 0};
    final firsts = {for (final p in players) p.uid: 0};

    final room = RoomStateModel(
      roomId: roomId,
      code: code,
      title: title.trim().isEmpty ? 'قعدة ${_profile.nickname}' : title.trim(),
      hostId: _profile.uid,
      visibility: visibility,
      maxPlayers: maxPlayers,
      totalRounds: totalRounds,
      direction: direction,
      challengeMode: challengeMode,
      turnTimerSeconds: turnTimerSeconds,
      status: 'waiting',
      roundNumber: 0,
      players: players,
      scores: scores,
      losses: losses,
      firstFinishes: firsts,
    );

    state = ActiveGameSessionState(
      isOnlineFirebase: false,
      isConnecting: false,
      room: room,
      messages: [
        ChatMessageModel(
          id: 'sys_welcome',
          senderUid: 'system',
          senderNickname: 'قهوة الشايب',
          senderAvatar: 'system',
          type: 'system',
          text: '${_profile.nickname} فتح القعدة! الشلة كلها جاهزة على الترابيزة ☕🃏',
        ),
      ],
    );
    return roomId;
  }

  Future<void> toggleReady() async {
    final room = state.room;
    if (room == null) return;
    final me = room.players.firstWhere(
      (p) => p.uid == _profile.uid,
      orElse: () => room.players.first,
    );
    final nextReady = !me.ready;
    await _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.buttonTap);

    if (state.isOnlineFirebase) {
      try {
        await bridge.setReady(room.roomId, nextReady);
      } catch (e) {
        state = state.copyWith(errorMessage: 'تعذر تحديث الجاهزية: $e');
      }
      return;
    }

    final updatedPlayers = room.players
        .map((p) => p.uid == me.uid
            ? RoomPlayerModel(
                uid: p.uid,
                nickname: p.nickname,
                avatarId: p.avatarId,
                seat: p.seat,
                ready: nextReady,
                isConnected: p.isConnected,
                temporaryTitle: p.temporaryTitle,
              )
            : p)
        .toList();

    state = state.copyWith(
      room: _copyRoom(room, players: updatedPlayers),
    );
  }

  Future<void> startMatch() async {
    final room = state.room;
    if (room == null) return;
    await _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.cardShuffle);

    if (state.isOnlineFirebase) {
      try {
        state = state.copyWith(isActionPending: true, clearError: true);
        await bridge.startMatch(room.roomId);
      } catch (e) {
        state = state.copyWith(errorMessage: 'مش قادرين نبدأ الجولة: $e');
      } finally {
        state = state.copyWith(isActionPending: false);
      }
      return;
    }

    _startLocalRound(roundNumber: 1);
  }

  void _startLocalRound({required int roundNumber}) {
    final room = state.room;
    if (room == null) return;
    _botTimer?.cancel();

    final playerOrder = room.players.map((p) => p.uid).toList();
    final shuffled = ShayebDartRulesEngine.shuffleDeck(ShayebDartRulesEngine.makeDeck());
    final rawHands = <String, List<PlayingCardModel>>{
      for (final pid in playerOrder) pid: <PlayingCardModel>[],
    };
    for (var i = 0; i < shuffled.length; i++) {
      rawHands[playerOrder[i % playerOrder.length]]!.add(shuffled[i]);
    }

    _localSecretHands = {};
    _localDiscarded = [];
    final finishOrder = <String>[];

    for (final pid in playerOrder) {
      final res = ShayebDartRulesEngine.resolvePairs(rawHands[pid]!);
      _localSecretHands[pid] = res.hand;
      _localDiscarded.addAll(res.discarded);
      if (res.hand.isEmpty) {
        finishOrder.add(pid);
      }
    }

    final active = playerOrder.where((pid) => _localSecretHands[pid]!.isNotEmpty).toList();
    final isFinished = active.length == 1;
    if (isFinished) {
      finishOrder.add(active.first);
    }

    final currentTurn = isFinished ? null : active.first;
    final drawTarget = currentTurn == null
        ? null
        : ShayebDartRulesEngine.nextActiveNeighbor(
            playerOrder: playerOrder,
            hands: _localSecretHands,
            fromPlayerId: currentTurn,
            direction: room.direction,
          );

    final pubRound = PublicRoundModel(
      id: 'round_$roundNumber',
      playerOrder: playerOrder,
      direction: room.direction,
      handCounts: {
        for (final pid in playerOrder) pid: _localSecretHands[pid]!.length,
      },
      finishOrder: finishOrder,
      currentPlayerId: currentTurn,
      drawTargetId: drawTarget,
      turnNumber: 0,
      version: 0,
      status: isFinished ? 'finished' : 'playing',
      loserId: isFinished ? active.first : null,
      discardCount: _localDiscarded.length,
      turnDeadlineMs: room.turnTimerSeconds > 0
          ? DateTime.now().millisecondsSinceEpoch + room.turnTimerSeconds * 1000
          : null,
    );

    final updatedRoom = _copyRoom(
      room,
      status: isFinished ? 'round_results' : 'playing',
      roundNumber: roundNumber,
      clearChallenge: true,
    );

    state = state.copyWith(
      room: updatedRoom,
      publicRound: pubRound,
      ownHand: List<PlayingCardModel>.from(_localSecretHands[_profile.uid] ?? const []),
      bannerNotification: 'الورق اتوزع والأجواز نزلت! استعد للسحب 🃏🔥',
      messages: [
        ...state.messages,
        ChatMessageModel(
          id: 'sys_round_$roundNumber',
          senderUid: 'system',
          senderNickname: 'قهوة الشايب',
          senderAvatar: 'system',
          type: 'system',
          text: 'بدأت الجولة $roundNumber من ${room.totalRounds}! ٤٩ ورقة اتوزعوا والأجواز اتشالت.',
        ),
      ],
    );

    _scheduleBotTurnIfNeeded();
  }

  /// Draws a card from the legal target opponent.
  Future<void> drawCardFromTarget(int cardIndex) async {
    final room = state.room;
    final pub = state.publicRound;
    if (room == null || pub == null || state.isActionPending) return;
    if (pub.status != 'playing' || pub.currentPlayerId != _profile.uid) return;

    if (state.isOnlineFirebase) {
      state = state.copyWith(isActionPending: true, clearError: true);
      try {
        await bridge.drawCard(
          roomId: room.roomId,
          cardIndex: cardIndex,
          expectedVersion: pub.version,
        );
      } catch (e) {
        state = state.copyWith(errorMessage: 'السحبة ما ظبطتش: $e');
      } finally {
        state = state.copyWith(isActionPending: false);
      }
      return;
    }

    _executeLocalDraw(actorId: _profile.uid, cardIndex: cardIndex);
  }

  void _executeLocalDraw({required String actorId, required int cardIndex}) {
    final room = state.room;
    final pub = state.publicRound;
    if (room == null || pub == null || pub.status != 'playing') return;
    if (pub.currentPlayerId != actorId) return;

    final targetId = ShayebDartRulesEngine.nextActiveNeighbor(
      playerOrder: pub.playerOrder,
      hands: _localSecretHands,
      fromPlayerId: actorId,
      direction: pub.direction,
    );
    if (targetId == null) return;

    final targetHand = List<PlayingCardModel>.from(_localSecretHands[targetId]!);
    if (cardIndex < 0 || cardIndex >= targetHand.length) return;

    final drawnCard = targetHand.removeAt(cardIndex);
    final actorHand = [..._localSecretHands[actorId]!, drawnCard];
    final resolved = ShayebDartRulesEngine.resolvePairs(actorHand);

    _localSecretHands[targetId] = targetHand;
    _localSecretHands[actorId] = resolved.hand;
    _localDiscarded.addAll(resolved.discarded);

    final finishOrder = List<String>.from(pub.finishOrder);
    final newlyFinished = <String>[];
    for (final pid in [targetId, actorId]) {
      if (_localSecretHands[pid]!.isEmpty && !finishOrder.contains(pid)) {
        finishOrder.add(pid);
        newlyFinished.add(pid);
      }
    }

    final active = pub.playerOrder.where((pid) => _localSecretHands[pid]!.isNotEmpty).toList();
    final isFinished = active.length == 1;
    final loserId = isFinished ? active.first : null;
    if (loserId != null && !finishOrder.contains(loserId)) {
      finishOrder.add(loserId);
    }

    final nextTurn = isFinished
        ? null
        : ShayebDartRulesEngine.nextActiveNeighbor(
            playerOrder: pub.playerOrder,
            hands: _localSecretHands,
            fromPlayerId: actorId,
            direction: pub.direction,
          );
    final nextTarget = nextTurn == null
        ? null
        : ShayebDartRulesEngine.nextActiveNeighbor(
            playerOrder: pub.playerOrder,
            hands: _localSecretHands,
            fromPlayerId: nextTurn,
            direction: pub.direction,
          );

    final nextPub = PublicRoundModel(
      id: pub.id,
      playerOrder: pub.playerOrder,
      direction: pub.direction,
      handCounts: {
        for (final pid in pub.playerOrder) pid: _localSecretHands[pid]!.length,
      },
      finishOrder: finishOrder,
      currentPlayerId: nextTurn,
      drawTargetId: nextTarget,
      turnNumber: pub.turnNumber + 1,
      version: pub.version + 1,
      status: isFinished ? 'finished' : 'playing',
      loserId: loserId,
      discardCount: _localDiscarded.length,
      turnDeadlineMs: isFinished || room.turnTimerSeconds <= 0
          ? null
          : DateTime.now().millisecondsSinceEpoch + room.turnTimerSeconds * 1000,
      lastMovePairsRemoved: resolved.pairCount,
      lastMoveActorId: actorId,
      lastMoveTargetId: targetId,
    );

    final newMessages = List<ChatMessageModel>.from(state.messages);
    final actorName = room.nicknameOf(actorId);
    final targetName = room.nicknameOf(targetId);

    String? banner;
    if (resolved.pairCount > 0) {
      _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.pairMatched);
      banner = actorId == _profile.uid
          ? ArEgStrings.pairRemoved
          : '$actorName سحب من $targetName ونزل جوز 🎯';
      newMessages.add(
        ChatMessageModel(
          id: 'sys_pair_${nextPub.version}',
          senderUid: 'system',
          senderNickname: 'قهوة الشايب',
          senderAvatar: 'system',
          type: 'system',
          text: '$actorName سحب من $targetName ونزل جوز 🎯',
        ),
      );
    } else {
      _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.cardDraw);
      if (actorId == _profile.uid && drawnCard.isElShayeb) {
        _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.kingReveal);
        banner = ArEgStrings.holdingShayebWarning;
      }
    }

    for (final escapedId in newlyFinished) {
      _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.opponentEscaped);
      final escapedName = room.nicknameOf(escapedId);
      newMessages.add(
        ChatMessageModel(
          id: 'sys_esc_${nextPub.version}_$escapedId',
          senderUid: 'system',
          senderNickname: 'قهوة الشايب',
          senderAvatar: 'system',
          type: 'system',
          text: '$escapedName صفّى ورقه وفلت من الشايب! 🏃‍♂️✨',
        ),
      );
    }

    var updatedRoom = room;
    if (isFinished && loserId != null) {
      _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.roundLost);
      final pts = ShayebDartRulesEngine.roundPoints(finishOrder);
      final newScores = Map<String, int>.from(room.scores);
      final newLosses = Map<String, int>.from(room.losses);
      final newFirsts = Map<String, int>.from(room.firstFinishes);

      for (final p in room.players) {
        newScores[p.uid] = (newScores[p.uid] ?? 0) + (pts[p.uid] ?? 0);
      }
      newLosses[loserId] = (newLosses[loserId] ?? 0) + 1;
      if (finishOrder.isNotEmpty) {
        final firstUid = finishOrder.first;
        newFirsts[firstUid] = (newFirsts[firstUid] ?? 0) + 1;
      }

      final isMatchOver = room.roundNumber >= room.totalRounds;
      final shouldChallenge = room.challengeMode == 'every_round' ||
          (room.challengeMode == 'end_of_match' && isMatchOver);

      ActiveChallengeModel? assignedChallenge;
      if (shouldChallenge) {
        final candidates = kEgyptianChallengesCatalog
            .where((c) => !_localUsedChallenges.contains(c.id))
            .toList();
        final pool = candidates.isNotEmpty ? candidates : kEgyptianChallengesCatalog;
        final picked = pool[Random().nextInt(pool.length)];
        _localUsedChallenges.add(picked.id);
        assignedChallenge = ActiveChallengeModel(
          instanceId: 'ch_round_${room.roundNumber}',
          roundNumber: room.roundNumber,
          loserUid: loserId,
          loserNickname: room.nicknameOf(loserId),
          challenge: picked,
          status: 'pending',
          redrawCount: 0,
        );
      }

      final loserName = room.nicknameOf(loserId);
      banner = 'الشايب لبس في $loserName! 👴👑';
      newMessages.add(
        ChatMessageModel(
          id: 'sys_end_${room.roundNumber}',
          senderUid: 'system',
          senderNickname: 'قهوة الشايب',
          senderAvatar: 'system',
          type: 'system',
          text:
              'الشايب لبس في $loserName! 👴👑 ${assignedChallenge != null ? "والحكم عليه: «${assignedChallenge.challenge.title}»" : ""}',
        ),
      );

      updatedRoom = _copyRoom(
        room,
        status: isMatchOver ? 'finished' : 'round_results',
        scores: newScores,
        losses: newLosses,
        firstFinishes: newFirsts,
        activeChallenge: assignedChallenge,
      );
    }

    state = state.copyWith(
      room: updatedRoom,
      publicRound: nextPub,
      ownHand: List<PlayingCardModel>.from(_localSecretHands[_profile.uid] ?? const []),
      messages: newMessages,
      bannerNotification: banner,
    );

    _scheduleBotTurnIfNeeded();
  }

  void _scheduleBotTurnIfNeeded() {
    _botTimer?.cancel();
    if (state.isOnlineFirebase) return;
    final pub = state.publicRound;
    if (pub == null || pub.status != 'playing') return;
    final activeId = pub.currentPlayerId;
    if (activeId == null || activeId == _profile.uid) return;

    _botTimer = Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      final currentPub = state.publicRound;
      if (currentPub == null ||
          currentPub.status != 'playing' ||
          currentPub.currentPlayerId != activeId) {
        return;
      }
      final targetId = currentPub.drawTargetId;
      if (targetId == null) return;
      final targetCount = currentPub.handCounts[targetId] ?? 0;
      if (targetCount <= 0) return;
      final randomIndex = Random().nextInt(targetCount);
      _executeLocalDraw(actorId: activeId, cardIndex: randomIndex);
    });
  }

  /// Safe local sorting or shuffling of the player's own visual hand display.
  void reorderOwnHand({required bool sortByRank}) {
    final hand = List<PlayingCardModel>.from(state.ownHand);
    if (sortByRank) {
      hand.sort((a, b) =>
          ShayebDartRulesEngine.ranks.indexOf(a.rank) -
          ShayebDartRulesEngine.ranks.indexOf(b.rank));
    } else {
      hand.shuffle();
    }
    _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.buttonTap);
    state = state.copyWith(ownHand: hand);
  }

  static String inferImageMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Uploads an image (<= 2 MB) to private Supabase Storage and returns its durable mediaId.
  Future<String?> uploadRoomImage({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    String? challengeInstanceId,
  }) async {
    final room = state.room;
    if (room == null || !state.isOnlineFirebase) return null;
    if (bytes.isEmpty || bytes.length > 2097152) {
      state = state.copyWith(errorMessage: 'حجم الصورة لازم يكون أقل من ٢ ميجابايت');
      return null;
    }
    final resolvedMime = contentType ?? inferImageMimeType(fileName);
    try {
      return await bridge.uploadChallengeEvidence(
        roomId: room.roomId,
        challengeInstanceId: challengeInstanceId ?? '',
        bytes: bytes,
        fileName: fileName,
        contentType: resolvedMime,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'تعذر رفع الصورة: $e');
      return null;
    }
  }

  Future<void> handleChallengeAction({
    required String action, // 'complete' | 'skip' | 'redraw'
    String? proofText,
    String? proofMediaId,
  }) async {
    final room = state.room;
    final current = room?.activeChallenge;
    if (room == null || current == null) return;
    await _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.challengeReveal);

    if (state.isOnlineFirebase) {
      try {
        await bridge.handleChallengeAction(
          roomId: room.roomId,
          action: action,
          proofText: proofText,
          proofMediaId: proofMediaId,
        );
      } catch (e) {
        state = state.copyWith(errorMessage: 'مش قادرين نحدث الحكم: $e');
      }
      return;
    }

    if (action == 'redraw') {
      if (current.redrawCount >= 2) {
        state = state.copyWith(
          errorMessage: 'استنفذت محاولات تغيير الحكم في الجولة دي!',
        );
        return;
      }
      final candidates = kEgyptianChallengesCatalog
          .where((c) => c.id != current.challenge.id)
          .toList();
      final picked = candidates[Random().nextInt(candidates.length)];
      final updatedChallenge = ActiveChallengeModel(
        instanceId: current.instanceId,
        roundNumber: current.roundNumber,
        loserUid: current.loserUid,
        loserNickname: current.loserNickname,
        challenge: picked,
        status: 'pending',
        redrawCount: current.redrawCount + 1,
      );
      state = state.copyWith(
        room: _copyRoom(room, activeChallenge: updatedChallenge),
      );
      return;
    }

    final updatedChallenge = ActiveChallengeModel(
      instanceId: current.instanceId,
      roundNumber: current.roundNumber,
      loserUid: current.loserUid,
      loserNickname: current.loserNickname,
      challenge: current.challenge,
      status: action == 'complete' ? 'completed' : 'skipped',
      redrawCount: current.redrawCount,
      proofText: proofText,
    );

    final msgText = action == 'complete'
        ? '${current.loserNickname} نفّذ الحكم «${current.challenge.title}» برجولة! 👏🔥${proofText != null && proofText.trim().isNotEmpty ? "\n💬 «${proofText.trim()}»" : ""}'
        : '${current.loserNickname} عدّى الحكم المرة دي 😅';

    state = state.copyWith(
      room: _copyRoom(room, activeChallenge: updatedChallenge),
      messages: [
        ...state.messages,
        ChatMessageModel(
          id: 'sys_ch_${DateTime.now().millisecondsSinceEpoch}',
          senderUid: 'system',
          senderNickname: 'قهوة الشايب',
          senderAvatar: 'system',
          type: 'system',
          text: msgText,
        ),
      ],
    );
  }

  Future<void> startNextRound() async {
    final room = state.room;
    if (room == null) return;
    await _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.cardShuffle);

    if (state.isOnlineFirebase) {
      try {
        await bridge.startNextRound(room.roomId);
      } catch (e) {
        state = state.copyWith(errorMessage: 'تعذر بدء الجولة الجديدة: $e');
      }
      return;
    }

    if (room.roundNumber < room.totalRounds) {
      _startLocalRound(roundNumber: room.roundNumber + 1);
    }
  }

  Future<void> rematch() async {
    final room = state.room;
    if (room == null) return;
    await _ref.read(soundServiceProvider).trigger(ShayebSoundEvent.buttonTap);

    if (state.isOnlineFirebase) {
      try {
        await bridge.rematchRoom(room.roomId);
      } catch (e) {
        state = state.copyWith(errorMessage: 'تعذر إعادة الماتش: $e');
      }
      return;
    }

    final zeroMap = {for (final p in room.players) p.uid: 0};
    state = state.copyWith(
      room: _copyRoom(
        room,
        status: 'waiting',
        roundNumber: 0,
        scores: zeroMap,
        losses: Map<String, int>.from(zeroMap),
        firstFinishes: Map<String, int>.from(zeroMap),
        clearChallenge: true,
      ),
    );
  }

  Future<void> sendChatMessage(String text, {String type = 'user'}) async {
    final room = state.room;
    if (room == null) return;
    final cleaned = text.replaceAll(RegExp(r'[<>]'), '').trim();
    if (cleaned.isEmpty) return;

    if (type == 'reaction') {
      final reactions = Map<String, String>.from(state.activeReactions);
      reactions[_profile.uid] = cleaned;
      state = state.copyWith(activeReactions: reactions);
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        final next = Map<String, String>.from(state.activeReactions);
        next.remove(_profile.uid);
        state = state.copyWith(activeReactions: next);
      });
    }

    if (state.isOnlineFirebase) {
      try {
        await bridge.sendChatMessage(
          roomId: room.roomId,
          senderNickname: _profile.nickname,
          senderAvatar: _profile.avatarId,
          text: cleaned,
          type: type,
        );
      } catch (error) {
        state = state.copyWith(errorMessage: 'الرسالة ما اتبعتتش: $error');
      }
      return;
    }

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessageModel(
          id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
          senderUid: _profile.uid,
          senderNickname: _profile.nickname,
          senderAvatar: _profile.avatarId,
          type: type,
          text: cleaned,
        ),
      ],
    );
  }

  Future<void> leaveCurrentRoom() async {
    _botTimer?.cancel();
    final room = state.room;
    if (room != null && state.isOnlineFirebase) {
      try {
        await bridge.leaveRoom(room.roomId);
      } catch (_) {}
    }
    _cancelSubscriptions();
    state = const ActiveGameSessionState();
  }

  RoomStateModel _copyRoom(
    RoomStateModel r, {
    String? status,
    int? roundNumber,
    List<RoomPlayerModel>? players,
    Map<String, int>? scores,
    Map<String, int>? losses,
    Map<String, int>? firstFinishes,
    ActiveChallengeModel? activeChallenge,
    bool clearChallenge = false,
  }) {
    return RoomStateModel(
      roomId: r.roomId,
      code: r.code,
      title: r.title,
      hostId: r.hostId,
      visibility: r.visibility,
      maxPlayers: r.maxPlayers,
      totalRounds: r.totalRounds,
      direction: r.direction,
      challengeMode: r.challengeMode,
      turnTimerSeconds: r.turnTimerSeconds,
      status: status ?? r.status,
      roundNumber: roundNumber ?? r.roundNumber,
      players: players ?? r.players,
      scores: scores ?? r.scores,
      losses: losses ?? r.losses,
      firstFinishes: firstFinishes ?? r.firstFinishes,
      activeChallenge: clearChallenge ? null : (activeChallenge ?? r.activeChallenge),
    );
  }

  void _cancelSubscriptions() {
    _roomSub?.cancel();
    _roundSub?.cancel();
    _handSub?.cancel();
    _chatSub?.cancel();
    _roomSub = null;
    _roundSub = null;
    _handSub = null;
    _chatSub = null;
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _cancelSubscriptions();
    super.dispose();
  }
}
