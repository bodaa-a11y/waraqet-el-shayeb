import test from "node:test";
import assert from "node:assert/strict";
import {
  makeRound,
  drawCard,
  publicView,
  assertRoundInvariants,
  roundPoints,
  secureRandomInt,
} from "../src/engine/index.ts";

test("300 complete real-rules simulations across all player counts (2-6) and both directions", () => {
  let turns = 0;
  let longest = 0;
  for (let iteration = 0; iteration < 300; iteration++) {
    const size = (iteration % 5) + 2;
    const players = Array.from({ length: size }, (_, i) => `p${i}`);
    let round = makeRound(players, {
      direction: iteration % 2 === 0 ? "clockwise" : "counterclockwise",
    });
    let thisGameTurns = 0;
    while (round.status !== "finished") {
      const pub = publicView(round);
      const targetCount = pub.handCounts[pub.drawTargetId];
      assert.ok(targetCount >= 1);
      const index = secureRandomInt(targetCount);
      round = drawCard(round, {
        actorId: round.currentPlayerId,
        cardIndex: index,
        expectedVersion: round.version,
      });
      thisGameTurns++;
      assert.ok(thisGameTurns < 10000, "Game should eventually terminate");
      assertRoundInvariants(round);
    }
    longest = Math.max(longest, thisGameTurns);
    turns += thisGameTurns;
    assert.equal(round.finishOrder.length, size);
    assert.equal(round.hands[round.loserId][0].rank, "K");
    assert.equal(round.discarded.length, 48);
    const score = roundPoints(round.finishOrder);
    assert.equal(
      Object.values(score).reduce((a, b) => a + b, 0),
      (size * (size - 1)) / 2,
    );
  }
  console.log(`Verified 300 multiplayer rounds; ${turns} legal turns; longest ${longest}`);
});
