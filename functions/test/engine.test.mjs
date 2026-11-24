import test from "node:test";
import assert from "node:assert/strict";
import {
  makeDeck,
  makeRound,
  drawCard,
  autoDrawOnTimeout,
  publicView,
  roundPoints,
  rankMatchPlayers,
  resolvePairs,
  nextActiveNeighbor,
  assertRoundInvariants,
  canTransitionPhase,
  assertValidPhaseTransition,
  EGYPTIAN_CHALLENGES,
  selectRandomChallenge,
  generateRoomCode,
  GameRuleError,
} from "../src/engine/index.ts";

test("deck has exactly 49 unique cards and only King of Hearts", () => {
  const deck = makeDeck();
  assert.equal(deck.length, 49);
  assert.equal(new Set(deck.map((c) => c.id)).size, 49);
  assert.deepEqual(
    deck.filter((c) => c.rank === "K").map((c) => c.suit),
    ["hearts"],
  );
});

test("matching ignores suits and resolves four-of-a-kind into two pairs", () => {
  const cards = makeDeck().filter((c) => c.rank === "7");
  const result = resolvePairs(cards);
  assert.equal(result.pairCount, 2);
  assert.equal(result.hand.length, 0);
  assert.equal(result.discarded.length, 4);
});

test("round setup preserves 49 cards and creates no unresolved pairs across 2-6 players", () => {
  for (let n = 2; n <= 6; n++) {
    const players = Array.from({ length: n }, (_, i) => "player_" + i);
    const round = makeRound(players);
    assertRoundInvariants(round);
    assert.equal(
      Object.values(round.hands).flat().length + round.discarded.length,
      49,
    );
  }
});

test("public game view contains counts and turn info but no cards or hand values", () => {
  const round = makeRound(["a", "b", "c"]);
  const pub = publicView(round);
  assert.equal("hands" in pub, false);
  assert.equal("discarded" in pub, false);
  assert.equal(JSON.stringify(pub).includes("hearts"), false);
  assert.equal(
    Object.values(pub.handCounts).reduce((a, b) => a + b, 0),
    49 - pub.discardCount,
  );
});

test("only active player can draw; stale and bad selections rejected", () => {
  let round;
  do {
    round = makeRound(["a", "b", "c", "d"]);
  } while (round.status !== "playing");
  const caller = round.currentPlayerId;
  assert.throws(
    () => drawCard(round, { actorId: "imposter", cardIndex: 0, expectedVersion: 0 }),
    (e) => e instanceof GameRuleError && e.code === "not_your_turn",
  );
  assert.throws(
    () => drawCard(round, { actorId: caller, cardIndex: -1, expectedVersion: 0 }),
    (e) => e.code === "invalid_index",
  );
  assert.throws(
    () => drawCard(round, { actorId: caller, cardIndex: 0, expectedVersion: 999 }),
    (e) => e.code === "stale_version",
  );
  const target = nextActiveNeighbor(round, caller);
  assert.ok(target && target !== caller);
  const update = drawCard(round, { actorId: caller, cardIndex: 0, expectedVersion: 0 });
  assert.equal(update.version, 1);
  assert.equal(update.turnNumber, 1);
  assertRoundInvariants(update);
  assert.equal(round.version, 0);
});

test("autoDrawOnTimeout draws a legal card when turn timer expires and rejects stale version", () => {
  let round;
  do {
    round = makeRound(["p1", "p2", "p3"]);
  } while (round.status !== "playing");
  assert.throws(
    () => autoDrawOnTimeout(round, 99),
    (e) => e instanceof GameRuleError && e.code === "stale_version",
  );
  const updated = autoDrawOnTimeout(round, 0);
  assert.equal(updated.version, 1);
  assertRoundInvariants(updated);
});

test("points calculated in finishing order with loser scoring zero and deterministic tie-breaking", () => {
  assert.deepEqual(roundPoints(["b", "a", "d", "c"]), { b: 3, a: 2, d: 1, c: 0 });
  const standings = rankMatchPlayers(
    ["p1", "p2", "p3", "p4"],
    { p1: 6, p2: 6, p3: 6, p4: 2 },
    { p1: 1, p2: 0, p3: 0, p4: 2 },
    { p1: 2, p2: 2, p3: 1, p4: 0 },
  );
  // p2 beats p3 on firstFinishes (both 6 pts, 0 losses); p3 beats p1 on fewer losses (0 vs 1)
  assert.deepEqual(
    standings.map((s) => s.uid),
    ["p2", "p3", "p1", "p4"],
  );
  assert.equal(standings[0].placement, 1);
  assert.equal(standings[3].placement, 4);
});

test("30 localized Egyptian challenges and unbiased non-repeating selection", () => {
  assert.equal(EGYPTIAN_CHALLENGES.length, 30);
  const ids = new Set(EGYPTIAN_CHALLENGES.map((c) => c.id));
  assert.equal(ids.size, 30);
  for (const ch of EGYPTIAN_CHALLENGES) {
    assert.ok(ch.title.length > 3);
    assert.ok(ch.description.length > 10);
    assert.equal(ch.enabled, true);
  }
  const used = EGYPTIAN_CHALLENGES.slice(0, 29).map((c) => c.id);
  const lastRemaining = selectRandomChallenge(used);
  assert.equal(lastRemaining.id, "ch_30");
});

test("state machine validates legal transitions and blocks illegal skips", () => {
  assert.equal(canTransitionPhase("WAITING_FOR_PLAYERS", "READY_TO_START"), true);
  assert.equal(canTransitionPhase("WAITING_FOR_PLAYERS", "MATCH_COMPLETED"), false);
  assert.throws(
    () => assertValidPhaseTransition("WAITING_FOR_DRAW", "MATCH_COMPLETED"),
    (e) => e instanceof GameRuleError && e.code === "invalid_phase_transition",
  );
});

test("room code generator creates 6-char unambiguous alphanumeric codes", () => {
  for (let i = 0; i < 50; i++) {
    const code = generateRoomCode(6);
    assert.equal(code.length, 6);
    assert.match(code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/);
  }
});

test("invalid player lists are rejected", () => {
  assert.throws(
    () => makeRound(["single"]),
    (e) => e.code === "player_count",
  );
  assert.throws(
    () => makeRound(["x", "x"]),
    (e) => e.code === "invalid_players",
  );
  assert.throws(
    () => makeRound(["a", "b"], { direction: "diagonal" }),
    (e) => e.code === "direction",
  );
});
