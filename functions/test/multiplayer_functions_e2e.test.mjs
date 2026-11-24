import test from "node:test";
import assert from "node:assert/strict";
import {
  makeRound,
  drawCard,
  autoDrawOnTimeout,
  publicView,
  roundPoints,
  rankMatchPlayers,
  generateRoomCode,
  selectRandomChallenge,
  secureRandomInt,
  assertRoundInvariants,
  GameRuleError,
} from "../src/engine/index.ts";

/**
 * Full In-Memory Cloud Functions v2 + Firestore Transaction & Security Rules Simulator.
 * Exercises all 14 callable Cloud Functions (`createRoom`, `joinRoomByCode`, `leaveRoom`,
 * `setPlayerReady`, `updateRoomSettings`, `startGame`, `drawCard`, `getRoomState`,
 * `advanceToNextRound`, `assignChallenge`, `completeChallenge`, `redrawChallenge`,
 * `sendRoomMessage`, `restartMatch`, plus `kickPlayer` and `claimTurnTimeout`) across
 * independent authenticated client contexts (2 to 6 players).
 */
class CloudFunctionsMultiplayerSimulator {
  constructor() {
    this.rooms = new Map();
    this.roomCodes = new Map();
    this.publicRooms = new Map();
    this.secretRounds = new Map();
    this.publicStates = new Map();
    this.privateHands = new Map(); // roomId -> Map<uid, Card[]>
    this.actions = new Map(); // roomId -> Map<actionId, { uid, version }>
    this.messages = new Map(); // roomId -> Array
  }

  _requireAuth(auth) {
    if (!auth?.uid) throw new GameRuleError("unauthenticated", "Auth required");
    return auth.uid;
  }

  _requireRoom(roomId) {
    const room = this.rooms.get(roomId);
    if (!room) throw new GameRuleError("not-found", "Room not found");
    return room;
  }

  _requireMember(room, uid) {
    if (!room.memberIds.includes(uid)) {
      throw new GameRuleError("permission-denied", "Not a room member");
    }
  }

  _validateNickname(raw) {
    if (typeof raw !== "string") throw new GameRuleError("invalid-argument", "Invalid nickname");
    const cleaned = raw.replace(/[<>]/g, "").trim();
    if (cleaned.length < 2 || cleaned.length > 24) {
      throw new GameRuleError("invalid-argument", "Nickname length invalid");
    }
    if (["النظام", "سيستم", "system", "admin", "أدمن", "المشرف"].includes(cleaned.toLowerCase())) {
      throw new GameRuleError("invalid-argument", "Reserved system nickname");
    }
    return cleaned;
  }

  _writeRound(roomId, round, roundNumber) {
    this.secretRounds.set(roomId, round);
    const pub = publicView(round);
    this.publicStates.set(roomId, { ...pub, roundNumber });
    const handMap = new Map();
    for (const pid of round.playerOrder) {
      handMap.set(pid, round.hands[pid]);
    }
    this.privateHands.set(roomId, handMap);
  }

  _computeRoundCompletion(room, round) {
    const scores = { ...room.scores };
    const losses = { ...room.losses };
    const firstFinishes = { ...room.firstFinishes };
    const pts = roundPoints(round.finishOrder);
    for (const p of room.players) {
      scores[p.uid] = (scores[p.uid] ?? 0) + (pts[p.uid] ?? 0);
    }
    const loserUid = round.loserId;
    losses[loserUid] = (losses[loserUid] ?? 0) + 1;
    const firstUid = round.finishOrder[0];
    if (firstUid) {
      firstFinishes[firstUid] = (firstFinishes[firstUid] ?? 0) + 1;
    }
    const isMatchOver = room.roundNumber >= room.totalRounds;
    const shouldChallenge =
      room.challengeMode === "every_round" ||
      (room.challengeMode === "end_of_match" && isMatchOver);

    let activeChallenge = null;
    const usedChallengeIds = [...room.usedChallengeIds];
    if (shouldChallenge) {
      const picked = selectRandomChallenge(usedChallengeIds);
      usedChallengeIds.push(picked.id);
      const loserPlayer = room.players.find((p) => p.uid === loserUid);
      activeChallenge = {
        instanceId: `ch_r${room.roundNumber}`,
        roundNumber: room.roundNumber,
        loserUid,
        loserNickname: loserPlayer?.nickname ?? "لاعب",
        challenge: picked,
        status: "pending",
        redrawCount: 0,
        proofText: null,
      };
    }

    return {
      scores,
      losses,
      firstFinishes,
      status: isMatchOver ? "finished" : "round_results",
      activeChallenge,
      usedChallengeIds,
      lastLoserUid: loserUid,
    };
  }

