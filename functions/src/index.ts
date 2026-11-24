import { initializeApp } from "firebase-admin/app";
import {
  getFirestore,
  FieldValue,
  Timestamp,
  type Transaction,
  type DocumentSnapshot,
} from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  makeRound,
  drawCard as executeDraw,
  autoDrawOnTimeout,
  publicView,
  roundPoints,
  rankMatchPlayers,
  generateRoomCode,
  selectRandomChallenge,
  EGYPTIAN_CHALLENGES,
  GameRuleError,
  type ChallengeMode,
  type ChallengeDefinition,
  type Direction,
  type RoundState,
} from "./engine/index.js";
import {
  requireUser,
  asRecord,
  requiredString,
  validateNickname,
  sanitizeChatText,
} from "./security/validators.js";

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 50 });

const db = getFirestore();
const ROOM_TTL_MS = 6 * 60 * 60 * 1000;

export interface RoomPlayer {
  uid: string;
  nickname: string;
  avatarId: string;
  seat: number;
  ready: boolean;
  isConnected: boolean;
  temporaryTitle?: string | null;
}

export interface ActiveChallengeInstance {
  instanceId: string;
  roundNumber: number;
  loserUid: string;
  loserNickname: string;
  challenge: ChallengeDefinition;
  status: "pending" | "completed" | "skipped";
  redrawCount: number;
  proofText?: string | null;
  proofMediaUrl?: string | null;
  proofMediaType?: "image" | "voice" | null;
  assignedAtMs: number;
}

export interface RoomDocument {
  hostId: string;
  code: string;
  title: string;
  visibility: "public" | "private";
  maxPlayers: number;
  totalRounds: 1 | 3 | 5;
  direction: Direction;
  challengeMode: ChallengeMode;
  turnTimerSeconds: number;
  status: "waiting" | "playing" | "round_results" | "finished" | "closed";
  players: RoomPlayer[];
  memberIds: string[];
  bannedUids: string[];
  roundNumber: number;
  scores: Record<string, number>;
  losses: Record<string, number>;
  firstFinishes: Record<string, number>;
  usedChallengeIds: string[];
  activeChallenge: ActiveChallengeInstance | null;
  lastLoserUid: string | null;
  expiresAtMs: number;
}

function isRoom(value: unknown): value is RoomDocument {
  return typeof value === "object" && value !== null && Array.isArray((value as RoomDocument).players);
}

function readRoom(snapshot: DocumentSnapshot): RoomDocument {
  if (!snapshot.exists || !isRoom(snapshot.data())) {
    throw new HttpsError("not-found", "القعدة دي مش موجودة أو قفلت");
  }
  return snapshot.data() as RoomDocument;
}

function assertMember(room: RoomDocument, uid: string): void {
  if (!room.memberIds.includes(uid)) {
    throw new HttpsError("permission-denied", "إنت مش عضو في القعدة دي");
  }
}

function readSettings(raw: Record<string, unknown>, hostNickname: string) {
  const maxPlayers = Number(raw.maxPlayers ?? 4);
  const totalRounds = Number(raw.totalRounds ?? 5);
  const direction = (raw.direction ?? "clockwise") as string;
  const visibility = (raw.visibility ?? "private") as string;
  const challengeMode = (raw.challengeMode ?? "every_round") as string;
  const turnTimerSeconds = Number(raw.turnTimerSeconds ?? 45);
  const rawTitle = typeof raw.title === "string" ? raw.title.replace(/[<>]/g, "").trim() : "";

  if (!Number.isInteger(maxPlayers) || maxPlayers < 2 || maxPlayers > 6) {
    throw new HttpsError("invalid-argument", "عدد اللعيبة لازم يكون بين ٢ و ٦");
  }
  if (![1, 3, 5].includes(totalRounds)) {
    throw new HttpsError("invalid-argument", "عدد الجولات لازم يكون ١ أو ٣ أو ٥");
  }
  if (direction !== "clockwise" && direction !== "counterclockwise") {
    throw new HttpsError("invalid-argument", "اتجاه السحب غير صالح");
  }
  if (visibility !== "private" && visibility !== "public") {
    throw new HttpsError("invalid-argument", "نوع القعدة غير صالح");
  }
  if (!["every_round", "end_of_match", "disabled"].includes(challengeMode)) {
    throw new HttpsError("invalid-argument", "نظام الأحكام غير صالح");
  }
  if (!Number.isInteger(turnTimerSeconds) || (turnTimerSeconds !== 0 && (turnTimerSeconds < 15 || turnTimerSeconds > 120))) {
    throw new HttpsError("invalid-argument", "وقت الدور لازم يكون بين ١٥ و ١٢٠ ثانية أو مقفول");
  }

  return {
    title: rawTitle.length >= 2 && rawTitle.length <= 36 ? rawTitle : `قعدة ${hostNickname}`,
    maxPlayers,
    totalRounds: totalRounds as 1 | 3 | 5,
    direction: direction as Direction,
    visibility: visibility as "private" | "public",
    challengeMode: challengeMode as ChallengeMode,
    turnTimerSeconds,
  };
}

