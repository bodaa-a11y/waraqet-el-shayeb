import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/media/media_storage_service.dart';

/// Lightweight document snapshot abstraction preserving backwards-compatibility
/// with the Firestore snapshot interface used across the Flutter controllers.
class ShayebDocSnapshot<T> {
  const ShayebDocSnapshot({required this.exists, this.dataMap, this.id = ''});
  final String id;
  final bool exists;
  final T? dataMap;
  T? data() => dataMap;
}

/// Lightweight collection snapshot abstraction preserving backwards-compatibility.
class ShayebQuerySnapshot<T> {
  const ShayebQuerySnapshot(this.docs);
  final List<ShayebDocSnapshot<T>> docs;
}

/// Canonical Flutter-to-Supabase bridge for El Shayeb Online (الشايب أونلاين).
///
/// Communicates with PostgreSQL via Supabase Edge Functions (`game` and `media`),
/// listens to Realtime subscriptions for authoritative state, and enforces RLS.
class ShayebGameBridge {
  ShayebGameBridge({
    SupabaseClient? client,
    MediaStorageService? mediaStorage,
  })  : _client = client ?? Supabase.instance.client,
        _mediaStorage = mediaStorage ?? SupabaseMediaStorageService(client: client);

  final SupabaseClient _client;
  final MediaStorageService _mediaStorage;

  SupabaseClient get client => _client;

  Future<String> ensureAnonymousLogin() async {
    final existing = _client.auth.currentUser;
    if (existing != null) return existing.id;
    final res = await _client.auth.signInAnonymously();
    final uid = res.user?.id;
    if (uid == null) throw StateError('فشل تسجيل الدخول، جرّب تاني');
    return uid;
  }

  String get uid {
    final value = _client.auth.currentUser?.id;
    if (value == null) throw StateError('لازم تدخل اللعبة الأول');
    return value;
  }

  Future<void> savePlayerProfile({
    required String nickname,
    required String avatarId,
  }) async {
    await ensureAnonymousLogin();
    await _invokeGame('saveProfile', {
      'nickname': nickname.trim(),
      'avatarId': avatarId,
    });
  }

  // ---------------------------------------------------------------------------
  // 1. createRoom
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> createRoom({
    required String nickname,
    String avatarId = 'avatar_1',
    String? title,
    int maxPlayers = 4,
    int totalRounds = 5,
    String direction = 'clockwise',
    String visibility = 'private',
    String challengeMode = 'every_round',
    int turnTimerSeconds = 45,
  }) async {
    await ensureAnonymousLogin();
    final res = await _invokeGame('createRoom', {
      'nickname': nickname,
      'avatarId': avatarId,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      'maxPlayers': maxPlayers,
      'totalRounds': totalRounds,
      'direction': direction,
      'visibility': visibility,
      'challengeMode': challengeMode,
      'turnTimerSeconds': turnTimerSeconds,
    });
    return res;
  }

  // ---------------------------------------------------------------------------
  // 2. joinRoomByCode & joinRoom
  // ---------------------------------------------------------------------------
  Future<String> joinRoomByCode({
    String? code,
    String? roomId,
    required String nickname,
    String avatarId = 'avatar_1',
  }) async {
    await ensureAnonymousLogin();
    final res = await _invokeGame('joinRoomByCode', {
      if (code != null) 'code': code.trim().toUpperCase(),
      if (roomId != null) 'roomId': roomId.trim(),
      'nickname': nickname,
      'avatarId': avatarId,
    });
    return res['roomId'] as String;
  }

  Future<String> joinRoom({
    String? code,
    String? roomId,
    required String nickname,
    String avatarId = 'avatar_1',
  }) =>
      joinRoomByCode(
        code: code,
        roomId: roomId,
        nickname: nickname,
        avatarId: avatarId,
      );

  // ---------------------------------------------------------------------------
  // 3. leaveRoom & kickPlayer
  // ---------------------------------------------------------------------------
  Future<void> leaveRoom(String roomId) async {
    await _invokeGame('leaveRoom', {'roomId': roomId});
  }