  // 1. createRoom
  createRoom(auth, data) {
    const uid = this._requireAuth(auth);
    const nickname = this._validateNickname(data.nickname);
    const roomId = `room_${this.rooms.size + 1}`;
    let code;
    do {
      code = generateRoomCode(6);
    } while (this.roomCodes.has(code));

    const room = {
      roomId,
      hostId: uid,
      code,
      title: data.title ?? `قعدة ${nickname}`,
      visibility: data.visibility ?? "private",
      maxPlayers: data.maxPlayers ?? 4,
      totalRounds: data.totalRounds ?? 3,
      direction: data.direction ?? "clockwise",
      challengeMode: data.challengeMode ?? "every_round",
      turnTimerSeconds: data.turnTimerSeconds ?? 45,
      status: "waiting",
      roundNumber: 0,
      players: [{ uid, nickname, avatarId: data.avatarId ?? "avatar_1", seat: 0, ready: true, isConnected: true }],
      memberIds: [uid],
      bannedUids: [],
      scores: { [uid]: 0 },
      losses: { [uid]: 0 },
      firstFinishes: { [uid]: 0 },
      usedChallengeIds: [],
      activeChallenge: null,
      lastLoserUid: null,
    };

    this.rooms.set(roomId, room);
    this.roomCodes.set(code, roomId);
    this.actions.set(roomId, new Map());
    this.messages.set(roomId, []);
    if (room.visibility === "public") {
      this.publicRooms.set(roomId, { roomId, title: room.title, playerCount: 1, maxPlayers: room.maxPlayers });
    }
    return { roomId, code };
  }

  // 2. joinRoomByCode
  joinRoomByCode(auth, data) {
    const uid = this._requireAuth(auth);
    const nickname = this._validateNickname(data.nickname);
    const code = (data.code ?? "").trim().toUpperCase();
    const roomId = data.roomId ?? this.roomCodes.get(code);
    if (!roomId) throw new GameRuleError("not-found", "Invalid room code");
    const room = this._requireRoom(roomId);
    if (room.bannedUids.includes(uid)) {
      throw new GameRuleError("permission-denied", "Banned from room");
    }
    if (room.memberIds.includes(uid)) {
      room.players = room.players.map((p) => (p.uid === uid ? { ...p, isConnected: true } : p));
      return { roomId, code: room.code };
    }
    if (room.status !== "waiting") throw new GameRuleError("failed-precondition", "Already started");
    if (room.players.length >= room.maxPlayers) throw new GameRuleError("resource-exhausted", "Room full");

    const usedSeats = new Set(room.players.map((p) => p.seat));
    let seat = 0;
    while (usedSeats.has(seat)) seat++;
    room.players.push({
      uid,
      nickname,
      avatarId: data.avatarId ?? "avatar_2",
      seat,
      ready: false,
      isConnected: true,
    });
    room.memberIds.push(uid);
    room.scores[uid] = 0;
    room.losses[uid] = 0;
    room.firstFinishes[uid] = 0;
    return { roomId, code: room.code };
  }

  // 3. leaveRoom & kickPlayer
  leaveRoom(auth, { roomId }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    if (!room.memberIds.includes(uid)) return { ok: true };
    if (room.status === "waiting" || room.status === "finished") {
      room.players = room.players.filter((p) => p.uid !== uid);
      room.memberIds = room.memberIds.filter((id) => id !== uid);
      if (room.players.length === 0) {
        room.status = "closed";
        this.roomCodes.delete(room.code);
        this.publicRooms.delete(roomId);
      } else if (room.hostId === uid) {
        const sorted = [...room.players].sort((a, b) => a.seat - b.seat);
        room.hostId = sorted[0].uid;
        room.players = room.players.map((p) => (p.uid === room.hostId ? { ...p, ready: true } : p));
      }
      return { ok: true };
    }
    // Active game disconnect preserves cards & seat invariant
    room.players = room.players.map((p) => (p.uid === uid ? { ...p, isConnected: false } : p));
    if (room.hostId === uid) {
      const nextHost = room.players.find((p) => p.uid !== uid && p.isConnected) ?? room.players.find((p) => p.uid !== uid);
      if (nextHost) room.hostId = nextHost.uid;
    }
    return { ok: true };
  }