function publicRoomEntry(roomId: string, room: RoomDocument) {
  const host = room.players.find((p) => p.uid === room.hostId);
  return {
    roomId,
    code: room.code,
    title: room.title || `قعدة ${host?.nickname ?? "المعلم"}`,
    hostNickname: host?.nickname ?? "المعلم",
    hostAvatar: host?.avatarId ?? "avatar_1",
    playerCount: room.players.length,
    maxPlayers: room.maxPlayers,
    totalRounds: room.totalRounds,
    direction: room.direction,
    challengeMode: room.challengeMode,
    hasSpace: room.players.length < room.maxPlayers,
    status: room.status,
    updatedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  };
}

function writeSystemMessage(tx: Transaction, roomId: string, text: string, eventType = "info"): void {
  const msgRef = db.collection("rooms").doc(roomId).collection("messages").doc();
  tx.set(msgRef, {
    id: msgRef.id,
    senderUid: "system",
    senderNickname: "قهوة الشايب",
    senderAvatar: "system",
    type: "system",
    eventType,
    text,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Canonical round persistence:
 * - Secret authoritative state -> `rooms/{roomId}/secret/round` (Admin SDK only)
 * - Sanitized public view -> `rooms/{roomId}/state/current` (Room members only)
 * - Per-player private hands -> `rooms/{roomId}/hands/{uid}` (Owner only)
 * Eliminates duplicate writes to `gameState/current` and `players/{uid}` subdocs.
 */
function writeRound(tx: Transaction, roomId: string, round: RoundState, roundNumber: number): void {
  const root = db.collection("rooms").doc(roomId);
  const pub = publicView(round);
  tx.set(root.collection("secret").doc("round"), { state: round });
  tx.set(root.collection("state").doc("current"), {
    ...pub,
    roundNumber,
    turnDeadline: pub.turnDeadlineMs ? Timestamp.fromMillis(pub.turnDeadlineMs) : null,
    updatedAt: FieldValue.serverTimestamp(),
  });

  for (const playerId of round.playerOrder) {
    tx.set(root.collection("hands").doc(playerId), {
      cards: round.hands[playerId],
      roundId: round.id,
      version: round.version,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

function computeRoundCompletion(
  room: RoomDocument,
  round: RoundState,
): Pick<
  RoomDocument,
  "scores" | "losses" | "firstFinishes" | "status" | "activeChallenge" | "usedChallengeIds" | "lastLoserUid"
> {
  const scores = { ...room.scores };
  const losses = { ...room.losses };
  const firstFinishes = { ...room.firstFinishes };
  const points = roundPoints(round.finishOrder);

  for (const player of room.players) {
    scores[player.uid] = (scores[player.uid] ?? 0) + (points[player.uid] ?? 0);
  }
  const loserUid = round.loserId!;
  losses[loserUid] = (losses[loserUid] ?? 0) + 1;
  const winnerUid = round.finishOrder[0];
  if (winnerUid) {
    firstFinishes[winnerUid] = (firstFinishes[winnerUid] ?? 0) + 1;
  }

  const isMatchOver = room.roundNumber >= room.totalRounds;
  const shouldAssignChallenge =
    room.challengeMode === "every_round" ||
    (room.challengeMode === "end_of_match" && isMatchOver);

  let activeChallenge: ActiveChallengeInstance | null = null;
  const usedChallengeIds = [...(room.usedChallengeIds ?? [])];

  if (shouldAssignChallenge) {
    const picked = selectRandomChallenge(usedChallengeIds);
    usedChallengeIds.push(picked.id);
    const loserPlayer = room.players.find((p) => p.uid === loserUid);
    activeChallenge = {
      instanceId: `ch_round_${room.roundNumber}_${Date.now()}`,
      roundNumber: room.roundNumber,
      loserUid,
      loserNickname: loserPlayer?.nickname ?? "اللاعب",
      challenge: picked,
      status: "pending",
      redrawCount: 0,
      proofText: null,
      proofMediaUrl: null,
      proofMediaType: null,
      assignedAtMs: Date.now(),
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

// ============================================================================
// 1. createRoom
// ============================================================================
export const createRoom = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const nickname = validateNickname(data.nickname);
  const avatarId = typeof data.avatarId === "string" && data.avatarId.trim() ? data.avatarId.trim() : "avatar_1";
  const settings = readSettings(data, nickname);
  const roomRef = db.collection("rooms").doc();

  for (let attempt = 0; attempt < 12; attempt++) {
    const code = generateRoomCode(6);
    const codeRef = db.collection("roomCodes").doc(code);
    const room: RoomDocument = {
      hostId: uid,
      code,
      ...settings,
      status: "waiting",
      roundNumber: 0,
      players: [{ uid, nickname, avatarId, seat: 0, ready: true, isConnected: true }],
      memberIds: [uid],
      bannedUids: [],
      scores: { [uid]: 0 },
      losses: { [uid]: 0 },
      firstFinishes: { [uid]: 0 },
      usedChallengeIds: [],
      activeChallenge: null,
      lastLoserUid: null,
      expiresAtMs: Date.now() + ROOM_TTL_MS,
    };

    const claimed = await db.runTransaction(async (tx) => {
      const existing = await tx.get(codeRef);
      if (existing.exists) return false;
      tx.create(codeRef, { roomId: roomRef.id, code, createdAt: FieldValue.serverTimestamp() });
      tx.create(roomRef, {
        ...room,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      writeSystemMessage(tx, roomRef.id, `${nickname} فتح القعدة! مستنيين باقي الشلة ☕`, "room_created");
      if (room.visibility === "public") {
        tx.set(db.collection("publicRooms").doc(roomRef.id), publicRoomEntry(roomRef.id, room));
      }
      return true;
    });

    if (claimed) return { roomId: roomRef.id, code };
  }
  throw new HttpsError("resource-exhausted", "مش قادرين نطلع كود قعدة جديد دلوقتي، جرّب تاني");
});

// ============================================================================
// 2. joinRoomByCode & joinRoom
// ============================================================================
export const joinRoomByCode = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const nickname = validateNickname(data.nickname);
  const avatarId = typeof data.avatarId === "string" && data.avatarId.trim() ? data.avatarId.trim() : "avatar_1";

  let targetRoomId: string | undefined;
  let normalizedCode = "";

  if (typeof data.roomId === "string" && data.roomId.trim().length > 0) {
    targetRoomId = data.roomId.trim();
  } else {
    normalizedCode = requiredString(data.code, "code", 8).toUpperCase();
    const codeSnap = await db.collection("roomCodes").doc(normalizedCode).get();
    targetRoomId = codeSnap.data()?.roomId as string | undefined;
  }

  if (!targetRoomId) {
    throw new HttpsError("not-found", "كود القعدة ده مش موجود، اتأكد من الكود يا نجم");
  }

  const ref = db.collection("rooms").doc(targetRoomId);
  let roomCode = normalizedCode;

  await db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(ref));
    roomCode = room.code;
    // Joining a private room requires its invite code. A roomId is only
    // sufficient for public discovery or for an existing member reconnecting.
    if (typeof data.roomId === "string" && room.visibility === "private" && !room.memberIds.includes(uid)) {
      throw new HttpsError("permission-denied", "القعدة الخاصة لازم تدخلها بالكود");
    }
    if ((room.bannedUids ?? []).includes(uid)) {
      throw new HttpsError("permission-denied", "صاحب القعدة خرجك من القعدة دي");
    }
    if (room.memberIds.includes(uid)) {
      const players = room.players.map((p) =>
        p.uid === uid
          ? {
              ...p,
              isConnected: true,
              nickname: room.status === "waiting" ? nickname : p.nickname,
              avatarId: room.status === "waiting" ? avatarId : p.avatarId,
            }
          : p,
      );
      tx.update(ref, { players, updatedAt: FieldValue.serverTimestamp() });
      return;
    }
    if (room.status !== "waiting") {
      throw new HttpsError("failed-precondition", "اللعب بدأ خلاص في القعدة دي!");
    }
    if (room.players.length >= room.maxPlayers) {
      throw new HttpsError("resource-exhausted", "القعدة كومبليت ومفيش كراسي فاضية!");
    }

    const usedSeats = new Set(room.players.map((p) => p.seat));
    let seat = 0;
    while (usedSeats.has(seat)) seat++;

    const players: RoomPlayer[] = [
      ...room.players,
      { uid, nickname, avatarId, seat, ready: false, isConnected: true },
    ];
    const memberIds = [...room.memberIds, uid];
    const next: RoomDocument = {
      ...room,
      players,
      memberIds,
      scores: { ...room.scores, [uid]: 0 },
      losses: { ...room.losses, [uid]: 0 },
      firstFinishes: { ...room.firstFinishes, [uid]: 0 },
    };

    tx.update(ref, {
      players,
      memberIds,
      scores: next.scores,
      losses: next.losses,
      firstFinishes: next.firstFinishes,
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeSystemMessage(tx, targetRoomId!, `${nickname} دخل القعدة! منور يا معلم 🔥`, "player_joined");
    if (room.visibility === "public") {
      tx.set(db.collection("publicRooms").doc(targetRoomId!), publicRoomEntry(targetRoomId!, next));
    }
  });

  return { roomId: targetRoomId, code: roomCode };
});

export const joinRoom = joinRoomByCode;

// ============================================================================
// 3. leaveRoom & kickPlayer
// ============================================================================
export const leaveRoom = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const roomRef = db.collection("rooms").doc(roomId);

  await db.runTransaction(async (tx) => {
    const roomSnap = await tx.get(roomRef);
    if (!roomSnap.exists) return;
    const room = readRoom(roomSnap);
    if (!room.memberIds.includes(uid)) return;

    const departing = room.players.find((p) => p.uid === uid);

    if (room.status === "waiting" || room.status === "finished") {
      const remainingPlayers = room.players.filter((p) => p.uid !== uid);
      const remainingMemberIds = room.memberIds.filter((id) => id !== uid);

      if (remainingPlayers.length === 0) {
        tx.update(roomRef, {
          status: "closed",
          players: [],
          memberIds: [],
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.delete(db.collection("publicRooms").doc(roomId));
        tx.delete(db.collection("roomCodes").doc(room.code));
        return;
      }

      const sortedBySeat = [...remainingPlayers].sort((a, b) => a.seat - b.seat);
      const nextHostId = room.hostId === uid ? sortedBySeat[0]!.uid : room.hostId;
      const playersWithHostReady = remainingPlayers.map((p) =>
        p.uid === nextHostId ? { ...p, ready: true } : p,
      );
      const next: RoomDocument = {
        ...room,
        hostId: nextHostId,
        players: playersWithHostReady,
        memberIds: remainingMemberIds,
      };

      tx.update(roomRef, {
        hostId: nextHostId,
        players: playersWithHostReady,
        memberIds: remainingMemberIds,
        updatedAt: FieldValue.serverTimestamp(),
      });
      writeSystemMessage(
        tx,
        roomId,
        `${departing?.nickname ?? "لاعب"} قام من القعدة${room.hostId === uid ? ` وبقى ${sortedBySeat[0]!.nickname} هو صاحب القعدة` : ""}`,
        "player_left",
      );
      if (room.visibility === "public" && room.status === "waiting") {
        tx.set(db.collection("publicRooms").doc(roomId), publicRoomEntry(roomId, next));
      }
      return;
    }

    const connectedOthers = room.players.filter((p) => p.uid !== uid && p.isConnected);
    const fallbackOthers = room.players.filter((p) => p.uid !== uid);
    const nextHostId =
      room.hostId === uid
        ? (connectedOthers[0]?.uid ?? fallbackOthers[0]?.uid ?? room.hostId)
        : room.hostId;
    const players = room.players.map((p) =>
      p.uid === uid ? { ...p, isConnected: false } : p,
    );
    tx.update(roomRef, {
      hostId: nextHostId,
      players,
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeSystemMessage(
      tx,
      roomId,
      `${departing?.nickname ?? "لاعب"} خرج مؤقتاً والنظام هيسحب مكانه لو دوره اتأخر`,
      "player_disconnected",
    );
  });

  return { ok: true };
});

export const kickPlayer = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const targetUid = requiredString(data.targetUid, "targetUid");
  if (uid === targetUid) {
    throw new HttpsError("invalid-argument", "مينفعش تطرد نفسك!");
  }
  const roomRef = db.collection("rooms").doc(roomId);

  await db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    if (room.hostId !== uid) {
      throw new HttpsError("permission-denied", "صاحب القعدة بس هو اللي يقدر يخرج لاعب");
    }
    if (room.status !== "waiting") {
      throw new HttpsError("failed-precondition", "مينفعش تخرج حد بعد بداية الجولة");
    }
    const target = room.players.find((p) => p.uid === targetUid);
    if (!target) return;
    const players = room.players.filter((p) => p.uid !== targetUid);
    const memberIds = room.memberIds.filter((id) => id !== targetUid);
    const bannedUids = [...new Set([...(room.bannedUids ?? []), targetUid])];
    const next: RoomDocument = { ...room, players, memberIds, bannedUids };

    tx.update(roomRef, {
      players,
      memberIds,
      bannedUids,
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeSystemMessage(tx, roomId, `تم استبعاد ${target.nickname} من القعدة`, "player_kicked");
    if (room.visibility === "public") {
      tx.set(db.collection("publicRooms").doc(roomId), publicRoomEntry(roomId, next));
    }
  });

  return { ok: true };
});

// ============================================================================
// 4. setPlayerReady & setReady
// ============================================================================
export const setPlayerReady = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  if (typeof data.ready !== "boolean") {
    throw new HttpsError("invalid-argument", "قيمة الجاهزية غير صالحة");
  }
  const ready = data.ready;
  const roomRef = db.collection("rooms").doc(roomId);

  await db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    assertMember(room, uid);
    if (room.status !== "waiting") {
      throw new HttpsError("failed-precondition", "اللعبة بدأت خلاص");
    }
    const players = room.players.map((p) => (p.uid === uid ? { ...p, ready } : p));
    const caller = room.players.find((p) => p.uid === uid);
    tx.update(roomRef, { players, updatedAt: FieldValue.serverTimestamp() });
    if (ready && caller) {
      writeSystemMessage(tx, roomId, `${caller.nickname} جاهز للعب! ✅`, "player_ready");
    }
  });

  return { ok: true };
});

export const setReady = setPlayerReady;

// ============================================================================
// 5. updateRoomSettings
// ============================================================================
export const updateRoomSettings = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const roomRef = db.collection("rooms").doc(roomId);

  await db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    assertMember(room, uid);
    if (room.hostId !== uid) {
      throw new HttpsError("permission-denied", "صاحب القعدة بس هو اللي يقدر يغير الإعدادات");
    }
    if (room.status !== "waiting") {
      throw new HttpsError("failed-precondition", "مينفعش تغير الإعدادات بعد ما اللعب يبدأ");
    }
    const host = room.players.find((p) => p.uid === uid);
    const settings = readSettings(data, host?.nickname ?? "المعلم");
    if (settings.maxPlayers < room.players.length) {
      throw new HttpsError("failed-precondition", "عدد اللعيبة الحالي أكبر من الحد الأقصى الجديد");
    }
    const next: RoomDocument = { ...room, ...settings };
    tx.update(roomRef, { ...settings, updatedAt: FieldValue.serverTimestamp() });
    if (settings.visibility === "public") {
      tx.set(db.collection("publicRooms").doc(roomId), publicRoomEntry(roomId, next));
    } else {
      tx.delete(db.collection("publicRooms").doc(roomId));
    }
    writeSystemMessage(tx, roomId, "صاحب القعدة حدّث إعدادات اللعب ⚙️", "settings_updated");
  });

  return { ok: true };
});

