import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  createDeck,
  DECK_SIZE,
  shuffle,
  dealCards,
  removePairs,
  nextActive,
  roundPoints,
  emptyTotals,
  applyRound,
  rankMatch,
  startRound,
  drawTarget,
  applyDraw,
  autoDrawPosition,
  fullRanking,
  publicView,
  assertInvariants,
  pickChallenge,
  GameRuleError,
} from "../src/engine/index.ts";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Deterministic PRNG for reproducible tests only (preserved from Archive A). */
function seeded(seed) {
  let a = seed >>> 0;
  return (n) => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return Math.floor((((t ^ (t >>> 14)) >>> 0) / 4294967296) * n);
  };
}

const players = (n) => Array.from({ length: n }, (_, i) => `p${i + 1}`);

test("Archive A: shuffle is a permutation, not identity, and uniform across 24,000 trials", () => {
  const d = createDeck();
  const s = shuffle(d);
  assert.deepEqual(
    s.map((x) => x.id).sort(),
    d.map((x) => x.id).sort(),
  );
  assert.notDeepEqual(
    s.map((x) => x.id),
    d.map((x) => x.id),
  );

  const n = 4;
  const trials = 24000;
  const counts = Array.from({ length: n }, () => Array(n).fill(0));
  for (let t = 0; t < trials; t++) {
    shuffle([0, 1, 2, 3]).forEach((v, i) => counts[v][i]++);
  }
  for (const row of counts) {
    for (const k of row) {
      assert.ok(Math.abs(k - trials / n) < (trials / n) * 0.1, `skewed: ${k}`);
    }
  }
});

test("Archive A: dealing is round-robin with expected unequal hand sizes (49 / N)", () => {
  const h4 = dealCards(createDeck(), 4);
  assert.deepEqual(
    h4.map((x) => x.length),
    [13, 12, 12, 12],
  );
  const h6 = dealCards(createDeck(), 6);
  assert.deepEqual(
    h6.map((x) => x.length),
    [9, 8, 8, 8, 8, 8],
  );
});

test("Archive A: nextActive skips finished players in both directions and never returns self", () => {
  const order = ["a", "b", "c", "d"];
  const active = (u) => u !== "b";
  assert.equal(nextActive(order, "a", "clockwise", active), "c");
  assert.equal(nextActive(order, "a", "counterclockwise", active), "d");
  assert.equal(nextActive(order, "b", "clockwise", active), "c");
  assert.equal(nextActive(order, "a", "clockwise", (u) => u === "a"), null);
});

test("Archive A: applyRound and rankMatch compute cumulative points, tie-breaks, and shared rank (1,1,3)", () => {
  let t = {};
  t = applyRound(t, ["a", "b", "c"]);
  t = applyRound(t, ["b", "a", "c"]);
  const r = rankMatch(t);
  assert.deepEqual(
    r.map((x) => x.rank),
    [1, 1, 3],
  );
  assert.equal(r[0].isSharedPlacement, true);
  assert.equal(r[2].uid, "c");
  assert.equal(r[2].roundLosses, 2);
});

test("Archive A: 5-round 4-player full match simulation accumulates consistent totals", () => {
  const order = players(4);
  let totals = Object.fromEntries(order.map((u) => [u, emptyTotals()]));
  for (let r = 1; r <= 5; r++) {
    const rand = seeded(900 + r);
    let s = startRound({ roundNumber: r, order, direction: "clockwise", rand });
    while (s.status === "playing") {
      s = applyDraw(s, s.currentPlayerId, autoDrawPosition(s, rand)).state;
    }
    totals = applyRound(totals, fullRanking(s));
  }
  assert.equal(
    Object.values(totals).reduce((a, t) => a + t.points, 0),
    5 * 6,
  );
  assert.equal(
    Object.values(totals).reduce((a, t) => a + t.roundLosses, 0),
    5,
  );
  assert.equal(
    Object.values(totals).reduce((a, t) => a + t.firstPlaces, 0),
    5,
  );
  const ranked = rankMatch(totals);
  assert.equal(ranked[0].rank, 1);
});

test("Archive A: challenges.json seed has 30 valid Arabic entries and pickChallenge avoids repeats", () => {
  const raw = fs.readFileSync(path.join(__dirname, "../data/challenges.json"), "utf8");
  const list = JSON.parse(raw);
  assert.equal(list.length, 30);
  assert.equal(new Set(list.map((x) => x.id)).size, 30);
  for (const x of list) {
    assert.ok(x.title && x.description && x.enabled === true);
    assert.ok(/[\u0600-\u06FF]/.test(x.title) && /[\u0600-\u06FF]/.test(x.description));
  }
  const recent = list.slice(0, 29).map((x) => x.id);
  assert.equal(pickChallenge(list, recent)?.id, "ch_030");
  assert.equal(pickChallenge(list.map((x) => ({ ...x, enabled: false }))), null);
});

// Archive A's 2,000 complete round simulations (400 rounds × 5 player counts: 2, 3, 4, 5, 6)
for (const n of [2, 3, 4, 5, 6]) {
  test(`Archive A simulation: ${n} players, 400 rounds, both directions, all 15 invariants verified after every move`, () => {
    let moves = 0;
    for (let i = 0; i < 400; i++) {
      const rand = seeded(n * 100000 + i);
      let s = startRound({
        roundNumber: (i % 5) + 1,
        order: players(n),
        direction: i % 2 ? "clockwise" : "counterclockwise",
        rand,
      });
      assertInvariants(s);
      let guard = 0;
      while (s.status === "playing") {
        assert.ok(++guard < 100000, "round did not terminate");
        const pos = autoDrawPosition(s, rand);
        s = applyDraw(s, s.currentPlayerId, pos).state;
        moves++;
        assertInvariants(s);
      }
      const ranking = fullRanking(s);
      assert.equal(ranking.length, n);
      assert.equal(new Set(ranking).size, n);
      assert.equal(ranking[n - 1], s.loserId);
      assert.equal(
        Object.values(roundPoints(ranking)).reduce((a, b) => a + b, 0),
        (n * (n - 1)) / 2,
      );
    }
    assert.ok(moves > 0);
  });
}