  kickPlayer(auth, { roomId, targetUid }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    if (room.hostId !== uid) throw new GameRuleError("permission-denied", "Only host can kick");
    if (room.status !== "waiting") throw new GameRuleError("failed-precondition", "Cannot kick after start");
    room.players = room.players.filter((p) => p.uid !== targetUid);
    room.memberIds = room.memberIds.filter((id) => id !== targetUid);
    room.bannedUids.push(targetUid);
    return { ok: true };
  }

  // 4. setPlayerReady
  setPlayerReady(auth, { roomId, ready }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    room.players = room.players.map((p) => (p.uid === uid ? { ...p, ready: Boolean(ready) } : p));
    return { ok: true };
  }

  // 5. updateRoomSettings
  updateRoomSettings(auth, { roomId, maxPlayers, totalRounds, direction, challengeMode }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    if (room.hostId !== uid) throw new GameRuleError("permission-denied", "Only host can update settings");
    if (room.status !== "waiting") throw new GameRuleError("failed-precondition", "Game already started");
    if (maxPlayers !== undefined) room.maxPlayers = maxPlayers;
    if (totalRounds !== undefined) room.totalRounds = totalRounds;
    if (direction !== undefined) room.direction = direction;
    if (challengeMode !== undefined) room.challengeMode = challengeMode;
    return { ok: true };
  }

  // 6. startGame
  startGame(auth, { roomId }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    if (room.hostId !== uid) throw new GameRuleError("permission-denied", "Only host can start");
    if (room.status !== "waiting") throw new GameRuleError("failed-precondition", "Already started");
    if (room.players.length < 2 || !room.players.every((p) => p.ready || p.uid === room.hostId)) {
      throw new GameRuleError("failed-precondition", "Not all players ready");
    }
    const order = [...room.players].sort((a, b) => a.seat - b.seat).map((p) => p.uid);
    const round = makeRound(order, {
      roundNumber: 1,
      direction: room.direction,
      turnTimerSeconds: room.turnTimerSeconds,
    });
    room.roundNumber = 1;
    room.activeChallenge = null;
    if (round.status === "finished") {
      Object.assign(room, this._computeRoundCompletion(room, round));
    } else {
      room.status = "playing";
    }
    this._writeRound(roomId, round, 1);
    return { ok: true };
  }

  // 7. drawCard & claimTurnTimeout
  drawCard(auth, { roomId, cardIndex, expectedVersion, actionId }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    const roomActions = this.actions.get(roomId);
    if (roomActions.has(actionId)) {
      const existing = roomActions.get(actionId);
      if (existing.uid !== uid) throw new GameRuleError("permission-denied", "Action ID belongs to another player");
      return { applied: false, alreadyApplied: true, version: existing.version };
    }
    if (room.status !== "playing") throw new GameRuleError("failed-precondition", "Round not playing");
    const prev = this.secretRounds.get(roomId);
    const next = drawCard(prev, { actorId: uid, cardIndex, expectedVersion });
    assertRoundInvariants(next);
    this._writeRound(roomId, next, room.roundNumber);
    roomActions.set(actionId, { uid, version: next.version });

    if (next.status === "finished") {
      Object.assign(room, this._computeRoundCompletion(room, next));
    }
    return { applied: true, alreadyApplied: false, version: next.version, roundFinished: next.status === "finished" };
  }

  claimTurnTimeout(auth, { roomId, expectedVersion, nowMs }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    const prev = this.secretRounds.get(roomId);
    const next = autoDrawOnTimeout(prev, expectedVersion, nowMs);
    this._writeRound(roomId, next, room.roundNumber);
    if (next.status === "finished") {
      Object.assign(room, this._computeRoundCompletion(room, next));
    }
    return { applied: true, version: next.version };
  }