  Future<void> kickPlayer({required String roomId, required String targetUid}) async {
    await _invokeGame('kickPlayer', {
      'roomId': roomId,
      'targetUid': targetUid,
    });
  }

  // ---------------------------------------------------------------------------
  // 4. setPlayerReady & setReady
  // ---------------------------------------------------------------------------
  Future<void> setPlayerReady(String roomId, bool ready) async {
    await _invokeGame('setPlayerReady', {'roomId': roomId, 'ready': ready});
  }

  Future<void> setReady(String roomId, bool ready) => setPlayerReady(roomId, ready);

  // ---------------------------------------------------------------------------
  // 5. updateRoomSettings
  // ---------------------------------------------------------------------------
  Future<void> updateRoomSettings({
    required String roomId,
    required int maxPlayers,
    required int totalRounds,
    required String direction,
    required String visibility,
    required String challengeMode,
    required int turnTimerSeconds,
  }) async {
    await _invokeGame('updateRoomSettings', {
      'roomId': roomId,
      'maxPlayers': maxPlayers,
      'totalRounds': totalRounds,
      'direction': direction,
      'visibility': visibility,
      'challengeMode': challengeMode,
      'turnTimerSeconds': turnTimerSeconds,
    });
  }

  // ---------------------------------------------------------------------------
  // 6. startGame & startMatch
  // ---------------------------------------------------------------------------
  Future<void> startGame(String roomId) async {
    await _invokeGame('startGame', {'roomId': roomId});
  }

  Future<void> startMatch(String roomId) => startGame(roomId);

  // ---------------------------------------------------------------------------
  // 7. drawCard & claimTurnTimeout
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> drawCard({
    required String roomId,
    required int cardIndex,
    required int expectedVersion,
    String? actionId,
  }) async {
    final requestId =
        actionId ?? '${DateTime.now().microsecondsSinceEpoch}_${uid.substring(0, 6)}';
    return await _invokeGame('drawCard', {
      'roomId': roomId,
      'cardIndex': cardIndex,
      'expectedVersion': expectedVersion,
      'actionId': requestId,
    });
  }

  Future<Map<String, dynamic>> claimTurnTimeout({
    required String roomId,
    required int expectedVersion,
  }) async {
    return await _invokeGame('claimTurnTimeout', {
      'roomId': roomId,
      'expectedVersion': expectedVersion,
    });
  }

  // ---------------------------------------------------------------------------
  // 8. getRoomState
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getRoomState(String roomId) async {
    return await _invokeGame('getRoomState', {'roomId': roomId});
  }

  // ---------------------------------------------------------------------------
  // 9. advanceToNextRound & startNextRound
  // ---------------------------------------------------------------------------
  Future<void> advanceToNextRound(String roomId) async {
    await _invokeGame('advanceToNextRound', {'roomId': roomId});
  }

  Future<void> startNextRound(String roomId) => advanceToNextRound(roomId);

  // ---------------------------------------------------------------------------
  // 10, 11, 12. Challenges
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> assignChallenge(String roomId) async {
    return await _invokeGame('assignChallenge', {'roomId': roomId});
  }

  Future<Map<String, dynamic>> completeChallenge({
    required String roomId,
    bool skip = false,
    String? proofText,
    String? proofMediaUrl, // deprecated; signed URLs are not persisted
    String? proofMediaType,
    String? proofMediaId,
  }) async {
    return await _invokeGame('completeChallenge', {
      'roomId': roomId,
      'skip': skip,
      if (proofText != null) 'proofText': proofText,
      if (proofMediaId != null) 'mediaId': proofMediaId,
    });
  }

  Future<Map<String, dynamic>> redrawChallenge(String roomId) async {
    return await _invokeGame('redrawChallenge', {'roomId': roomId});
  }

