import { createDeck, DECK_SIZE } from "./deck.ts";
import { dealCards } from "./deal.ts";
import { removePairs } from "./pairing.ts";
import { type RandomInt, secureRandomInt, shuffle } from "./shuffle.ts";
import { nextActive } from "./turns.ts";
import {
  GameRuleError,
  RANKS,
  SUITS,
  type Card,
  type Direction,
  type DrawAction,
  type PlayerId,
  type PublicRoundState,
  type RoundState,
  type Suit,
} from "./types.ts";

function assertPlayers(players: readonly PlayerId[]): void {
  if (players.length < 2 || players.length > 6) {
    throw new GameRuleError("player_count", "A room must have 2–6 players");
  }
  if (
    players.some((id) => typeof id !== "string" || id.length < 1) ||
    new Set(players).size !== players.length
  ) {
    throw new GameRuleError("invalid_players", "Player IDs must be unique and nonempty");
  }
}

export interface StartRoundOptions {
  roundNumber?: number;
  order?: readonly PlayerId[];
  direction?: Direction;
  oldKingSuit?: Suit;
  kingSuit?: Suit;
  id?: string;
  turnTimerSeconds?: number;
  nowMs?: number;
  rand?: RandomInt;
  shuffleInitialFinishTies?: boolean;
}

/**
 * Canonical round initializer unifying Archive A (`startRound`) and Archive B (`makeRound`).
 * - Generates and shuffles the 49-card Egyptian deck using `rand` (defaults to `secureRandomInt`).
 * - Deals round-robin via `dealCards`.
 * - Resolves initial pairs via `removePairs`.
 * - Rotates starting turn by `roundNumber` (when > 1) so no seat/host is permanently favored.
 */
export function makeRound(
  playerOrder: readonly PlayerId[],
  options: StartRoundOptions = {},
): RoundState {
  assertPlayers(playerOrder);
  const direction = options.direction ?? "clockwise";
  if (direction !== "clockwise" && direction !== "counterclockwise") {
    throw new GameRuleError("direction", "Invalid draw direction");
  }
  const rand = options.rand ?? secureRandomInt;
  const kingSuit = options.oldKingSuit ?? options.kingSuit ?? "hearts";
  const roundNumber = options.roundNumber ?? 1;

  const shuffledDeck = shuffle(createDeck(kingSuit), rand);
  const dealt = dealCards(shuffledDeck, playerOrder.length);

  const mutableHands: Record<PlayerId, Card[]> = {};
  const discarded: Card[] = [];
  const initialEmpty: PlayerId[] = [];

  playerOrder.forEach((p, idx) => {
    const result = removePairs(dealt[idx]!);
    mutableHands[p] = result.hand;
    discarded.push(...result.discarded);
    if (result.hand.length === 0) {
      initialEmpty.push(p);
    }
  });

  // Archive A supports shuffling simultaneous initial finishers to prevent host/seat bias;
  // Archive B uses deterministic seating order when shuffleInitialFinishTies is false.
  const finishOrder: PlayerId[] = options.shuffleInitialFinishTies
    ? shuffle(initialEmpty, rand)
    : [...initialEmpty];

  const active = playerOrder.filter((p) => mutableHands[p]!.length > 0);
  const isFinished = active.length === 1;
  if (isFinished) {
    finishOrder.push(active[0]!);
  }

  // Rotate starting turn by roundNumber so Seat 0 (the host) is never permanently favored
  let firstActivePlayer: PlayerId | null = null;
  if (!isFinished) {
    const startIdx = Math.max(0, roundNumber - 1) % playerOrder.length;
    for (let k = 0; k < playerOrder.length; k++) {
      const candidate = playerOrder[(startIdx + k) % playerOrder.length]!;
      if (mutableHands[candidate]!.length > 0) {
        firstActivePlayer = candidate;
        break;
      }
    }
  }

  const timerSecs = options.turnTimerSeconds ?? 45;
  const nowMs = options.nowMs ?? Date.now();

  const state: RoundState = {
    id: options.id ?? crypto.randomUUID(),
    playerOrder: [...playerOrder],
    direction,
    hands: mutableHands,
    discarded,
    finishOrder,
    currentPlayerId: firstActivePlayer,
    turnNumber: 0,
    version: 0,
    status: isFinished ? "finished" : "playing",
    phase: isFinished ? "ROUND_COMPLETED" : "WAITING_FOR_DRAW",
    turnTimerSeconds: timerSecs,
    turnDeadlineMs: isFinished || timerSecs <= 0 ? null : nowMs + timerSecs * 1000,
    loserId: isFinished ? active[0]! : null,
    lastMove: null,
  };

  assertRoundInvariants(state);
  return state;
}