// ============================================================================
// 6. startGame & startMatch
// ============================================================================
export const startGame = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const roomRef = db.collection("rooms").doc(roomId);

  await db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    assertMember(room, uid);
    if (room.hostId !== uid) {
      throw new HttpsError("permission-denied", "صاحب القعدة بس هو اللي يقدر يبدأ اللعب");
    }
    if (room.status !== "waiting") {
      throw new HttpsError("failed-precondition", "اللعبة شغالة بالفعل");
    }
    if (room.players.length < 2 || !room.players.every((p) => p.ready || p.uid === room.hostId)) {
      throw new HttpsError("failed-precondition", "لازم على الأقل ٢ لعيبة وكلهم يكونوا جاهزين");
    }

    const playerOrder = [...room.players].sort((a, b) => a.seat - b.seat).map((p) => p.uid);
    const round = makeRound(playerOrder, {
      roundNumber: 1,
      direction: room.direction,
      turnTimerSeconds: room.turnTimerSeconds ?? 45,
      shuffleInitialFinishTies: true,
    });
    const updated: RoomDocument = { ...room, roundNumber: 1, activeChallenge: null };
    const results =
      round.status === "finished"
        ? computeRoundCompletion(updated, round)
        : { status: "playing" as const, activeChallenge: null };

    tx.update(roomRef, {
      roundNumber: 1,
      ...results,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (room.visibility === "public") {
      tx.delete(db.collection("publicRooms").doc(roomId));
    }
    writeRound(tx, roomId, round, 1);
    writeSystemMessage(tx, roomId, "اللعبة بدأت! ٤٩ ورقة اتوزعوا والأجواز اتشالت.. مين هيلبس الشايب؟ 🃏🔥", "match_started");
  });

  return { ok: true };
});

