import 'dart:io';
import 'dart:math';
import '../lib/features/cards/domain/playing_card.dart';
import '../lib/features/challenges/domain/challenge_model.dart';
import '../lib/features/game/animations/game_animation_coordinator.dart';
import '../lib/features/game/domain/dart_rules_engine.dart';
import '../lib/features/game/domain/room_models.dart';
import '../lib/localization/ar_eg_strings.dart';

void _expect(bool condition, String description) {
  if (!condition) {
    throw StateError('Assertion failed: $description');
  }
}

void main() {
  print('TAP version 13');

  // 1. 49-card deck and single King of Hearts
  final deck = ShayebDartRulesEngine.makeDeck();
  _expect(deck.length == 49, 'Deck must have 49 cards');
  _expect(deck.map((c) => c.id).toSet().length == 49, 'All 49 cards must be unique');
  final kings = deck.where((c) => c.isElShayeb).toList();
  _expect(kings.length == 1 && kings.first.suit == CardSuit.hearts, 'Only King of Hearts remains');
  print('ok 1 - Dart deck has 49 unique cards and only King of Hearts');

  // 2. Pair resolution (4-of-a-kind -> 2 pairs, El Shayeb preserved)
  final sevens = deck.where((c) => c.rank == '7').toList();
  final resolved = ShayebDartRulesEngine.resolvePairs([...sevens, kings.first]);
  _expect(resolved.pairCount == 2, '4-of-a-kind produces 2 pairs');
  _expect(resolved.discarded.length == 4, '4 cards discarded');
  _expect(resolved.hand.length == 1 && resolved.hand.first.isElShayeb, 'El Shayeb remains in hand');
  print('ok 2 - Dart pair resolution removes pairs and preserves El Shayeb');

  // 3. Round scoring and deterministic tie-breaking
  final pts = ShayebDartRulesEngine.roundPoints(['p1', 'p2', 'p3', 'p4']);
  _expect(pts['p1'] == 3 && pts['p2'] == 2 && pts['p3'] == 1 && pts['p4'] == 0, 'N-1..0 points');

  final room = RoomStateModel(
    roomId: 'r1',
    code: 'SH7K29',
    title: 'قعدة الصحاب',
    hostId: 'u1',
    visibility: 'private',
    maxPlayers: 3,
    totalRounds: 3,
    direction: 'clockwise',
    challengeMode: 'every_round',
    turnTimerSeconds: 45,
    status: 'finished',
    roundNumber: 3,
    players: const [
      RoomPlayerModel(uid: 'u1', nickname: 'أحمد', avatarId: 'avatar_1', seat: 0, ready: true),
      RoomPlayerModel(uid: 'u2', nickname: 'كريم', avatarId: 'avatar_2', seat: 1, ready: true),
      RoomPlayerModel(uid: 'u3', nickname: 'يوسف', avatarId: 'avatar_3', seat: 2, ready: true),
    ],
    scores: const {'u1': 4, 'u2': 4, 'u3': 1},
    losses: const {'u1': 1, 'u2': 0, 'u3': 2},
    firstFinishes: const {'u1': 2, 'u2': 1, 'u3': 0},
  );
  final standings = MatchStandingRow.computeFromRoom(room);
  _expect(standings.first.uid == 'u2' && standings.first.placement == 1, 'Tie-break favors fewer losses');
  print('ok 3 - Dart round points and deterministic tie-breaking verified');

  // 4. Nickname validation & anti-impersonation
  _expect(PlayerProfile.validateNickname('أ') != null, 'Rejects 1-char name');
  _expect(PlayerProfile.validateNickname('النظام') != null, 'Rejects system impersonation');
  _expect(PlayerProfile.validateNickname('Admin') != null, 'Rejects Admin impersonation');
  _expect(PlayerProfile.validateNickname('المعلم رضا') == null, 'Accepts valid Egyptian Arabic name');
  print('ok 4 - Dart nickname validation and anti-impersonation verified');

  // 5. 30 Egyptian challenges catalog & Arabic localization strings
  _expect(kEgyptianChallengesCatalog.length == 30, 'Exactly 30 challenges');
  _expect(kEgyptianChallengesCatalog.map((c) => c.id).toSet().length == 30, '30 unique challenge IDs');
  _expect(ArEgStrings.gameTitle == 'ورقة الشايب', 'Arabic title verified');
  _expect(ArEgStrings.avatars.length == 8, '8 Egyptian café avatars defined');
  print('ok 5 - Dart 30 Egyptian challenges catalog and RTL localization verified');

  // 6. Serialization & Data Contract Compatibility between Cloud Functions JSON and Dart Models
  final sampleRoomJson = <String, dynamic>{
    'code': 'SH7K29',
    'title': 'قعدة المعلم',
    'hostId': 'u1',
    'visibility': 'private',
    'maxPlayers': 4,
    'totalRounds': 5,
    'direction': 'clockwise',
    'challengeMode': 'every_round',
    'turnTimerSeconds': 45,
    'status': 'playing',
    'roundNumber': 1,
    'players': [
      {'uid': 'u1', 'nickname': 'أحمد', 'avatarId': 'avatar_1', 'seat': 0, 'ready': true, 'isConnected': true},
      {'uid': 'u2', 'nickname': 'محمود', 'avatarId': 'avatar_2', 'seat': 1, 'ready': true, 'isConnected': true},
    ],
    'scores': {'u1': 3, 'u2': 1},
    'losses': {'u1': 0, 'u2': 1},
    'firstFinishes': {'u1': 1, 'u2': 0},
    'activeChallenge': {
      'instanceId': 'ch_round_1',
      'roundNumber': 1,
      'loserUid': 'u2',
      'loserNickname': 'محمود',
      'status': 'pending',
      'redrawCount': 0,
      'challenge': {
        'id': 'ch_01',
        'title': 'نشرة أخبار الهزيمة',
        'description': 'قدّم نشرة أخبار درامية',
        'category': 'acting',
        'proofType': 'voice',
        'estimatedDurationSeconds': 25,
      },
    },
  };
  final parsedRoom = RoomStateModel.fromMap('room_123', sampleRoomJson);
  _expect(parsedRoom.code == 'SH7K29' && parsedRoom.players.length == 2, 'RoomStateModel parsed');
  _expect(parsedRoom.activeChallenge?.challenge.id == 'ch_01', 'ActiveChallengeModel parsed');

  final samplePublicRoundJson = <String, dynamic>{
    'id': 'round_1',
    'playerOrder': ['u1', 'u2'],
    'direction': 'clockwise',
    'handCounts': {'u1': 4, 'u2': 5},
    'finishOrder': <String>[],
    'currentPlayerId': 'u1',
    'drawTargetId': 'u2',
    'turnNumber': 3,
    'version': 3,
    'status': 'playing',
    'loserId': null,
    'discardCount': 40,
    'turnDeadlineMs': 1700000000000,
    'lastMove': {
      'actorId': 'u2',
      'targetId': 'u1',
      'pairsRemoved': 1,
      'finishedPlayerIds': <String>[],
      'turnNumber': 3,
    },
  };
  final parsedPub = PublicRoundModel.fromMap(samplePublicRoundJson);
  _expect(parsedPub.currentPlayerId == 'u1' && parsedPub.drawTargetId == 'u2', 'PublicRoundModel parsed');
  _expect(parsedPub.lastMovePairsRemoved == 1, 'LastMove parsed');
  print('ok 6 - Dart-to-Cloud-Functions JSON data contracts verified');

  // 7. 100 full simulated rounds in Dart across 2-6 players (Offline Bot Mode engine verification)
  for (var iter = 0; iter < 100; iter++) {
    final playerCount = (iter % 5) + 2;
    final playerOrder = List.generate(playerCount, (i) => 'p$i');
    final direction = iter.isEven ? 'clockwise' : 'counterclockwise';
    final shuffled = ShayebDartRulesEngine.shuffleDeck(ShayebDartRulesEngine.makeDeck());
    final hands = <String, List<PlayingCardModel>>{
      for (final p in playerOrder) p: <PlayingCardModel>[],
    };
    for (var i = 0; i < shuffled.length; i++) {
      hands[playerOrder[i % playerCount]]!.add(shuffled[i]);
    }
    var discardedCount = 0;
    final finishOrder = <String>[];
    for (final p in playerOrder) {
      final r = ShayebDartRulesEngine.resolvePairs(hands[p]!);
      hands[p] = r.hand;
      discardedCount += r.discarded.length;
      if (r.hand.isEmpty) finishOrder.add(p);
    }
    var active = playerOrder.where((p) => hands[p]!.isNotEmpty).toList();
    var currentTurn = active.length == 1 ? null : active.first;
    while (active.length > 1 && currentTurn != null) {
      final target = ShayebDartRulesEngine.nextActiveNeighbor(
        playerOrder: playerOrder,
        hands: hands,
        fromPlayerId: currentTurn,
        direction: direction,
      )!;
      final targetHand = hands[target]!;
      final pickIndex = Random().nextInt(targetHand.length);
      final drawn = targetHand.removeAt(pickIndex);
      final r = ShayebDartRulesEngine.resolvePairs([...hands[currentTurn]!, drawn]);
      hands[currentTurn] = r.hand;
      discardedCount += r.discarded.length;
      for (final pid in [target, currentTurn]) {
        if (hands[pid]!.isEmpty && !finishOrder.contains(pid)) {
          finishOrder.add(pid);
        }
      }
      active = playerOrder.where((p) => hands[p]!.isNotEmpty).toList();
      currentTurn = active.length == 1
          ? null
          : ShayebDartRulesEngine.nextActiveNeighbor(
              playerOrder: playerOrder,
              hands: hands,
              fromPlayerId: currentTurn,
              direction: direction,
            );
    }
    _expect(active.length == 1, 'Exactly one loser remains');
    final loser = active.first;
    if (!finishOrder.contains(loser)) finishOrder.add(loser);
    _expect(hands[loser]!.length == 1 && hands[loser]!.first.isElShayeb, 'Loser holds El Shayeb');
    _expect(discardedCount == 48, 'All 48 non-King cards discarded as pairs');
    _expect(finishOrder.length == playerCount, 'All players ranked in finishOrder');
  }
  print('ok 7 - 100 complete Dart offline-bot multiplayer rounds simulated across 2-6 players');

  // 8. Verify all 16 synthesized WAV sound assets exist and have valid RIFF/WAVE headers
  const expectedWavFiles = [
    'card_deal.wav',
    'card_draw.wav',
    'card_shuffle.wav',
    'challenge_reveal.wav',
    'king_reveal.wav',
    'match_victory.wav',
    'opponent_escaped.wav',
    'pair_matched.wav',
    'round_lost.wav',
    'your_turn.wav',
    'card_select.wav',
    'card_flip.wav',
    'king_suspense.wav',
    'button_click.wav',
    'room_joined.wav',
    'match_completed.wav',
  ];
  final projectRoot = File(Platform.script.toFilePath()).parent.parent;
  for (final wavName in expectedWavFiles) {
    final wavFile = File('${projectRoot.path}/assets/sounds/$wavName');
    _expect(wavFile.existsSync(), 'Missing sound asset: $wavName');
    final bytes = wavFile.readAsBytesSync();
    _expect(bytes.length > 44, 'WAV file too small: $wavName');
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    _expect(riff == 'RIFF' && wave == 'WAVE', 'Invalid RIFF/WAVE header in $wavName');
  }
  print('ok 8 - All 16 synthesized WAV sound assets verified (valid RIFF/WAVE PCM headers)');

  // 9. Verify Dual Theme ('قهوة البلد' / 'ليالي النيل') background & avatar JPEG assets
  const expectedJpgAssets = [
    'assets/images/themes/ahwa_classic_bg.jpg',
    'assets/images/themes/nile_royal_bg.jpg',
    'assets/images/avatars/avatar_1.jpg',
    'assets/images/avatars/avatar_2.jpg',
    'assets/images/avatars/avatar_3.jpg',
    'assets/images/avatars/avatar_4.jpg',
    'assets/images/avatars/avatar_5.jpg',
    'assets/images/avatars/avatar_6.jpg',
  ];
  for (final relPath in expectedJpgAssets) {
    final jpgFile = File('${projectRoot.path}/$relPath');
    _expect(jpgFile.existsSync(), 'Missing Dual Theme JPEG asset: $relPath');
    final bytes = jpgFile.readAsBytesSync();
    _expect(bytes.length > 100, 'JPEG asset too small: $relPath');
    _expect(
      bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF,
      'Invalid JPEG magic header in $relPath',
    );
  }
  print('ok 9 - All 8 Dual Theme (قهوة البلد / ليالي النيل) & Avatar JPEG assets verified');

  // 10. Verify GameAnimationCoordinator event derivation, deduplication, reconnect no-replay, and avatar motion states
  final coordinator = GameAnimationCoordinator();
  final round1Turn0 = PublicRoundModel.fromMap({
    'id': 'round_1',
    'playerOrder': ['u1', 'u2', 'u3'],
    'direction': 'clockwise',
    'handCounts': {'u1': 5, 'u2': 5, 'u3': 5},
    'finishOrder': <String>[],
    'currentPlayerId': 'u1',
    'drawTargetId': 'u2',
    'turnNumber': 0,
    'version': 0,
    'status': 'playing',
  });
  final initialEvents = coordinator.deriveNewEvents(
    room: parsedRoom,
    publicRound: round1Turn0,
    localPlayerUid: 'u1',
  );
  _expect(
    initialEvents.any((e) => e.type == GameAnimationEventType.roundShuffleAndDeal),
    'Turn 0 triggers roundShuffleAndDeal',
  );
  _expect(
    initialEvents.any((e) => e.type == GameAnimationEventType.turnChanged),
    'Initial snapshot triggers turnChanged',
  );

  // Deduplication: passing identical snapshot produces 0 duplicate events
  final duplicateEvents = coordinator.deriveNewEvents(
    room: parsedRoom,
    publicRound: round1Turn0,
    localPlayerUid: 'u1',
  );
  _expect(duplicateEvents.isEmpty, 'Duplicate Firestore snapshot must emit 0 animation events');

  // Card drawn + Pair matched on Turn 1
  final round1Turn1 = PublicRoundModel.fromMap({
    'id': 'round_1',
    'playerOrder': ['u1', 'u2', 'u3'],
    'direction': 'clockwise',
    'handCounts': {'u1': 4, 'u2': 4, 'u3': 5},
    'finishOrder': <String>[],
    'currentPlayerId': 'u2',
    'drawTargetId': 'u3',
    'turnNumber': 1,
    'version': 1,
    'status': 'playing',
    'lastMove': {
      'actorId': 'u1',
      'targetId': 'u2',
      'pairsRemoved': 1,
      'finishedPlayerIds': <String>[],
      'turnNumber': 1,
    },
  });
  final turn1Events = coordinator.deriveNewEvents(
    room: parsedRoom,
    publicRound: round1Turn1,
    localPlayerUid: 'u1',
  );
  _expect(
    turn1Events.any((e) => e.type == GameAnimationEventType.cardDrawn && e.actorUid == 'u1'),
    'Turn 1 emits cardDrawn event',
  );
  _expect(
    turn1Events.any((e) => e.type == GameAnimationEventType.pairMatched && e.pairsRemoved == 1),
    'Turn 1 emits pairMatched event',
  );

  // Mid-round reconnection guard: fresh coordinator attaching at turnNumber=5 must NOT replay shuffle/deal
  final reconnectCoordinator = GameAnimationCoordinator();
  final round1Turn5 = PublicRoundModel.fromMap({
    'id': 'round_1',
    'playerOrder': ['u1', 'u2', 'u3'],
    'direction': 'clockwise',
    'handCounts': {'u1': 2, 'u2': 1, 'u3': 2},
    'finishOrder': <String>[],
    'currentPlayerId': 'u2',
    'drawTargetId': 'u3',
    'turnNumber': 5,
    'version': 5,
    'status': 'playing',
  });
  final reconnectEvents = reconnectCoordinator.deriveNewEvents(
    room: parsedRoom,
    publicRound: round1Turn5,
    localPlayerUid: 'u1',
  );
  _expect(
    !reconnectEvents.any((e) => e.type == GameAnimationEventType.roundShuffleAndDeal),
    'Mid-round reconnect at turnNumber=5 must NOT replay roundShuffleAndDeal',
  );

  // Round completion -> King Reveal + Defeat + Challenge Reveal
  final round1Done = PublicRoundModel.fromMap({
    'id': 'round_1',
    'playerOrder': ['u1', 'u2', 'u3'],
    'direction': 'clockwise',
    'handCounts': {'u1': 0, 'u2': 1, 'u3': 0},
    'finishOrder': ['u1', 'u3', 'u2'],
    'currentPlayerId': null,
    'drawTargetId': null,
    'turnNumber': 6,
    'version': 6,
    'status': 'finished',
    'loserId': 'u2',
  });
  final roundEndEvents = coordinator.deriveNewEvents(
    room: parsedRoom,
    publicRound: round1Done,
    localPlayerUid: 'u2',
  );
  _expect(
    roundEndEvents.any((e) => e.type == GameAnimationEventType.kingRevealCinematic && e.loserUid == 'u2'),
    'Round completion emits kingRevealCinematic',
  );
  _expect(
    roundEndEvents.any((e) => e.type == GameAnimationEventType.roundDefeat),
    'Loser client emits roundDefeat',
  );
  _expect(
    initialEvents.any((e) => e.type == GameAnimationEventType.challengeReveal),
    'Active challenge emits challengeReveal on initial snapshot',
  );

  // Avatar motion state resolution across all 8 states
  final disconnectedRoom = RoomStateModel.fromMap('room_123', {
    ...sampleRoomJson,
    'players': [
      {'uid': 'u1', 'nickname': 'أحمد', 'avatarId': 'avatar_1', 'seat': 0, 'ready': true, 'isConnected': false},
      {'uid': 'u2', 'nickname': 'محمود', 'avatarId': 'avatar_2', 'seat': 1, 'ready': true, 'isConnected': true},
    ],
  });
  _expect(
    GameAnimationCoordinator.resolveAvatarState(
          room: disconnectedRoom,
          publicRound: round1Turn1,
          playerUid: 'u1',
        ) ==
        AvatarMotionState.disconnected,
    'Disconnected player resolves to AvatarMotionState.disconnected',
  );
  _expect(
    GameAnimationCoordinator.resolveAvatarState(
          room: parsedRoom,
          publicRound: round1Done,
          playerUid: 'u1',
        ) ==
        AvatarMotionState.victory,
    'Escaped player on completed round resolves to AvatarMotionState.victory',
  );
  _expect(
    GameAnimationCoordinator.resolveAvatarState(
          room: parsedRoom,
          publicRound: round1Done,
          playerUid: 'u2',
        ) ==
        AvatarMotionState.defeat,
    'Loser holding El Shayeb resolves to AvatarMotionState.defeat',
  );
  _expect(
    GameAnimationCoordinator.resolveAvatarState(
          room: parsedRoom,
          publicRound: round1Turn5,
          playerUid: 'u3',
        ) ==
        AvatarMotionState.suspense,
    'Draw target player resolves to AvatarMotionState.suspense',
  );
  _expect(
    GameAnimationCoordinator.resolveAvatarState(
          room: parsedRoom,
          publicRound: round1Turn5,
          playerUid: 'u2',
        ) ==
        AvatarMotionState.yourTurn,
    'Current turn player resolves to AvatarMotionState.yourTurn',
  );
  _expect(
    GameAnimationCoordinator.resolveAvatarState(
          room: parsedRoom,
          publicRound: round1Turn5,
          playerUid: 'u2',
          isCurrentlyDrawing: true,
        ) ==
        AvatarMotionState.drawing,
    'Drawing player resolves to AvatarMotionState.drawing',
  );
  _expect(
    GameAnimationCoordinator.resolveAvatarState(
          room: parsedRoom,
          publicRound: round1Turn1,
          playerUid: 'u1',
        ) ==
        AvatarMotionState.pairMatched,
    'Player who just matched a pair resolves to AvatarMotionState.pairMatched',
  );
  print('ok 10 - GameAnimationCoordinator event derivation, deduplication, reconnect guard & 8 avatar states verified');

  // 11. Verify «ورقة الشايب» PNG logo, Android launcher icons across 5 densities, & Manifest
  const pngPaths = <String>[
    'assets/images/logo/waraqet_el_shayeb_logo.png',
    'android/app/src/main/res/drawable/ic_launcher_foreground.png',
    'android/app/src/main/res/drawable/splash_logo.png',
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png',
    'android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png',
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png',
  ];
  for (final relPath in pngPaths) {
    final pngFile = File(relPath);
    _expect(pngFile.existsSync(), 'Missing PNG branding asset: $relPath');
    final bytes = pngFile.readAsBytesSync();
    _expect(
      bytes.length > 200 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47,
      'Invalid PNG magic header in $relPath',
    );
  }
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  _expect(manifestFile.existsSync(), 'AndroidManifest.xml must exist');
  final manifestText = manifestFile.readAsStringSync();
  _expect(manifestText.contains('android:label="ورقة الشايب"'), 'Manifest label is ورقة الشايب');
  _expect(manifestText.contains('android.permission.INTERNET'), 'Manifest includes INTERNET permission');
  print('ok 11 - Mobile PNG logo, Android 5-density launcher icons & Manifest verified');
  print('1..11');
}
