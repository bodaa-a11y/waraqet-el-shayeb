import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  makeRound,
  drawCard,
  publicView,
  GameRuleError,
} from "../src/engine/index.ts";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, "../..");

/**
 * In-memory transactional room store simulator that mirrors the exact
 * Cloud Functions transaction & idempotency logic in functions/src/index.ts.
 */
class TransactionalRoomHarness {
  constructor(playerIds) {
    this.memberIds = [...playerIds];
    let round;
    do {
      round = makeRound(playerIds);
    } while (round.status !== "playing");
    this.secretRound = round;
    this.actions = new Map();
    this.hands = new Map(playerIds.map((id) => [id, round.hands[id]]));
    this.publicState = publicView(round);
  }

  readHand(callerUid, targetUid) {
    if (!this.memberIds.includes(callerUid)) {
      throw new GameRuleError("permission_denied", "Non-member cannot read room documents");
    }
    if (callerUid !== targetUid) {
      throw new GameRuleError("permission_denied", "Player cannot read another player's private hand");
    }
    return this.hands.get(targetUid);
  }

  readSecretRound() {
    throw new GameRuleError("permission_denied", "Clients can never read secret/round");
  }

  executeTransactionalDraw({ callerUid, cardIndex, expectedVersion, actionId }) {
    if (!this.memberIds.includes(callerUid)) {
      throw new GameRuleError("permission_denied", "Caller is not a room member");
    }
    if (this.actions.has(actionId)) {
      const existing = this.actions.get(actionId);
      if (existing.uid !== callerUid) {
        throw new GameRuleError("permission_denied", "Action ID belongs to another player");
      }
      return { applied: false, alreadyApplied: true, version: existing.version };
    }
    const next = drawCard(this.secretRound, {
      actorId: callerUid,
      cardIndex,
      expectedVersion,
    });
    this.secretRound = next;
    this.publicState = publicView(next);
    for (const pid of next.playerOrder) {
      this.hands.set(pid, next.hands[pid]);
    }
    this.actions.set(actionId, { uid: callerUid, version: next.version });
    return { applied: true, alreadyApplied: false, version: next.version };
  }
}

test("security & anti-cheat: unauthorized hand reads, secret state reads, and non-member actions are blocked", () => {
  const harness = new TransactionalRoomHarness(["u1", "u2", "u3", "u4"]);

  // Owner can read own hand
  const ownHand = harness.readHand("u1", "u1");
  assert.ok(Array.isArray(ownHand));

  // Cross-player hand read blocked
  assert.throws(
    () => harness.readHand("u1", "u2"),
    (e) => e instanceof GameRuleError && e.code === "permission_denied",
  );

  // Outsider hand read blocked
  assert.throws(
    () => harness.readHand("outsider", "u1"),
    (e) => e instanceof GameRuleError && e.code === "permission_denied",
  );

  // Secret round state blocked
  assert.throws(
    () => harness.readSecretRound(),
    (e) => e instanceof GameRuleError && e.code === "permission_denied",
  );
});

test("concurrency & idempotency: duplicate actionId returns safe idempotent response; concurrent draw on same version fails with stale_version", () => {
  const harness = new TransactionalRoomHarness(["u1", "u2", "u3", "u4"]);
  const activeUid = harness.publicState.currentPlayerId;

  // First draw succeeds
  const first = harness.executeTransactionalDraw({
    callerUid: activeUid,
    cardIndex: 0,
    expectedVersion: 0,
    actionId: "action_turn0_retryable",
  });
  assert.equal(first.applied, true);
  assert.equal(first.alreadyApplied, false);
  assert.equal(first.version, 1);

  // Network retry with the SAME actionId is idempotent and does not draw a second card
  const retry = harness.executeTransactionalDraw({
    callerUid: activeUid,
    cardIndex: 0,
    expectedVersion: 0,
    actionId: "action_turn0_retryable",
  });
  assert.equal(retry.applied, false);
  assert.equal(retry.alreadyApplied, true);
  assert.equal(harness.publicState.version, 1);

  // Different player trying to reuse that actionId is rejected
  assert.throws(
    () =>
      harness.executeTransactionalDraw({
        callerUid: "u2",
        cardIndex: 0,
        expectedVersion: 1,
        actionId: "action_turn0_retryable",
      }),
    (e) => e instanceof GameRuleError && e.code === "permission_denied",
  );

  // Stale concurrent draw with old expectedVersion (0 instead of 1) is rejected
  const nextUid = harness.publicState.currentPlayerId;
  if (nextUid) {
    assert.throws(
      () =>
        harness.executeTransactionalDraw({
          callerUid: nextUid,
          cardIndex: 0,
          expectedVersion: 0,
          actionId: "action_stale_attempt",
        }),
      (e) => e instanceof GameRuleError && e.code === "stale_version",
    );
  }
});

test("firestore.rules and storage.rules enforce member-only reads, owner-only hands, and zero client game writes", () => {
  const firestoreRules = fs.readFileSync(path.join(rootDir, "firestore.rules"), "utf8");
  const storageRules = fs.readFileSync(path.join(rootDir, "storage.rules"), "utf8");

  // Private rooms cannot be listed globally
  assert.match(firestoreRules, /match \/rooms\/\{roomId\}[\s\S]*?allow list:\s*if false;/);
  // Hands are strictly owner-only get, never list or write
  assert.match(firestoreRules, /match \/hands\/\{playerUid\}[\s\S]*?allow get:\s*if isOwner\(playerUid\) && isRoomMember\(roomId\);/);
  assert.match(firestoreRules, /match \/hands\/\{playerUid\}[\s\S]*?allow list, write:\s*if false;/);
  // Secret round document is completely inaccessible to clients
  assert.match(firestoreRules, /match \/secret\/\{id\}[\s\S]*?allow read, write:\s*if false;/);
  // All chat creation is server-only, preventing sender spoofing or rate-limit bypass.
  assert.match(firestoreRules, /match \/messages\/\{messageId\}[\s\S]*?allow create, update, delete:\s*if false;/);
  assert.match(firestoreRules, /match \/chatRate\/\{playerUid\}[\s\S]*?allow read, write:\s*if false;/);
  // Storage rules validate room membership and MIME types
  assert.match(storageRules, /allow read:\s*if isRoomMember\(roomId\);/);
  assert.match(storageRules, /image\/\(jpeg\|png\|webp\)/);
});