export const startMatch = startGame;

// ============================================================================
// 7. drawCard & claimTurnTimeout
// ============================================================================
export const drawCard = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const actionId = requiredString(data.actionId, "actionId", 80);
  if (!/^[a-zA-Z0-9_-]{8,80}$/.test(actionId)) {
    throw new HttpsError("invalid-argument", "معرّف الحركة غير صالح");
  }
  const cardIndex = data.cardIndex ?? data.selectedCardPosition;
  const expectedVersion = data.expectedVersion ?? data.expectedStateVersion;
  if (!Number.isSafeInteger(cardIndex) || !Number.isSafeInteger(expectedVersion)) {
    throw new HttpsError("invalid-argument", "رقم الورقة أو إصدار الدور غير صالح");
  }

  const roomRef = db.collection("rooms").doc(roomId);
  const secretRef = roomRef.collection("secret").doc("round");
  const actionRef = roomRef.collection("actions").doc(actionId);

  const result = await db.runTransaction(async (tx) => {
    const [existing, roomSnap, secretSnap] = await Promise.all([
      tx.get(actionRef),
      tx.get(roomRef),
      tx.get(secretRef),
    ]);
    const room = readRoom(roomSnap);
    assertMember(room, uid);

    if (existing.exists) {
      if (existing.data()?.uid !== uid) {
        throw new HttpsError("permission-denied", "الحركة دي تخص لاعب تاني");
      }
      return { applied: false, alreadyApplied: true };
    }
    if (room.status !== "playing") {
      throw new HttpsError("failed-precondition", "الجولة مش شغالة دلوقتي");
    }
    const previous = secretSnap.data()?.state as RoundState | undefined;
    if (!previous) {
      throw new HttpsError("failed-precondition", "بيانات الجولة مش موجودة");
    }

    let next: RoundState;
    try {
      next = executeDraw(previous, {
        actorId: uid,
        cardIndex: cardIndex as number,
        expectedVersion: expectedVersion as number,
      });
    } catch (error) {
      if (error instanceof GameRuleError) {
        throw new HttpsError("failed-precondition", error.message);
      }
      throw error;
    }

    writeRound(tx, roomId, next, room.roundNumber);

    const actorName = room.players.find((p) => p.uid === uid)?.nickname ?? "لاعب";
    const targetName =
      room.players.find((p) => p.uid === next.lastMove?.targetId)?.nickname ?? "لاعب";

    if ((next.lastMove?.pairsRemoved ?? 0) > 0) {
      writeSystemMessage(tx, roomId, `عاش! ${actorName} سحب من ${targetName} ونزل جوز 🎯`, "pair_matched");
    }

    for (const escapedId of next.lastMove?.finishedPlayerIds ?? []) {
      const escapedName = room.players.find((p) => p.uid === escapedId)?.nickname ?? "لاعب";
      writeSystemMessage(tx, roomId, `${escapedName} صفّى ورقه وفلت من الشايب! 🏃‍♂️✨`, "player_escaped");
    }

    if (next.status === "finished") {
      const completion = computeRoundCompletion(room, next);
      const loserName = room.players.find((p) => p.uid === next.loserId)?.nickname ?? "لاعب";
      tx.update(roomRef, {
        ...completion,
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (completion.activeChallenge) {
        tx.set(
          roomRef.collection("challenges").doc(completion.activeChallenge.instanceId),
          completion.activeChallenge,
        );
      }
      writeSystemMessage(
        tx,
        roomId,
        `الشايب لبس في ${loserName}! 👴👑 ${
          completion.activeChallenge ? `والحكم عليه: «${completion.activeChallenge.challenge.title}»` : ""
        }`,
        "round_finished",
      );
    }

    tx.create(actionRef, {
      uid,
      roundId: next.id,
      version: next.version,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      applied: true,
      alreadyApplied: false,
      version: next.version,
      pairsRemoved: next.lastMove?.pairsRemoved ?? 0,
      roundFinished: next.status === "finished",
    };
  });

  return result;
});

export const claimTurnTimeout = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const expectedVersion = Number(data.expectedVersion ?? -1);
  if (!Number.isSafeInteger(expectedVersion) || expectedVersion < 0) {
    throw new HttpsError("invalid-argument", "إصدار الدور غير صالح");
  }

  const roomRef = db.collection("rooms").doc(roomId);
  const secretRef = roomRef.collection("secret").doc("round");

  return db.runTransaction(async (tx) => {
    const [roomSnap, secretSnap] = await Promise.all([tx.get(roomRef), tx.get(secretRef)]);
    const room = readRoom(roomSnap);
    assertMember(room, uid);
    if (room.status !== "playing") {
      return { applied: false, reason: "not_playing" };
    }
    const previous = secretSnap.data()?.state as RoundState | undefined;
    if (!previous || previous.version !== expectedVersion) {
      return { applied: false, reason: "version_changed" };
    }
    const nowMs = Date.now();
    if (!previous.turnDeadlineMs || nowMs < previous.turnDeadlineMs - 1000) {
      return { applied: false, reason: "deadline_not_reached" };
    }

    const timedOutUid = previous.currentPlayerId!;
    const timedOutName = room.players.find((p) => p.uid === timedOutUid)?.nickname ?? "لاعب";
    const next = autoDrawOnTimeout(previous, expectedVersion, nowMs);

    writeRound(tx, roomId, next, room.roundNumber);
    writeSystemMessage(tx, roomId, `وقت ${timedOutName} خلص! النظام سحب له ورقة عشوائية ⏱️`, "turn_timeout");

    if (next.status === "finished") {
      const completion = computeRoundCompletion(room, next);
      const loserName = room.players.find((p) => p.uid === next.loserId)?.nickname ?? "لاعب";
      tx.update(roomRef, { ...completion, updatedAt: FieldValue.serverTimestamp() });
      if (completion.activeChallenge) {
        tx.set(
          roomRef.collection("challenges").doc(completion.activeChallenge.instanceId),
          completion.activeChallenge,
        );
      }
      writeSystemMessage(tx, roomId, `الشايب لبس في ${loserName}! 👴👑`, "round_finished");
    }

    return { applied: true, version: next.version };
  });
});

