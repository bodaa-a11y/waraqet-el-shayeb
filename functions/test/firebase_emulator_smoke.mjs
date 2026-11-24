/**
 * Real Firebase Emulator Suite smoke test. NO MOCKS.
 * Requirements: Auth + Firestore + Functions (with project demo-el-shayeb).
 * Run through scripts/test_backend_emulator.ps1 on Windows.
 * Uses only Node.js >= 20 built-ins; does NOT run in live Firebase.
 */
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const projectId = process.env.SHAYEB_TEST_PROJECT || 'demo-el-shayeb';
if (!projectId.startsWith('demo-')) {
  throw new Error('Safety stop: emulator test requires a demo- project ID');
}
const host = process.env.EMULATOR_HOST || '127.0.0.1';
const authBase = `http://${host}:9099`;
const fnBase = `http://${host}:5001/${projectId}/europe-west1`;
const fsBase = `http://${host}:8080/v1/projects/${projectId}/databases/(default)/documents`;

async function jsonFetch(url, options = {}) {
  const res = await fetch(url, { signal: AbortSignal.timeout(15000), ...options });
  const raw = await res.text();
  let payload;
  try { payload = raw ? JSON.parse(raw) : null; } catch { payload = { raw }; }
  return { ok: res.ok, status: res.status, payload };
}

