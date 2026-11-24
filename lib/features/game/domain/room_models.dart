import '../../challenges/domain/challenge_model.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.nickname,
    required this.avatarId,
    this.soundEnabled = true,
    this.soundVolume = 0.78,
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.effectsQualityKey = 'full',
  });

  final String uid;
  final String nickname;
  final String avatarId;
  final bool soundEnabled;
  final double soundVolume;
  final bool hapticsEnabled;
  final bool reducedMotion;
  final String effectsQualityKey;

  PlayerProfile copyWith({
    String? uid,
    String? nickname,
    String? avatarId,
    bool? soundEnabled,
    double? soundVolume,
    bool? hapticsEnabled,
    bool? reducedMotion,
    String? effectsQualityKey,
  }) {
    return PlayerProfile(
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      avatarId: avatarId ?? this.avatarId,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      effectsQualityKey: effectsQualityKey ?? this.effectsQualityKey,
    );
  }

  static String? validateNickname(String raw) {
    final trimmed = raw.replaceAll(RegExp(r'[<>]'), '').trim();
    if (trimmed.length < 2 || trimmed.length > 24) {
      return 'الاسم لازم يكون بين حرفين و ٢٤ حرف';
    }
    const forbidden = {'النظام', 'سيستم', 'system', 'admin', 'أدمن', 'المشرف'};
    if (forbidden.contains(trimmed.toLowerCase())) {
      return 'الاسم ده محجوز للنظام، اختار اسم تاني يا معلم';
    }
    return null;
  }
}

class RoomPlayerModel {
  const RoomPlayerModel({
    required this.uid,
    required this.nickname,
    required this.avatarId,
    required this.seat,
    required this.ready,
    this.isConnected = true,
    this.temporaryTitle,
  });

  factory RoomPlayerModel.fromMap(Map<String, dynamic> map) {
    return RoomPlayerModel(
      uid: (map['uid'] ?? '').toString(),
      nickname: (map['nickname'] ?? 'لاعب').toString(),
      avatarId: (map['avatarId'] ?? 'avatar_1').toString(),
      seat: (map['seat'] as num?)?.toInt() ?? 0,
      ready: map['ready'] == true,
      isConnected: map['isConnected'] != false,
      temporaryTitle: map['temporaryTitle']?.toString(),
    );
  }

  final String uid;
  final String nickname;
  final String avatarId;
  final int seat;
  final bool ready;
  final bool isConnected;
  final String? temporaryTitle;
}

class ActiveChallengeModel {
  const ActiveChallengeModel({
    required this.instanceId,
    required this.roundNumber,
    required this.loserUid,
    required this.loserNickname,
    required this.challenge,
    required this.status,
    required this.redrawCount,
    this.proofText,
    this.proofMediaUrl,
    this.proofMediaType,
    this.proofMediaId,
  });

  factory ActiveChallengeModel.fromMap(Map<String, dynamic> map) {
    final chMap = Map<String, dynamic>.from(map['challenge'] as Map? ?? {});
    return ActiveChallengeModel(
      instanceId: (map['instanceId'] ?? '').toString(),
      roundNumber: (map['roundNumber'] as num?)?.toInt() ?? 1,
      loserUid: (map['loserUid'] ?? '').toString(),
      loserNickname: (map['loserNickname'] ?? 'اللاعب').toString(),
      challenge: ChallengeItem.fromMap(chMap),
      status: (map['status'] ?? 'pending').toString(),
      redrawCount: (map['redrawCount'] as num?)?.toInt() ?? 0,
      proofText: map['proofText']?.toString(),
      proofMediaUrl: map['proofMediaUrl']?.toString(),
      proofMediaType: map['proofMediaType']?.toString(),
      proofMediaId: map['proofMediaId']?.toString(),
    );
  }

  final String instanceId;
  final int roundNumber;
  final String loserUid;
  final String loserNickname;
  final ChallengeItem challenge;
  final String status; // 'pending' | 'completed' | 'skipped'
  final int redrawCount;
  final String? proofText;
  final String? proofMediaUrl;
  final String? proofMediaType;
  final String? proofMediaId;
}

class RoomStateModel {
  const RoomStateModel({
    required this.roomId,
    required this.code,
    required this.title,
    required this.hostId,
    required this.visibility,
    required this.maxPlayers,
    required this.totalRounds,
    required this.direction,
    required this.challengeMode,
    required this.turnTimerSeconds,
    required this.status,
    required this.roundNumber,
    required this.players,
    required this.scores,
    required this.losses,
    required this.firstFinishes,
    this.activeChallenge,
  });