// ============================================================================
// 8. getRoomState
// ============================================================================
export const getRoomState = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const roomRef = db.collection("rooms").doc(roomId);

  const [roomSnap, publicSnap, handSnap] = await Promise.all([
    roomRef.get(),
    roomRef.collection("state").doc("current").get(),
    roomRef.collection("hands").doc(uid).get(),
  ]);

  const room = readRoom(roomSnap);
  assertMember(room, uid);
  const standings = rankMatchPlayers(
    room.players.map((p) => p.uid),
    room.scores,
    room.losses,
    room.firstFinishes,
  );

  return {
    room,
    publicRound: publicSnap.exists ? publicSnap.data() : null,
    ownHand: handSnap.exists ? handSnap.data()?.cards ?? [] : [],
    standings,
  };
});

export const getMatchStandings = getRoomState;

// ============================================================================
// 9. advanceToNextRound & nextRound
// ============================================================================
export const advanceToNextRound = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const roomRef = db.collection("rooms").doc(roomId);

  await db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    assertMember(room, uid);
    if (room.hostId !== uid) {
      throw new HttpsError("permission-denied", "صاحب القعدة بس هو اللي يبدأ الجولة الجديدة");
    }
    if (room.status !== "round_results" || room.roundNumber >= room.totalRounds) {
      throw new HttpsError("failed-precondition", "مفيش جولة تانية متاحة");
    }

    const nextNumber = room.roundNumber + 1;
    const playerOrder = [...room.players].sort((a, b) => a.seat - b.seat).map((p) => p.uid);
    const round = makeRound(playerOrder, {
      roundNumber: nextNumber,
      direction: room.direction,
      turnTimerSeconds: room.turnTimerSeconds ?? 45,
      shuffleInitialFinishTies: true,
    });
    const updated: RoomDocument = { ...room, roundNumber: nextNumber, activeChallenge: null };
    const results =
      round.status === "finished"
        ? computeRoundCompletion(updated, round)
        : { status: "playing" as const, activeChallenge: null };

    tx.update(roomRef, {
      roundNumber: nextNumber,
      ...results,
      updatedAt: FieldValue.serverTimestamp(),
    });
    writeRound(tx, roomId, round, nextNumber);
    writeSystemMessage(tx, roomId, `الجولة رقم ${nextNumber} بدأت! ركّز يا معلم 🃏`, "round_started");
  });

  return { ok: true };
});