  Future<Map<String, dynamic>> handleChallengeAction({
    required String roomId,
    required String action, // 'complete' | 'skip' | 'redraw'
    String? proofText,
    String? proofMediaUrl, // deprecated
    String? proofMediaType,
    String? proofMediaId,
  }) async {
    if (action == 'redraw') {
      return redrawChallenge(roomId);
    }
    return completeChallenge(
      roomId: roomId,
      skip: action == 'skip',
      proofText: proofText,
      proofMediaId: proofMediaId,
    );
  }

  // ---------------------------------------------------------------------------
  // 13. sendRoomMessage & sendChatMessage
  // ---------------------------------------------------------------------------
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
    String type = 'user',
    String? attachmentUrl,
    String? attachmentType,
    String? challengeInstanceId,
  }) async {
    await _invokeGame('sendRoomMessage', {
      'roomId': roomId,
      'text': text,
      'type': type,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentType != null) 'attachmentType': attachmentType,
      if (challengeInstanceId != null) 'challengeInstanceId': challengeInstanceId,
    });
  }

  Future<void> sendChatMessage({
    required String roomId,
    required String senderNickname,
    required String senderAvatar,
    required String text,
    String type = 'user',
    String? attachmentUrl,
    String? attachmentType,
    String? challengeInstanceId,
  }) async {
    final cleaned = text.replaceAll(RegExp(r'[<>]'), '').trim();
    if (cleaned.isEmpty || cleaned.length > 300) return;
    await sendRoomMessage(
      roomId: roomId,
      text: cleaned,
      type: type,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      challengeInstanceId: challengeInstanceId,
    );
  }

  // ---------------------------------------------------------------------------
  // 14. restartMatch & rematchRoom
  // ---------------------------------------------------------------------------
  Future<void> restartMatch(String roomId) async {
    await _invokeGame('restartMatch', {'roomId': roomId});
  }

  Future<void> rematchRoom(String roomId) => restartMatch(roomId);

  // ---------------------------------------------------------------------------
  // Media Upload & Download
  // ---------------------------------------------------------------------------
  Future<String> uploadChallengeEvidence({
    required String roomId,
    required String challengeInstanceId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    int? durationMs,
  }) async {
    // Returns the durable UUID for the uploaded object.
    return _mediaStorage.uploadEvidence(
      roomId: roomId,
      challengeInstanceId: challengeInstanceId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      durationMs: durationMs,
    );
  }

  /// Generate an authorized short-lived URL only when the user opens media.
  /// Never persist this response in PostgreSQL or shared messages.
  Future<Map<String, dynamic>> getPrivateMediaDownload(String mediaId) async {
    final response = await _client.functions.invoke(
      'media',
      body: {'action': 'getDownloadUrl', 'mediaId': mediaId},
    );
    if (response.status >= 400 || response.data is! Map) {
      throw StateError('الملف مش متاح دلوقتي');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  // ---------------------------------------------------------------------------
  // Realtime Subscriptions
  // ---------------------------------------------------------------------------

  /// Watches full authoritative room state (settings, players, active challenge).
  Stream<ShayebDocSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    late StreamController<ShayebDocSnapshot<Map<String, dynamic>>> controller;
    RealtimeChannel? channel;

    Future<void> fetchAndEmit() async {
      try {
        final state = await getRoomState(roomId);
        if (!controller.isClosed) {
          controller.add(ShayebDocSnapshot(exists: true, dataMap: state));
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    controller = StreamController<ShayebDocSnapshot<Map<String, dynamic>>>(
      onListen: () {
        fetchAndEmit();

        channel = _client.channel('room_updates:$roomId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: roomId,
            ),
            callback: (_) => fetchAndEmit(),
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'room_players',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (_) => fetchAndEmit(),
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'challenge_assignments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (_) => fetchAndEmit(),
          )
          ..subscribe();
      },
      onCancel: () async {
        if (channel != null) {
          await _client.removeChannel(channel!);
        }
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  /// Watches public round state (counts, turn, rankings - no secret card IDs).
  Stream<ShayebDocSnapshot<Map<String, dynamic>>> watchPublicRound(String roomId) {
    return _client
        .from('game_states')
        .stream(primaryKey: ['room_id'])
        .eq('room_id', roomId)
        .map((rows) {
          if (rows.isEmpty) {
            return const ShayebDocSnapshot(exists: false);
          }
          final state = rows.first['public_state'];
          if (state is Map) {
            return ShayebDocSnapshot(
              exists: true,
              dataMap: Map<String, dynamic>.from(state),
            );
          }
          return const ShayebDocSnapshot(exists: false);
        });
  }

  /// Watches the local player's private hand (owner-only read via RLS).
  Stream<ShayebDocSnapshot<Map<String, dynamic>>> watchOwnHand(String roomId) {
    final currentUid = uid;
    return _client
        .from('player_hands')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId)
        .map((rows) {
          final own = rows.where((r) => r['user_id'] == currentUid).toList();
          if (own.isEmpty) {
            return const ShayebDocSnapshot(exists: false);
          }
          return ShayebDocSnapshot(
            exists: true,
            dataMap: {
              'cards': own.first['cards'] ?? <dynamic>[],
              'roundId': own.first['round_id'],
              'version': own.first['version'],
            },
          );
        });
  }

  /// Public rooms directory. Reads the `public_rooms` view (no invite codes,
  /// no member lists). Views are not published to Realtime, so the directory
  /// is refreshed by light polling (every 5 s) while the screen is open.
  Stream<ShayebQuerySnapshot<Map<String, dynamic>>> watchPublicRooms({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    await ensureAnonymousLogin();
    while (true) {
      final rows = await _client
          .from('public_rooms')
          .select()
          .order('updated_at', ascending: false)
          .limit(30);
      final docs = (rows as List).map((raw) {
        final r = Map<String, dynamic>.from(raw as Map);
        final id = r['id'].toString();
        return ShayebDocSnapshot<Map<String, dynamic>>(
          id: id,
          exists: true,
          dataMap: {
            'roomId': id,
            'title': r['title'],
            'hostNickname': r['host_nickname'],
            'hostAvatar': r['host_avatar'],
            'playerCount': r['player_count'],
            'maxPlayers': r['max_players'],
            'totalRounds': r['total_rounds'],
            'direction': r['direction'],
            'challengeMode': r['challenge_mode'],
            'hasSpace': r['has_space'],
            'status': r['status'],
          },
        );
      }).toList();
      yield ShayebQuerySnapshot(docs);
      await Future<void>.delayed(interval);
    }
  }

  /// Watches real-time room chat messages and system events.
  Stream<ShayebQuerySnapshot<Map<String, dynamic>>> watchRoomMessages(String roomId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((rows) {
          final docs = rows.map((r) {
            final mapped = <String, dynamic>{
              'id': r['id'],
              'senderUid': r['sender_id'],
              'senderNickname': r['sender_nickname'],
              'senderAvatar': r['sender_avatar'],
              'type': r['type'],
              'text': r['text'],
              'createdAt': r['created_at'],
              'mediaId': r['media_id'],
              'challengeInstanceId': r['challenge_instance_id'],
            };
            return ShayebDocSnapshot<Map<String, dynamic>>(
              id: r['id'].toString(),
              exists: true,
              dataMap: mapped,
            );
          }).toList();
          return ShayebQuerySnapshot(docs);
        });
  }

  // ---------------------------------------------------------------------------
  // Internal Helper
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _invokeGame(
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'game',
        body: {'action': action, ...body},
      );
      if (response.status >= 400) {
        final errData = response.data;
        final errorText = errData is Map ? errData['error']?.toString() : null;
        throw StateError(errorText ?? 'خطأ في السيرفر (${response.status})');
      }
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {'ok': true};
    } on FunctionException catch (e) {
      final errDetails = e.details;
      if (errDetails is Map && errDetails['error'] != null) {
        throw StateError(errDetails['error'].toString());
      }
      throw StateError(e.reasonPhrase ?? 'خطأ في السيرفر (${e.status})');
    } catch (e) {
      if (e is StateError) rethrow;
      throw StateError(e.toString());
    }
  }
}