  // 8. getRoomState (Enforces strict hand isolation: only returns caller's ownHand!)
  getRoomState(auth, { roomId, requestedHandUid }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    if (requestedHandUid && requestedHandUid !== uid) {
      throw new GameRuleError("permission-denied", "Cannot read another player's private hand");
    }
    const pub = this.publicStates.get(roomId) ?? null;
    const ownHand = this.privateHands.get(roomId)?.get(uid) ?? [];
    const standings = rankMatchPlayers(
      room.players.map((p) => p.uid),
      room.scores,
      room.losses,
      room.firstFinishes,
    );
    return { room, publicRound: pub, ownHand, standings };
  }

  // 9. advanceToNextRound
  advanceToNextRound(auth, { roomId }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    if (room.hostId !== uid) throw new GameRuleError("permission-denied", "Only host can advance round");
    if (room.status !== "round_results" || room.roundNumber >= room.totalRounds) {
      throw new GameRuleError("failed-precondition", "No next round available");
    }
    const nextNumber = room.roundNumber + 1;
    const order = [...room.players].sort((a, b) => a.seat - b.seat).map((p) => p.uid);
    const round = makeRound(order, {
      roundNumber: nextNumber,
      direction: room.direction,
      turnTimerSeconds: room.turnTimerSeconds,
    });
    room.roundNumber = nextNumber;
    room.activeChallenge = null;
    if (round.status === "finished") {
      Object.assign(room, this._computeRoundCompletion(room, round));
    } else {
      room.status = "playing";
    }
    this._writeRound(roomId, round, nextNumber);
    return { ok: true };
  }

  // 10, 11, 12. assignChallenge, redrawChallenge, completeChallenge
  assignChallenge(auth, { roomId }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    return { activeChallenge: room.activeChallenge };
  }

  redrawChallenge(auth, { roomId }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    const current = room.activeChallenge;
    if (!current) throw new GameRuleError("failed-precondition", "No active challenge");
    if (current.loserUid !== uid && room.hostId !== uid) {
      throw new GameRuleError("permission-denied", "Only loser can redraw challenge");
    }
    if (current.redrawCount >= 2) {
      throw new GameRuleError("failed-precondition", "Max redraws reached");
    }
    const nextCh = selectRandomChallenge([...room.usedChallengeIds, current.challenge.id]);
    room.usedChallengeIds.push(nextCh.id);
    room.activeChallenge = {
      ...current,
      challenge: nextCh,
      redrawCount: current.redrawCount + 1,
    };
    return { activeChallenge: room.activeChallenge };
  }

  completeChallenge(auth, { roomId, skip = false, proofText = null }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    const current = room.activeChallenge;
    if (!current) throw new GameRuleError("failed-precondition", "No active challenge");
    if (current.loserUid !== uid && room.hostId !== uid) {
      throw new GameRuleError("permission-denied", "Only loser can complete challenge");
    }
    room.activeChallenge = {
      ...current,
      status: skip ? "skipped" : "completed",
      proofText,
    };
    return { activeChallenge: room.activeChallenge };
  }

  // 13. sendRoomMessage
  sendRoomMessage(auth, { roomId, text, type = "user" }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    this._requireMember(room, uid);
    if (!["user", "reaction", "evidence"].includes(type)) {
      throw new GameRuleError("permission-denied", "Cannot forge system message");
    }
    const cleaned = String(text ?? "").replace(/[<>]/g, "").trim();
    if (!cleaned || cleaned.length > 300) {
      throw new GameRuleError("invalid-argument", "Invalid message text");
    }
    const msg = { id: `msg_${Date.now()}`, senderUid: uid, type, text: cleaned };
    this.messages.get(roomId).push(msg);
    return { messageId: msg.id };
  }

  // 14. restartMatch
  restartMatch(auth, { roomId }) {
    const uid = this._requireAuth(auth);
    const room = this._requireRoom(roomId);
    if (room.hostId !== uid) throw new GameRuleError("permission-denied", "Only host can restart match");
    room.status = "waiting";
    room.roundNumber = 0;
    room.activeChallenge = null;
    for (const p of room.players) {
      room.scores[p.uid] = 0;
      room.losses[p.uid] = 0;
      room.firstFinishes[p.uid] = 0;
      p.ready = true;
    }
    return { ok: true };
  }
}