export const nextRound = advanceToNextRound;

// ============================================================================
// 10, 11, 12. assignChallenge, completeChallenge, redrawChallenge, handleChallengeAction
// ============================================================================
export const assignChallenge = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const roomRef = db.collection("rooms").doc(roomId);

  return db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    assertMember(room, uid);
    if (room.activeChallenge) {
      return { activeChallenge: room.activeChallenge };
    }
    const loserUid = room.lastLoserUid ?? uid;
    const loserPlayer = room.players.find((p) => p.uid === loserUid);
    const used = [...(room.usedChallengeIds ?? [])];
    const picked = selectRandomChallenge(used);
    used.push(picked.id);

    const instance: ActiveChallengeInstance = {
      instanceId: `ch_round_${room.roundNumber}_${Date.now()}`,
      roundNumber: room.roundNumber,
      loserUid,
      loserNickname: loserPlayer?.nickname ?? "اللاعب",
      challenge: picked,
      status: "pending",
      redrawCount: 0,
      proofText: null,
      proofMediaUrl: null,
      proofMediaType: null,
      assignedAtMs: Date.now(),
    };

    tx.update(roomRef, {
      activeChallenge: instance,
      usedChallengeIds: used,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(roomRef.collection("challenges").doc(instance.instanceId), instance);
    return { activeChallenge: instance };
  });
});

