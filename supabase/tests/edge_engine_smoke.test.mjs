// Smoke test: the engine copy bundled with the Edge Functions
// (supabase/functions/_shared/engine) plays complete rounds end-to-end.
// Runs on Node >= 22.6 (native TypeScript type stripping).
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  makeRound,
  drawCard,
  publicView,
  roundPoints,
  generateRoomCode,
} from "../functions/_shared/engine/index.ts";

for (const n of [2, 3, 4, 5, 6]) {
  test(`edge engine: full ${n}-player round finishes with exactly one loser`, () => {
    const players = Array.from({ length: n }, (_, i) => `p${i + 1}`);
    let round = makeRound(players, { roundNumber: 1, direction: "clockwise", turnTimerSeconds: 45 });
    let guard = 0;
    while (round.status === "playing" && guard++ < 20000) {
      const target = publicView(round).drawTargetId;
      const targetCount = round.hands[target].length;
      round = drawCard(round, {
        actorId: round.currentPlayerId,
        cardIndex: Math.floor(Math.random() * targetCount),
        expectedVersion: round.version,
      });
    }
    assert.equal(round.status, "finished");
    assert.ok(round.loserId, "loser assigned");
    const pub = publicView(round);
    assert.ok(!JSON.stringify(pub).includes('"hands"'), "public view must not leak hands");
    const pts = roundPoints(round.finishOrder);
    assert.equal(Object.keys(pts).length, n);
  });
}

test("edge engine: room codes are 6 chars from the safe alphabet", () => {
  for (let i = 0; i < 200; i++) {
    assert.match(generateRoomCode(6), /^[A-Z0-9]{6}$/);
  }
});