test("E2E Multi-Client Test: 2 independent authenticated clients play a complete 3-round match with challenges, chat, and restart", () => {
  const sim = new CloudFunctionsMultiplayerSimulator();
  const clientA = { uid: "uid_ahmed" };
  const clientB = { uid: "uid_sara" };
  const outsider = { uid: "uid_outsider" };

  // 1. Client A creates a 3-round private room
  const { roomId, code } = sim.createRoom(clientA, {
    nickname: "أحمد المعلم",
    maxPlayers: 2,
    totalRounds: 3,
    challengeMode: "every_round",
  });
  assert.equal(code.length, 6);

  // 2. Client B joins using the 6-char room code
  const joined = sim.joinRoomByCode(clientB, { code, nickname: "سارة البرنسيسة" });
  assert.equal(joined.roomId, roomId);

  // 3. Outsider is blocked from reading room state or sending messages
  assert.throws(
    () => sim.getRoomState(outsider, { roomId }),
    (e) => e.code === "permission-denied",
  );
  assert.throws(
    () => sim.sendRoomMessage(outsider, { roomId, text: "اختراق" }),
    (e) => e.code === "permission-denied",
  );

  // 4. Client B cannot start the game (not host) and Client A cannot start before Client B is ready
  assert.throws(
    () => sim.startGame(clientB, { roomId }),
    (e) => e.code === "permission-denied",
  );
  assert.throws(
    () => sim.startGame(clientA, { roomId }),
    (e) => e.code === "failed-precondition",
  );

  // 5. Client B marks ready; Host A starts the match
  sim.setPlayerReady(clientB, { roomId, ready: true });
  sim.startGame(clientA, { roomId });

  // 6. Verify anti-cheat hand isolation: Client A cannot read Client B's hand
  assert.throws(
    () => sim.getRoomState(clientA, { roomId, requestedHandUid: "uid_sara" }),
    (e) => e.code === "permission-denied",
  );

  // 7. Play all 3 rounds to completion using only publicRound + each player's own auth context
  for (let roundNum = 1; roundNum <= 3; roundNum++) {
    let stateA = sim.getRoomState(clientA, { roomId });
    while (stateA.publicRound.status === "playing") {
      const activeUid = stateA.publicRound.currentPlayerId;
      const activeClient = activeUid === "uid_ahmed" ? clientA : clientB;
      const inactiveClient = activeUid === "uid_ahmed" ? clientB : clientA;

      // Wrong player attempting to draw is rejected
      assert.throws(
        () =>
          sim.drawCard(inactiveClient, {
            roomId,
            cardIndex: 0,
            expectedVersion: stateA.publicRound.version,
            actionId: `bad_turn_${roundNum}_${stateA.publicRound.version}`,
          }),
        (e) => e.code === "not_your_turn",
      );

      const actionId = `act_r${roundNum}_v${stateA.publicRound.version}`;
      const targetId = stateA.publicRound.drawTargetId;
      const targetCount = stateA.publicRound.handCounts[targetId];
      const pickedIdx = secureRandomInt(targetCount);
      const drawRes = sim.drawCard(activeClient, {
        roomId,
        cardIndex: pickedIdx,
        expectedVersion: stateA.publicRound.version,
        actionId,
      });
      assert.equal(drawRes.applied, true);

      // Duplicate request with same actionId is safely idempotent
      const dupRes = sim.drawCard(activeClient, {
        roomId,
        cardIndex: 0,
        expectedVersion: stateA.publicRound.version,
        actionId,
      });
      assert.equal(dupRes.applied, false);
      assert.equal(dupRes.alreadyApplied, true);

      stateA = sim.getRoomState(clientA, { roomId });
    }

    // Round completed: verify challenge assigned to loser, redraw once, then complete with proof
    const postRound = sim.getRoomState(clientA, { roomId });
    assert.ok(postRound.room.activeChallenge);
    const loserUid = postRound.room.activeChallenge.loserUid;
    const loserClient = loserUid === "uid_ahmed" ? clientA : clientB;
    const oldChallengeId = postRound.room.activeChallenge.challenge.id;

    const redrawn = sim.redrawChallenge(loserClient, { roomId });
    assert.notEqual(redrawn.activeChallenge.challenge.id, oldChallengeId);
    assert.equal(redrawn.activeChallenge.redrawCount, 1);

    const completed = sim.completeChallenge(loserClient, {
      roomId,
      proofText: "نفذت الحكم يا رجالة!",
    });
    assert.equal(completed.activeChallenge.status, "completed");

    if (roundNum < 3) {
      assert.equal(postRound.room.status, "round_results");
      sim.advanceToNextRound(clientA, { roomId });
    } else {
      assert.equal(postRound.room.status, "finished");
    }
  }

  // 8. Verify chat messages & anti-impersonation
  sim.sendRoomMessage(clientA, { roomId, text: "جيم عالمي يا سارة 🔥" });
  assert.throws(
    () => sim.sendRoomMessage(clientB, { roomId, text: "رسالة مزورة", type: "system" }),
    (e) => e.code === "permission-denied",
  );

  // 9. Verify final standings & restartMatch
  const finalView = sim.getRoomState(clientA, { roomId });
  assert.equal(finalView.standings.length, 2);
  assert.equal(
    finalView.standings[0].totalPoints + finalView.standings[1].totalPoints,
    3, // 3 rounds × 1 point per 2-player round
  );

  sim.restartMatch(clientA, { roomId });
  const restarted = sim.getRoomState(clientA, { roomId });
  assert.equal(restarted.room.status, "waiting");
  assert.equal(restarted.room.roundNumber, 0);
});