async function runChallengeTransition(
  uid: string,
  roomId: string,
  action: "complete" | "skip" | "redraw",
  data: Record<string, unknown>,
) {
  const roomRef = db.collection("rooms").doc(roomId);
  return db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    assertMember(room, uid);
    const current = room.activeChallenge;
    if (!current) {
      throw new HttpsError("failed-precondition", "مفيش حكم مطلوب دلوقتي");
    }
    if (current.loserUid !== uid && room.hostId !== uid) {
      throw new HttpsError("permission-denied", "اللاعب اللي لبس الشايب بس هو اللي ينفذ أو يغير الحكم");
    }

    if (action === "redraw") {
      if (current.redrawCount >= 2) {
        throw new HttpsError("failed-precondition", "استنفذت محاولات تغيير الحكم في الجولة دي!");
      }
      const usedChallengeIds = [...(room.usedChallengeIds ?? []), current.challenge.id];
      const nextChallenge = selectRandomChallenge(usedChallengeIds);
      const updatedChallenge: ActiveChallengeInstance = {
        ...current,
        challenge: nextChallenge,
        redrawCount: current.redrawCount + 1,
      };
      tx.update(roomRef, {
        activeChallenge: updatedChallenge,
        usedChallengeIds: [...usedChallengeIds, nextChallenge.id],
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(roomRef.collection("challenges").doc(current.instanceId), updatedChallenge);
      writeSystemMessage(
        tx,
        roomId,
        `${current.loserNickname} غيّر الحكم.. الحكم الجديد: «${nextChallenge.title}» 🎲`,
        "challenge_redrawn",
      );
      return { activeChallenge: updatedChallenge };
    }

    const proofText =
      typeof data.proofText === "string" && data.proofText.trim()
        ? data.proofText.replace(/[<>]/g, "").trim().slice(0, 300)
        : null;
    const proofMediaUrl =
      typeof data.proofMediaUrl === "string" && data.proofMediaUrl.trim()
        ? data.proofMediaUrl.trim()
        : null;
    const proofMediaType =
      data.proofMediaType === "image" || data.proofMediaType === "voice"
        ? data.proofMediaType
        : null;

    const updatedChallenge: ActiveChallengeInstance = {
      ...current,
      status: action === "complete" ? "completed" : "skipped",
      proofText,
      proofMediaUrl,
      proofMediaType,
    };

    let players = room.players;
    if (action === "complete" && current.challenge.id === "ch_21") {
      players = room.players.map((p) =>
        p.uid === current.loserUid ? { ...p, temporaryTitle: "شايب المعمورة 👴" } : p,
      );
    }

    tx.update(roomRef, {
      players,
      activeChallenge: updatedChallenge,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(roomRef.collection("challenges").doc(current.instanceId), updatedChallenge);

    if (action === "complete") {
      writeSystemMessage(
        tx,
        roomId,
        `${current.loserNickname} نفّذ الحكم «${current.challenge.title}» برجولة! 👏🔥${
          proofText ? `\n💬 «${proofText}»` : ""
        }`,
        "challenge_completed",
      );
    } else {
      writeSystemMessage(
        tx,
        roomId,
        `${current.loserNickname} عدّى الحكم المرة دي 😅`,
        "challenge_skipped",
      );
    }

    return { activeChallenge: updatedChallenge };
  });
}

export const completeChallenge = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const action = data.skip === true ? "skip" : "complete";
  return runChallengeTransition(uid, roomId, action, data);
});

export const redrawChallenge = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  return runChallengeTransition(uid, roomId, "redraw", data);
});

export const handleChallengeAction = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const action = requiredString(data.action, "action") as "complete" | "skip" | "redraw";
  if (!["complete", "skip", "redraw"].includes(action)) {
    throw new HttpsError("invalid-argument", "إجراء الحكم غير صالح");
  }
  return runChallengeTransition(uid, roomId, action, data);
});