  factory RoomStateModel.fromMap(String roomId, Map<String, dynamic> map) {
    final rawPlayers = (map['players'] as List<dynamic>? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => RoomPlayerModel.fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.seat.compareTo(b.seat));

    Map<String, int> parseIntMap(Object? raw) {
      final res = <String, int>{};
      if (raw is Map) {
        for (final entry in raw.entries) {
          res[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
        }
      }
      return res;
    }

    final rawChallenge = map['activeChallenge'];
    return RoomStateModel(
      roomId: roomId,
      code: (map['code'] ?? '').toString(),
      title: (map['title'] ?? 'قعدة الشايب').toString(),
      hostId: (map['hostId'] ?? '').toString(),
      visibility: (map['visibility'] ?? 'private').toString(),
      maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 4,
      totalRounds: (map['totalRounds'] as num?)?.toInt() ?? 5,
      direction: (map['direction'] ?? 'clockwise').toString(),
      challengeMode: (map['challengeMode'] ?? 'every_round').toString(),
      turnTimerSeconds: (map['turnTimerSeconds'] as num?)?.toInt() ?? 45,
      status: (map['status'] ?? 'waiting').toString(),
      roundNumber: (map['roundNumber'] as num?)?.toInt() ?? 0,
      players: rawPlayers,
      scores: parseIntMap(map['scores']),
      losses: parseIntMap(map['losses']),
      firstFinishes: parseIntMap(map['firstFinishes']),
      activeChallenge: rawChallenge is Map
          ? ActiveChallengeModel.fromMap(Map<String, dynamic>.from(rawChallenge))
          : null,
    );
  }

  final String roomId;
  final String code;
  final String title;
  final String hostId;
  final String visibility;
  final int maxPlayers;
  final int totalRounds;
  final String direction;
  final String challengeMode;
  final int turnTimerSeconds;
  final String status;
  final int roundNumber;
  final List<RoomPlayerModel> players;
  final Map<String, int> scores;
  final Map<String, int> losses;
  final Map<String, int> firstFinishes;
  final ActiveChallengeModel? activeChallenge;

  String nicknameOf(String? uid) {
    if (uid == null) return 'لاعب';
    for (final p in players) {
      if (p.uid == uid) return p.nickname;
    }
    return 'لاعب';
  }

  String avatarOf(String? uid) {
    if (uid == null) return 'avatar_1';
    for (final p in players) {
      if (p.uid == uid) return p.avatarId;
    }
    return 'avatar_1';
  }
}

class PublicRoundModel {
  const PublicRoundModel({
    required this.id,
    required this.playerOrder,
    required this.direction,
    required this.handCounts,
    required this.finishOrder,
    required this.currentPlayerId,
    required this.drawTargetId,
    required this.turnNumber,
    required this.version,
    required this.status,
    required this.loserId,
    required this.discardCount,
    this.turnDeadlineMs,
    this.lastMovePairsRemoved = 0,
    this.lastMoveActorId,
    this.lastMoveTargetId,
  });