/** Archive A `startRound` adapter returning the canonical `RoundState`. */
export function startRound(
  opts: StartRoundOptions & { order: readonly PlayerId[] },
): RoundState {
  return makeRound(opts.order, {
    ...opts,
    shuffleInitialFinishTies: opts.shuffleInitialFinishTies ?? true,
  });
}

/** Next active player in a stable seating order, excluding `from`. */
export function nextActiveNeighbor(round: RoundState, from: PlayerId): PlayerId | null {
  return nextActive(
    round.playerOrder,
    from,
    round.direction,
    (uid) => (round.hands[uid]?.length ?? 0) > 0,
  );
}

/** Archive A `drawTarget` helper: server-determined draw target for the current turn. */
export function drawTarget(round: RoundState): PlayerId {
  if (round.status !== "playing" || !round.currentPlayerId) {
    throw new GameRuleError("round_finished", "No draw is pending");
  }
  const target = nextActiveNeighbor(round, round.currentPlayerId);
  if (!target) {
    throw new GameRuleError("no_target", "No eligible target");
  }
  return target;
}

/**
 * Canonical server-authoritative draw transition unifying Archive A (`applyDraw`)
 * and Archive B (`drawCard`).
 */
export function drawCard(round: RoundState, action: DrawAction, nowMs = Date.now()): RoundState {
  if (round.status !== "playing") {
    throw new GameRuleError("round_finished", "Round already ended");
  }
  if (round.version !== action.expectedVersion) {
    throw new GameRuleError("stale_version", "Turn state changed; refresh and retry");
  }
  if (round.currentPlayerId !== action.actorId) {
    throw new GameRuleError("not_your_turn", "It is not your turn");
  }
  if (!Number.isSafeInteger(action.cardIndex)) {
    throw new GameRuleError("invalid_index", "Card position must be an integer");
  }
  const targetId = nextActiveNeighbor(round, action.actorId);
  if (!targetId) {
    throw new GameRuleError("no_target", "There is no eligible target");
  }
  const opponentHand = round.hands[targetId]!;
  if (action.cardIndex < 0 || action.cardIndex >= opponentHand.length) {
    throw new GameRuleError("invalid_index", "Selected card position is not valid");
  }

  const drawn = opponentHand[action.cardIndex]!;
  const targetHand = opponentHand.filter((_, i) => i !== action.cardIndex);
  const resolved = removePairs([...round.hands[action.actorId]!, drawn]);
  const hands = {
    ...round.hands,
    [targetId]: targetHand,
    [action.actorId]: resolved.hand,
  };
  const discarded = [...round.discarded, ...resolved.discarded];
  const finishOrder = [...round.finishOrder];
  const newlyFinished: PlayerId[] = [];

  // Target loses its last card first; drawer pairs & finishes second (matches both Archive A and Archive B)
  for (const p of [targetId, action.actorId]) {
    if (hands[p]!.length === 0 && !finishOrder.includes(p)) {
      finishOrder.push(p);
      newlyFinished.push(p);
    }
  }

  const active = round.playerOrder.filter((p) => hands[p]!.length > 0);
  if (active.length < 1) {
    throw new Error("King cannot disappear from all hands");
  }
  const finished = active.length === 1;
  const loserId = finished ? active[0]! : null;
  if (loserId && !finishOrder.includes(loserId)) {
    finishOrder.push(loserId);
  }

  const workingRound: RoundState = { ...round, hands };
  const nextPlayerId = finished ? null : nextActiveNeighbor(workingRound, action.actorId);
  if (!finished && nextPlayerId === null) {
    throw new Error("No valid next player");
  }

  const timerSecs = round.turnTimerSeconds ?? 45;
  const next: RoundState = {
    ...round,
    hands,
    discarded,
    finishOrder,
    currentPlayerId: nextPlayerId,
    turnNumber: round.turnNumber + 1,
    version: round.version + 1,
    status: finished ? "finished" : "playing",
    phase: finished ? "ROUND_COMPLETED" : "WAITING_FOR_DRAW",
    turnDeadlineMs: finished || timerSecs <= 0 ? null : nowMs + timerSecs * 1000,
    loserId,
    lastMove: {
      actorId: action.actorId,
      targetId,
      pairsRemoved: resolved.pairCount,
      finishedPlayerIds: newlyFinished,
      turnNumber: round.turnNumber + 1,
    },
  };
  assertRoundInvariants(next);
  return next;
}