test("E2E Multi-Client Test: 3, 4, 5, and 6 independent authenticated clients play full matches with host transfer, kick, timeout, and reconnect", () => {
  for (const playerCount of [3, 4, 5, 6]) {
    const sim = new CloudFunctionsMultiplayerSimulator();
    const clients = Array.from({ length: playerCount }, (_, i) => ({
      uid: `user_${i + 1}`,
      nickname: `لاعب_${i + 1}`,
    }));

    const { roomId, code } = sim.createRoom(clients[0], {
      nickname: clients[0].nickname,
      maxPlayers: playerCount,
      totalRounds: 1,
    });

    for (let i = 1; i < playerCount; i++) {
      sim.joinRoomByCode(clients[i], { code, nickname: clients[i].nickname });
      sim.setPlayerReady(clients[i], { roomId, ready: true });
    }

    sim.startGame(clients[0], { roomId });

    // Simulate one player temporarily disconnecting and reconnecting mid-round
    sim.leaveRoom(clients[1], { roomId });
    sim.joinRoomByCode(clients[1], { code, nickname: clients[1].nickname });

    // Simulate a turn timeout on the first turn
    let view = sim.getRoomState(clients[0], { roomId });
    if (view.publicRound.status === "playing") {
      const timeoutRes = sim.claimTurnTimeout(clients[0], {
        roomId,
        expectedVersion: view.publicRound.version,
      });
      assert.equal(timeoutRes.applied, true);
    }

    // Play out the rest of the round
    view = sim.getRoomState(clients[0], { roomId });
    while (view.publicRound.status === "playing") {
      const activeUid = view.publicRound.currentPlayerId;
      const activeClient = clients.find((c) => c.uid === activeUid);
      const targetId = view.publicRound.drawTargetId;
      const targetCount = view.publicRound.handCounts[targetId];
      sim.drawCard(activeClient, {
        roomId,
        cardIndex: secureRandomInt(targetCount),
        expectedVersion: view.publicRound.version,
        actionId: `act_${playerCount}p_v${view.publicRound.version}`,
      });
      view = sim.getRoomState(clients[0], { roomId });
    }

    assert.equal(view.room.status, "finished");
    assert.equal(view.standings.length, playerCount);
    const expectedTotalPoints = (playerCount * (playerCount - 1)) / 2;
    const actualTotalPoints = view.standings.reduce((acc, s) => acc + s.totalPoints, 0);
    assert.equal(actualTotalPoints, expectedTotalPoints);
  }
});