// ============================================================================
// 13. sendRoomMessage
// ============================================================================
export const sendRoomMessage = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const text = sanitizeChatText(data.text, 300);
  const type = data.type ?? "user";
  if (type !== "user" && type !== "reaction") {
    throw new HttpsError("invalid-argument", "نوع الرسالة غير متاح حالياً");
  }
  // Evidence must use the protected challenge upload flow, not user-provided
  // URLs. Never allow arbitrary attachment URLs through chat callables.
  if (data.attachmentUrl != null || data.attachmentType != null) {
    throw new HttpsError("invalid-argument", "ارفع الإثبات من شاشة الحكم المخصصة");
  }

  const roomRef = db.collection("rooms").doc(roomId);
  const rateRef = roomRef.collection("chatRate").doc(uid);
  const now = Date.now();
  const msgId = await db.runTransaction(async (tx) => {
    const [roomSnap, rateSnap] = await Promise.all([tx.get(roomRef), tx.get(rateRef)]);
    const room = readRoom(roomSnap);
    assertMember(room, uid);
    const lastSentAtMs = rateSnap.data()?.lastSentAtMs;
    if (typeof lastSentAtMs === "number" && now - lastSentAtMs < 750) {
      throw new HttpsError("resource-exhausted", "بالراحة يا معلم، استنى لحظة بين الرسايل");
    }
    const sender = room.players.find((p) => p.uid === uid);
    if (!sender) throw new HttpsError("permission-denied", "اللاعب مش موجود في القعدة");
    const msgRef = roomRef.collection("messages").doc();
    tx.create(msgRef, {
      id: msgRef.id,
      senderUid: uid,
      senderNickname: sender.nickname,
      senderAvatar: sender.avatarId,
      type,
      text,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(rateRef, { lastSentAtMs: now, updatedAt: FieldValue.serverTimestamp() });
    return msgRef.id;
  });
  return { messageId: msgId };
});

// ============================================================================
// 14. restartMatch & rematchRoom
// ============================================================================
export const restartMatch = onCall(async (request) => {
  const uid = requireUser(request.auth);
  const data = asRecord(request.data);
  const roomId = requiredString(data.roomId, "roomId");
  const roomRef = db.collection("rooms").doc(roomId);

  await db.runTransaction(async (tx) => {
    const room = readRoom(await tx.get(roomRef));
    assertMember(room, uid);
    if (room.hostId !== uid) {
      throw new HttpsError("permission-denied", "صاحب القعدة بس هو اللي يقدر يعيد الماتش");
    }
    if (room.status !== "finished") {
      throw new HttpsError("failed-precondition", "مينفعش تعيد الماتش قبل ما يخلص");
    }
    const scores: Record<string, number> = {};
    const losses: Record<string, number> = {};
    const firstFinishes: Record<string, number> = {};
    const players = room.players.map((p) => {
      scores[p.uid] = 0;
      losses[p.uid] = 0;
      firstFinishes[p.uid] = 0;
      return { ...p, ready: true, temporaryTitle: null };
    });

    tx.update(roomRef, {
      status: "waiting",
      roundNumber: 0,
      players,
      scores,
      losses,
      firstFinishes,
      activeChallenge: null,
      lastLoserUid: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    // Do not serve stale finished-round cards after a rematch reset.
    if (room.visibility === "public") {
      tx.set(db.collection("publicRooms").doc(roomId),
        publicRoomEntry(roomId, { ...room, status: "waiting", roundNumber: 0, players }));
    }
    tx.delete(roomRef.collection("state").doc("current"));
    tx.delete(roomRef.collection("secret").doc("round"));
    for (const player of room.players) {
      tx.delete(roomRef.collection("hands").doc(player.uid));
    }
    writeSystemMessage(tx, roomId, "هنعيدها من الأول! القعدة رجعت جاهزة لماتش جديد 🔄🔥", "rematch_ready");
  });

  return { ok: true };
});

export const rematchRoom = restartMatch;

export const seedChallengesCatalog = onCall(async (request) => {
  requireUser(request.auth);
  // Catalog initialization is an administrative action, not a player action.
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "إضافة الأحكام متاحة للمشرف فقط");
  }
  const batch = db.batch();
  for (const ch of EGYPTIAN_CHALLENGES) {
    batch.set(db.collection("challenges").doc(ch.id), ch, { merge: true });
  }
  await batch.commit();
  return { seededCount: EGYPTIAN_CHALLENGES.length };
});

export const cleanupExpiredRooms = onSchedule("every 60 minutes", async () => {
  const cutoff = Date.now();
  const expiredSnap = await db
    .collection("rooms")
    .where("expiresAtMs", "<=", cutoff)
    .limit(100)
    .get();

  if (expiredSnap.empty) return;
  const batch = db.batch();
  for (const doc of expiredSnap.docs) {
    const data = doc.data() as Partial<RoomDocument>;
    if (data.code) {
      batch.delete(db.collection("roomCodes").doc(data.code));
    }
    batch.delete(db.collection("publicRooms").doc(doc.id));
    batch.update(doc.ref, {
      status: "closed",
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
});