/** Archive A `applyDraw` adapter over canonical `drawCard`. */
export function applyDraw(
  state: RoundState,
  uid: PlayerId,
  position: number,
): { state: RoundState; event: NonNullable<RoundState["lastMove"]> & { roundCompleted: boolean; loserUid: PlayerId | null } } {
  const next = drawCard(state, {
    actorId: uid,
    cardIndex: position,
    expectedVersion: state.version,
  });
  return {
    state: next,
    event: {
      ...next.lastMove!,
      roundCompleted: next.status === "finished",
      loserUid: next.loserId,
    },
  };
}

/** Archive A random legal card index selector for turn timer auto-play. */
export function autoDrawPosition(round: RoundState, rand: RandomInt = secureRandomInt): number {
  const targetId = drawTarget(round);
  return rand(round.hands[targetId]!.length);
}

/** Auto-draws a random legal card when a turn deadline has expired. */
export function autoDrawOnTimeout(
  round: RoundState,
  expectedVersion: number,
  nowMs = Date.now(),
  rand: RandomInt = secureRandomInt,
): RoundState {
  if (round.status !== "playing" || !round.currentPlayerId) {
    throw new GameRuleError("round_finished", "Round is not active");
  }
  if (round.version !== expectedVersion) {
    throw new GameRuleError("stale_version", "Turn version already advanced");
  }
  const randomIndex = autoDrawPosition(round, rand);
  return drawCard(
    round,
    {
      actorId: round.currentPlayerId,
      cardIndex: randomIndex,
      expectedVersion,
    },
    nowMs,
  );
}

/** Everyone in finishing order, loser last. Only valid when round is finished. */
export function fullRanking(round: RoundState): PlayerId[] {
  if (round.status !== "finished" || !round.loserId) {
    throw new GameRuleError("round_active", "Round is not complete");
  }
  return [...round.finishOrder];
}

/**
 * Sanitized public view safe to broadcast to all room members.
 * Never includes `hands`, `discarded` card objects, or secret card identities.
 */
export function publicView(round: RoundState): PublicRoundState {
  const handCounts: Record<PlayerId, number> = {};
  for (const playerId of round.playerOrder) {
    handCounts[playerId] = round.hands[playerId]!.length;
  }
  return {
    id: round.id,
    playerOrder: [...round.playerOrder],
    direction: round.direction,
    handCounts,
    finishOrder: [...round.finishOrder],
    currentPlayerId: round.currentPlayerId,
    drawTargetId: round.currentPlayerId ? nextActiveNeighbor(round, round.currentPlayerId) : null,
    turnNumber: round.turnNumber,
    version: round.version,
    status: round.status,
    phase: round.phase ?? (round.status === "finished" ? "ROUND_COMPLETED" : "WAITING_FOR_DRAW"),
    turnDeadlineMs: round.turnDeadlineMs ?? null,
    loserId: round.loserId,
    discardCount: round.discarded.length,
    lastMove: round.lastMove,
  };
}

/**
 * Verifies all 15 mathematical and security invariants of an El Shayeb round.
 * Throws immediately if any invariant is violated.
 */