  factory PublicRoundModel.fromMap(Map<String, dynamic> map) {
    final counts = <String, int>{};
    final rawCounts = map['handCounts'];
    if (rawCounts is Map) {
      for (final e in rawCounts.entries) {
        counts[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    final lastMove = map['lastMove'] is Map
        ? Map<String, dynamic>.from(map['lastMove'] as Map)
        : null;
    return PublicRoundModel(
      id: (map['id'] ?? 'round_1').toString(),
      playerOrder: (map['playerOrder'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      direction: (map['direction'] ?? 'clockwise').toString(),
      handCounts: counts,
      finishOrder: (map['finishOrder'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      currentPlayerId: map['currentPlayerId']?.toString(),
      drawTargetId: map['drawTargetId']?.toString(),
      turnNumber: (map['turnNumber'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 0,
      status: (map['status'] ?? 'playing').toString(),
      loserId: map['loserId']?.toString(),
      discardCount: (map['discardCount'] as num?)?.toInt() ?? 0,
      turnDeadlineMs: (map['turnDeadlineMs'] as num?)?.toInt(),
      lastMovePairsRemoved: (lastMove?['pairsRemoved'] as num?)?.toInt() ?? 0,
      lastMoveActorId: lastMove?['actorId']?.toString(),
      lastMoveTargetId: lastMove?['targetId']?.toString(),
    );
  }

  final String id;
  final List<String> playerOrder;
  final String direction;
  final Map<String, int> handCounts;
  final List<String> finishOrder;
  final String? currentPlayerId;
  final String? drawTargetId;
  final int turnNumber;
  final int version;
  final String status;
  final String? loserId;
  final int discardCount;
  final int? turnDeadlineMs;
  final int lastMovePairsRemoved;
  final String? lastMoveActorId;
  final String? lastMoveTargetId;
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.senderUid,
    required this.senderNickname,
    required this.senderAvatar,
    required this.type,
    required this.text,
    this.attachmentUrl,
    this.attachmentType,
    this.mediaId,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: (map['id'] ?? '').toString(),
      senderUid: (map['senderUid'] ?? '').toString(),
      senderNickname: (map['senderNickname'] ?? 'لاعب').toString(),
      senderAvatar: (map['senderAvatar'] ?? 'avatar_1').toString(),
      type: (map['type'] ?? 'user').toString(),
      text: (map['text'] ?? '').toString(),
      attachmentUrl: map['attachmentUrl']?.toString(),
      attachmentType: map['attachmentType']?.toString(),
      mediaId: map['mediaId']?.toString(),
    );
  }

  final String id;
  final String senderUid;
  final String senderNickname;
  final String senderAvatar;
  final String type; // 'user' | 'system' | 'reaction' | 'evidence'
  final String text;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? mediaId; // Durable UUID; download URL is requested on demand.

  bool get isSystem => type == 'system';
}

class MatchStandingRow {
  const MatchStandingRow({
    required this.uid,
    required this.nickname,
    required this.avatarId,
    required this.totalPoints,
    required this.roundsLost,
    required this.firstFinishes,
    required this.placement,
    required this.isSharedPlacement,
    required this.titleAr,
  });

  final String uid;
  final String nickname;
  final String avatarId;
  final int totalPoints;
  final int roundsLost;
  final int firstFinishes;
  final int placement;
  final bool isSharedPlacement;
  final String titleAr;

  static List<MatchStandingRow> computeFromRoom(RoomStateModel room) {
    final rows = room.players.map((p) {
      return (
        uid: p.uid,
        nickname: p.nickname,
        avatarId: p.avatarId,
        pts: room.scores[p.uid] ?? 0,
        lost: room.losses[p.uid] ?? 0,
        firsts: room.firstFinishes[p.uid] ?? 0,
      );
    }).toList();

    rows.sort((a, b) {
      if (b.pts != a.pts) return b.pts.compareTo(a.pts);
      if (a.lost != b.lost) return a.lost.compareTo(b.lost);
      if (b.firsts != a.firsts) return b.firsts.compareTo(a.firsts);
      return a.uid.compareTo(b.uid);
    });

    final placements = <int>[];
    for (var i = 0; i < rows.length; i++) {
      if (i == 0) {
        placements.add(1);
        continue;
      }
      final prev = rows[i - 1];
      final curr = rows[i];
      final tied =
          prev.pts == curr.pts && prev.lost == curr.lost && prev.firsts == curr.firsts;
      placements.add(tied ? placements[i - 1] : i + 1);
    }

    final counts = <int, int>{};
    for (final p in placements) {
      counts[p] = (counts[p] ?? 0) + 1;
    }

    return List.generate(rows.length, (idx) {
      final r = rows[idx];
      final placement = placements[idx];
      final isLast = idx == rows.length - 1 && rows.length > 1;
      var title = 'لعيب القعدة';
      if (placement == 1) {
        title = 'معلم القهوة الكبير 👑';
      } else if (isLast && r.lost > 0) {
        title = 'شايب القعدة الرسمي 👴';
      } else if (r.firsts >= 2) {
        title = 'ملك الفلتان ⚡';
      }
      return MatchStandingRow(
        uid: r.uid,
        nickname: r.nickname,
        avatarId: r.avatarId,
        totalPoints: r.pts,
        roundsLost: r.lost,
        firstFinishes: r.firsts,
        placement: placement,
        isSharedPlacement: (counts[placement] ?? 0) > 1,
        titleAr: title,
      );
    });
  }
}