async function signIn() {
  const out = await jsonFetch(`${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-emulator-api-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  assert.ok(out.ok && out.payload?.idToken && out.payload?.localId,
    `Auth emulator sign-up failed: ${JSON.stringify(out)}`);
  return { uid: out.payload.localId, token: out.payload.idToken };
}

async function call(name, user, data = {}, expectFailure = false) {
  const out = await jsonFetch(`${fnBase}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  if (expectFailure) {
    assert.ok(!out.ok || out.payload?.error, `${name}: expected rejection, got ${JSON.stringify(out)}`);
    return out;
  }
  assert.ok(out.ok && !out.payload?.error,
    `${name} failed (${out.status}): ${JSON.stringify(out.payload)}`);
  return out.payload?.result ?? out.payload?.data;
}

async function readDocument(path, user, allowed = true) {
  const out = await jsonFetch(`${fsBase}/${path}`, {
    headers: { Authorization: `Bearer ${user.token}` },
  });
  if (allowed) assert.equal(out.status, 200, `Firestore allowed read ${path}: ${JSON.stringify(out)}`);
  else assert.ok([401, 403].includes(out.status), `Firestore must deny ${path}: ${JSON.stringify(out)}`);
  return out.payload;
}

async function directMessageWrite(roomId, user) {
  const out = await jsonFetch(`${fsBase}/rooms/${roomId}/messages?documentId=forged_${Date.now()}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${user.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: {
      senderUid: { stringValue: 'system' },
      senderNickname: { stringValue: 'SYSTEM' },
      type: { stringValue: 'system' },
      text: { stringValue: 'FAKE SERVER EVENT' },
      createdAt: { timestampValue: new Date().toISOString() },
    } }),
  });
  assert.ok([401, 403].includes(out.status), `Direct chat write must be denied: ${JSON.stringify(out)}`);
}

async function main() {
  const [alice, bob, outsider] = await Promise.all([signIn(), signIn(), signIn()]);
  const byUid = new Map([[alice.uid, alice], [bob.uid, bob]]);
  console.log('✓ Three independent Auth Emulator sessions');

  await call('createRoom', null, { nickname: 'أحمد' }, true);
  const { roomId, code } = await call('createRoom', alice, {
    nickname: 'أحمد', avatarId: 'avatar_1', visibility: 'private',
    maxPlayers: 2, totalRounds: 3, direction: 'clockwise',
    challengeMode: 'every_round', turnTimerSeconds: 0,
  });
  assert.ok(roomId && /^[A-Z0-9]{6}$/.test(code), 'Private room code generated');
  console.log(`✓ Private room created with code ${code}`);

  await call('joinRoomByCode', bob, { roomId, nickname: 'محمد' }, true);
  await call('joinRoomByCode', bob, { code: 'BADBAD', nickname: 'محمد' }, true);
  await call('joinRoomByCode', bob, { code, nickname: 'محمد', avatarId: 'avatar_2' });
  await call('getRoomState', outsider, { roomId }, true);
  await readDocument(`rooms/${roomId}`, outsider, false);
  await readDocument(`rooms/${roomId}`, alice, true);
  console.log('✓ Room code joining + private-room membership rules');

  const sent = await call('sendRoomMessage', alice, { roomId, text: 'صباح الفل يا معلم ☕' });
  assert.ok(sent.messageId);
  const chat = await readDocument(`rooms/${roomId}/messages/${sent.messageId}`, bob);
  assert.equal(chat.fields.senderUid.stringValue, alice.uid);
  assert.equal(chat.fields.text.stringValue, 'صباح الفل يا معلم ☕');
  await directMessageWrite(roomId, bob);
  await call('sendRoomMessage', outsider, { roomId, text: 'intrusion' }, true);
  await call('sendRoomMessage', alice, { roomId, text: 'https://example.org', attachmentUrl: 'https://evil.example' }, true);
  await call('seedChallengesCatalog', alice, {}, true);
  console.log('✓ Real Firestore chat delivery + sender forgery blocked');

  await call('setPlayerReady', bob, { roomId, ready: true });
  await call('startGame', alice, { roomId });
  await call('restartMatch', alice, { roomId }, true);
  const first = await call('getRoomState', alice, { roomId });
  assert.equal(first.room.roundNumber, 1);
  assert.equal(first.publicRound.handCounts[alice.uid] + first.publicRound.handCounts[bob.uid] + first.publicRound.discardCount, 49);
  await readDocument(`rooms/${roomId}/hands/${alice.uid}`, alice);
  await readDocument(`rooms/${roomId}/hands/${alice.uid}`, bob, false);
  await readDocument(`rooms/${roomId}/secret/round`, alice, false);
  console.log('✓ Server dealing + 49-card invariant + protected private hands');

  let drawCount = 0;
  for (let round = 1; round <= 3; round++) {
    for (let step = 0; step < 600; step++) {
      const status = await call('getRoomState', alice, { roomId });
      if (status.room.status === 'finished' || status.room.status === 'round_results') break;
      const turnUid = status.publicRound.currentPlayerId;
      const actingUser = byUid.get(turnUid);
      assert.ok(actingUser, `Unknown turn owner: ${turnUid}`);
      const draw = await call('drawCard', actingUser, {
        roomId, cardIndex: 0, expectedVersion: status.publicRound.version,
        actionId: `test_${randomUUID()}`,
      });
      assert.equal(draw.applied, true);
      drawCount++;
      if (step === 599) throw new Error('Too many draws; possible infinite match');
    }
    const result = await call('getRoomState', alice, { roomId });
    assert.ok(['finished', 'round_results'].includes(result.room.status));
    assert.equal(result.publicRound.status, 'finished');
    assert.ok(result.publicRound.loserId);
    assert.equal(result.room.roundNumber, round);
    assert.equal(result.ownHand.length + (await call('getRoomState', bob, { roomId })).ownHand.length + result.publicRound.discardCount, 49);
    const losingUser = byUid.get(result.publicRound.loserId);
    if (result.room.activeChallenge) {
      await call('completeChallenge', losingUser, { roomId, skip: true });
    }
    if (round < 3) await call('advanceToNextRound', alice, { roomId });
  }
  const finished = await call('getRoomState', alice, { roomId });
  assert.equal(finished.room.status, 'finished');
  await call('restartMatch', alice, { roomId });
  const reset = await call('getRoomState', alice, { roomId });
  assert.equal(reset.room.status, 'waiting');
  assert.equal(reset.publicRound, null);
  assert.deepEqual(reset.ownHand, []);
  console.log(`✓ Three complete REAL backend rounds (${drawCount} legal draws), challenge skip + safe rematch`);

  const publicRoom = await call('createRoom', bob, {
    nickname: 'محمد', visibility: 'public', maxPlayers: 2,
    totalRounds: 1, turnTimerSeconds: 0,
  });
  await readDocument(`publicRooms/${publicRoom.roomId}`, alice, true);
  await call('joinRoomByCode', outsider, { roomId: publicRoom.roomId, nickname: 'علي' });
  const directoryEntry = await readDocument(`publicRooms/${publicRoom.roomId}`, alice, true);
  assert.equal(Number(directoryEntry.fields.playerCount.integerValue), 2);
  await call('joinRoomByCode', alice, { roomId: publicRoom.roomId, nickname: 'أحمد' }, true);
  console.log('✓ Public room directory, roomId-based public joining, and capacity validation');
  console.log('\n✅ ALL EMULATOR SMOKE CHECKS PASSED — these exercised REAL local Firebase services');
}

main().catch((error) => {
  console.error('❌ Firebase emulator integration test failed:', error.stack ?? error);
  process.exitCode = 1;
});