export function assertRoundInvariants(round: RoundState): void {
  assertPlayers(round.playerOrder);
  if (round.direction !== "clockwise" && round.direction !== "counterclockwise") {
    throw new Error("Invalid direction");
  }
  if (!Number.isSafeInteger(round.version) || round.version < 0) {
    throw new Error("Invalid version");
  }
  if (!Number.isSafeInteger(round.turnNumber) || round.turnNumber < 0) {
    throw new Error("Invalid turn number");
  }
  if (round.discarded.length % 2 !== 0) {
    throw new Error("Discard pile must contain complete pairs");
  }

  const unique = new Set<string>();
  let cardCount = 0;
  let kingCount = 0;

  for (const p of round.playerOrder) {
    const hand = round.hands[p];
    if (!hand) throw new Error(`Missing hand for player ${p}`);
    const counts = new Map<string, number>();
    for (const card of hand) {
      if (card.rank === "K") kingCount++;
      counts.set(card.rank, (counts.get(card.rank) ?? 0) + 1);
      if (unique.has(card.id)) throw new Error(`Duplicated card ${card.id}`);
      if (
        !RANKS.includes(card.rank) ||
        !SUITS.includes(card.suit) ||
        card.id !== `${card.rank}:${card.suit}`
      ) {
        throw new Error("Invalid card");
      }
      unique.add(card.id);
      cardCount++;
    }
    if ([...counts.entries()].some(([rank, count]) => rank !== "K" && count > 1)) {
      throw new Error("Resolvable pair left in hand");
    }
  }

  for (let i = 0; i < round.discarded.length; i += 2) {
    const a = round.discarded[i]!;
    const b = round.discarded[i + 1]!;
    if (a.rank !== b.rank || a.rank === "K") throw new Error("Invalid discard pair");
    for (const card of [a, b]) {
      if (
        !RANKS.includes(card.rank) ||
        !SUITS.includes(card.suit) ||
        card.id !== `${card.rank}:${card.suit}`
      ) {
        throw new Error("Invalid discard card");
      }
      if (unique.has(card.id)) throw new Error(`Duplicated card ${card.id}`);
      unique.add(card.id);
      cardCount++;
    }
  }

  if (cardCount !== DECK_SIZE || unique.size !== DECK_SIZE || kingCount !== 1) {
    throw new Error("Card conservation violated");
  }
  if (new Set(round.finishOrder).size !== round.finishOrder.length) {
    throw new Error("Duplicate finishing player");
  }
  if (round.finishOrder.some((p) => !round.playerOrder.includes(p))) {
    throw new Error("Unknown finishing player");
  }

  const active = round.playerOrder.filter((p) => round.hands[p]!.length > 0);
  if (round.status === "playing") {
    if (active.length < 2) throw new Error("Playing round needs at least two active players");
    if (!round.currentPlayerId || !active.includes(round.currentPlayerId)) {
      throw new Error("Active player missing");
    }
    if (round.loserId !== null) throw new Error("Playing round cannot have loser");
    if (round.finishOrder.length + active.length !== round.playerOrder.length) {
      throw new Error("Player accounting error");
    }
  } else {
    if (active.length !== 1 || round.currentPlayerId !== null) {
      throw new Error("Invalid finished round state");
    }
    if (round.loserId !== active[0]) throw new Error("Loser must be last active player");
    if (
      round.hands[active[0]!]!.length !== 1 ||
      round.hands[active[0]!]![0]!.rank !== "K"
    ) {
      throw new Error("Loser must hold only the King");
    }
    if (
      round.finishOrder.length !== round.playerOrder.length ||
      round.finishOrder.at(-1) !== round.loserId
    ) {
      throw new Error("Finished round ranking is incorrect");
    }
  }

  for (const p of round.playerOrder) {
    if (p !== round.loserId && round.finishOrder.includes(p) && round.hands[p]!.length !== 0) {
      throw new Error("Finished player still has cards");
    }
  }
}

export const assertInvariants = assertRoundInvariants;
