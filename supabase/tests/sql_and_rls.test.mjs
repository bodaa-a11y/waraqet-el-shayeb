import { test, describe, before } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { PGlite } from "@electric-sql/pglite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.resolve(__dirname, "../migrations");

describe("Supabase PostgreSQL Migrations, RPCs & RLS Test Suite", () => {
  let db;

  const userA = "11111111-1111-4111-8111-111111111111";
  const userB = "22222222-2222-4222-8222-222222222222";
  const userC = "33333333-3333-4333-8333-333333333333";

  before(async () => {
    db = new PGlite();

    // Setup mock Supabase roles and auth schema
    await db.exec(`
      do $$ begin
        if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
        if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
        if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role; end if;
      end $$;

      create schema if not exists auth;
      create table if not exists auth.users (
        id uuid primary key,
        email text,
        created_at timestamptz default now()
      );
      insert into auth.users (id, email) values
        ('${userA}', 'userA@example.com'),
        ('${userB}', 'userB@example.com'),
        ('${userC}', 'userC@example.com');

      -- Mock auth.uid() function returning current session context
      create or replace function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
      $$;

      -- Mock storage schema for bucket creation
      create schema if not exists storage;
      create table if not exists storage.buckets (
        id text primary key,
        name text,
        public boolean default false,
        file_size_limit bigint,
        allowed_mime_types text[]
      );
      create table if not exists storage.objects (
        id uuid primary key default gen_random_uuid(),
        bucket_id text references storage.buckets(id),
        name text,
        owner uuid,
        metadata jsonb default '{}'::jsonb,
        created_at timestamptz default now()
      );
    `);

    // Execute migrations 1 through 6 in order
    const files = fs.readdirSync(migrationsDir)
      .filter((f) => f.endsWith(".sql"))
      .sort();

    for (const f of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, f), "utf8");
      await db.exec(sql);
    }
  });

  test("1. Profiles: Can save player profile and enforce nickname rules", async () => {
    // Valid profile
    const res = await db.query(
      `select public.rpc_save_profile($1) as val`,
      [JSON.stringify({ uid: userA, nickname: "المعلم أحمد", avatarId: "avatar_1" })]
    );
    assert.equal(res.rows[0].val.ok, true);

    // Profile exists in table
    const check = await db.query(`select nickname, avatar_id from public.profiles where id = $1`, [userA]);
    assert.equal(check.rows[0].nickname, "المعلم أحمد");
    assert.equal(check.rows[0].avatar_id, "avatar_1");

    // Rejects forbidden system nickname
    await assert.rejects(
      async () => {
        await db.query(`select public.rpc_save_profile($1)`, [
          JSON.stringify({ uid: userA, nickname: "admin" })
        ]);
      },
      /الاسم ده محجوز للنظام/
    );
  });

  test("2. Rooms: Create private room, join with valid code, reject join without code", async () => {
    // Player A creates private room
    const createRes = await db.query(`select public.rpc_create_room($1) as val`, [
      JSON.stringify({
        uid: userA,
        nickname: "المعلم أحمد",
        avatarId: "avatar_1",
        code: "SH7K29",
        title: "قعدة المعلم",
        maxPlayers: 3,
        totalRounds: 3,
        visibility: "private"
      })
    ]);
    const { roomId, code } = createRes.rows[0].val;
    assert.equal(code, "SH7K29");
    assert.ok(roomId);

    // Player B attempts to join private room using ONLY roomId without code -> rejected
    await assert.rejects(
      async () => {
        await db.query(`select public.rpc_join_room($1)`, [
          JSON.stringify({
            uid: userB,
            roomId: roomId,
            code: "",
            nickname: "كريم",
            avatarId: "avatar_2"
          })
        ]);
      },
      /القعدة الخاصة لازم تدخلها بالكود/
    );

    // Player B joins with correct code -> succeeds
    const joinRes = await db.query(`select public.rpc_join_room($1) as val`, [
      JSON.stringify({
        uid: userB,
        code: "SH7K29",
        nickname: "كريم",
        avatarId: "avatar_2"
      })
    ]);
    assert.equal(joinRes.rows[0].val.roomId, roomId);

    // Both players appear in room_players
    const players = await db.query(
      `select user_id, nickname, seat, ready from public.room_players where room_id = $1 order by seat`,
      [roomId]
    );
    assert.equal(players.rows.length, 2);
    assert.equal(players.rows[0].user_id, userA);
    assert.equal(players.rows[0].ready, true); // host starts ready
    assert.equal(players.rows[1].user_id, userB);
    assert.equal(players.rows[1].ready, false);
  });

  test("3. Readiness & Start Game validation", async () => {
    const roomRow = await db.query(`select id from public.rooms where code = 'SH7K29'`);
    const roomId = roomRow.rows[0].id;

    // Player B marks ready
    await db.query(`select public.rpc_set_ready($1)`, [
      JSON.stringify({ uid: userB, roomId, ready: true })
    ]);

    const pB = await db.query(`select ready from public.room_players where room_id = $1 and user_id = $2`, [roomId, userB]);
    assert.equal(pB.rows[0].ready, true);

    // Host A starts game via commit
    const actionId = "start_action_001";
    const commitRes = await db.query(`select public.rpc_commit_round($1) as val`, [
      JSON.stringify({
        uid: userA,
        roomId,
        actionType: "start_game",
        actionId,
        playerOrder: [userA, userB],
        expectedRoundVersion: null,
        round: {
          roundId: "round_test_1",
          roundNumber: 1,
          version: 0,
          status: "playing",
          publicState: { turnNumber: 0, currentPlayerId: userA, drawTargetId: userB },
          secretState: { dummy: true },
          hands: {
            [userA]: [{ id: "c1", suit: "hearts", rank: "A" }],
            [userB]: [{ id: "c2", suit: "diamonds", rank: "A" }]
          }
        },
        newDiscards: [],
        messages: [{ text: "اللعبة بدأت!", eventType: "match_started" }],
        completion: null,
        result: { ok: true }
      })
    ]);
    assert.equal(commitRes.rows[0].val.ok, true);

    // Idempotency: repeating same actionId returns previous result
    const repeatRes = await db.query(`select public.rpc_commit_round($1) as val`, [
      JSON.stringify({
        uid: userA,
        roomId,
        actionType: "start_game",
        actionId,
        playerOrder: [userA, userB],
        round: { roundId: "round_test_1", roundNumber: 1, version: 0, status: "playing", publicState: {}, secretState: {}, hands: {} }
      })
    ]);
    assert.equal(repeatRes.rows[0].val.alreadyApplied, true);
  });

  test("4. RLS Hand Privacy: Player A cannot read Player B's hand", async () => {
    const roomRow = await db.query(`select id from public.rooms where code = 'SH7K29'`);
    const roomId = roomRow.rows[0].id;

    await db.exec(`set role authenticated; set "request.jwt.claim.sub" = '${userA}';`);
    try {
      // Player A reads their own hand -> 1 card
      const myHand = await db.query(`select * from public.player_hands where room_id = $1 and user_id = $2`, [roomId, userA]);
      assert.equal(myHand.rows.length, 1);
      assert.equal(myHand.rows[0].cards[0].id, "c1");

      // Player A tries to query Player B's hand -> RLS returns 0 rows!
      const opponentHand = await db.query(`select * from public.player_hands where room_id = $1 and user_id = $2`, [roomId, userB]);
      assert.equal(opponentHand.rows.length, 0);
    } finally {
      await db.exec(`reset role; reset "request.jwt.claim.sub";`);
    }
  });

  test("5. Chat: Player can send message; rate limiting and system impersonation blocked", async () => {
    const roomRow = await db.query(`select id from public.rooms where code = 'SH7K29'`);
    const roomId = roomRow.rows[0].id;

    // Valid message
    const msgRes = await db.query(`select public.rpc_send_chat($1) as val`, [
      JSON.stringify({ uid: userA, roomId, text: "مساء الخير يا رجالة!", type: "user" })
    ]);
    assert.ok(msgRes.rows[0].val.messageId);

    // Rapid spam within 750ms -> rejected with rate limit
    await assert.rejects(
      async () => {
        await db.query(`select public.rpc_send_chat($1)`, [
          JSON.stringify({ uid: userA, roomId, text: "سبام سريع", type: "user" })
        ]);
      },
      /بالراحة يا معلم، استنى لحظة بين الرسايل/
    );

    // Client attempting to send forged type='system' message -> rejected
    await assert.rejects(
      async () => {
        await db.query(`select public.rpc_send_chat($1)`, [
          JSON.stringify({ uid: userA, roomId, text: "تزوير نظام", type: "system" })
        ]);
      },
      /نوع الرسالة غير متاح/
    );
  });

  test("6. Challenges: 30 challenges seeded and assignable", async () => {
    const countRes = await db.query(`select count(*) from public.challenges where enabled = true`);
    assert.equal(Number(countRes.rows[0].count), 30);
  });

  test("7. Discarded pairs RLS, blocked client mutations, stats/leaderboard & rematch cleanup", async () => {
    const createRes = await db.query(`select public.rpc_create_room($1) as val`, [
      JSON.stringify({
        uid: userA,
        nickname: "المعلم أحمد",
        avatarId: "avatar_1",
        code: "LB1RND",
        title: "قعدة الحسم",
        maxPlayers: 2,
        totalRounds: 1,
        challengeMode: "every_round",
        visibility: "private"
      })
    ]);
    const roomId = createRes.rows[0].val.roomId;

    await db.query(`select public.rpc_join_room($1)`, [
      JSON.stringify({ uid: userB, code: "LB1RND", nickname: "كريم", avatarId: "avatar_2" })
    ]);
    await db.query(`select public.rpc_set_ready($1)`, [
      JSON.stringify({ uid: userB, roomId, ready: true })
    ]);

    // Start round 1 with an initial discarded pair
    await db.query(`select public.rpc_commit_round($1)`, [
      JSON.stringify({
        uid: userA,
        roomId,
        actionType: "start_game",
        actionId: "lb_start_01",
        playerOrder: [userA, userB],
        expectedRoundVersion: null,
        round: {
          roundId: "round_lb_1",
          roundNumber: 1,
          version: 0,
          status: "playing",
          publicState: { turnNumber: 0, currentPlayerId: userA, drawTargetId: userB },
          secretState: { id: "round_lb_1", version: 0 },
          hands: {
            [userA]: [{ id: "8S", suit: "spades", rank: "8" }],
            [userB]: [{ id: "KH", suit: "hearts", rank: "K", isShayeb: true }]
          }
        },
        newDiscards: [
          {
            turnNumber: 0,
            userId: null,
            cards: [{ id: "7H", suit: "hearts", rank: "7" }, { id: "7D", suit: "diamonds", rank: "7" }]
          }
        ],
        messages: [],
        completion: null,
        result: { ok: true }
      })
    ]);

    // During active round: discarded_pairs hidden, game_secrets/chat insert/stats update blocked
    await db.exec(`set role authenticated; set "request.jwt.claim.sub" = '${userA}';`);
    try {
      const hiddenDiscards = await db.query(
        `select * from public.discarded_pairs where room_id = $1`,
        [roomId]
      );
      assert.equal(hiddenDiscards.rows.length, 0);

      await assert.rejects(
        () => db.query(`select * from public.game_secrets where room_id = $1`, [roomId]),
        /permission denied/
      );
      await assert.rejects(
        () => db.query(
          `insert into public.chat_messages (room_id, sender_id, sender_nickname, sender_avatar, type, text)
           values ($1, $2, 'مخترق', 'avatar_1', 'system', 'فوز وهمي')`,
          [roomId, userA]
        ),
        /permission denied/
      );
      await assert.rejects(
        () => db.query(`update public.profiles set total_points = 9999 where id = $1`, [userA]),
        /permission denied/
      );
    } finally {
      await db.exec(`reset role; reset "request.jwt.claim.sub";`);
    }

    // Complete round 1 (which also finishes the 1-round match)
    const finRes = await db.query(`select public.rpc_commit_round($1) as val`, [
      JSON.stringify({
        uid: userA,
        roomId,
        actionType: "draw_card",
        actionId: "lb_draw_fin",
        playerOrder: null,
        expectedRoundVersion: 0,
        round: {
          roundId: "round_lb_1",
          roundNumber: 1,
          version: 1,
          status: "finished",
          publicState: { turnNumber: 1, status: "finished", loserId: userB, finishOrder: [userA, userB] },
          secretState: { id: "round_lb_1", version: 1, status: "finished" },
          hands: {
            [userA]: [],
            [userB]: [{ id: "KH", suit: "hearts", rank: "K", isShayeb: true }]
          }
        },
        newDiscards: [
          {
            turnNumber: 1,
            userId: userA,
            cards: [{ id: "8S", suit: "spades", rank: "8" }, { id: "8C", suit: "clubs", rank: "8" }]
          }
        ],
        messages: [],
        completion: {
          loserId: userB,
          winnerId: userA,
          finishOrder: [userA, userB],
          points: { [userA]: 10, [userB]: 0 }
        },
        result: { applied: true, roundFinished: true }
      })
    ]);
    assert.equal(finRes.rows[0].val.matchOver, true);
    assert.ok(finRes.rows[0].val.instanceId);

    // Verify challenge auto-assignment & lifetime stats updates
    const assignRows = await db.query(
      `select loser_id, status from public.challenge_assignments where room_id = $1`,
      [roomId]
    );
    assert.equal(assignRows.rows.length, 1);
    assert.equal(assignRows.rows[0].loser_id, userB);
    assert.equal(assignRows.rows[0].status, "pending");

    const profRows = await db.query(
      `select id, games_played, rounds_played, rounds_won, rounds_lost, matches_won, total_points
         from public.profiles where id in ($1, $2) order by total_points desc`,
      [userA, userB]
    );
    assert.equal(profRows.rows[0].id, userA);
    assert.equal(profRows.rows[0].games_played, 1);
    assert.equal(profRows.rows[0].rounds_played, 1);
    assert.equal(profRows.rows[0].matches_won, 1);
    assert.equal(profRows.rows[0].total_points, 10);
    assert.equal(profRows.rows[1].id, userB);
    assert.equal(profRows.rows[1].rounds_lost, 1);

    // After round finishes: authenticated player sees discarded_pairs & full leaderboard view
    await db.exec(`set role authenticated; set "request.jwt.claim.sub" = '${userB}';`);
    try {
      const revealedDiscards = await db.query(
        `select turn_number from public.discarded_pairs where room_id = $1 order by turn_number`,
        [roomId]
      );
      assert.equal(revealedDiscards.rows.length, 2);

      const board = await db.query(`select id, total_points, rank from public.leaderboard order by rank`);
      assert.equal(board.rows.length, 2);
      assert.equal(board.rows[0].id, userA);
      assert.equal(board.rows[0].total_points, 10);
    } finally {
      await db.exec(`reset role; reset "request.jwt.claim.sub";`);
    }

    // Rematch clears stale hands/state/secrets and increments match_number
    const rematchRes = await db.query(`select public.rpc_restart_match($1) as val`, [
      JSON.stringify({ uid: userA, roomId })
    ]);
    assert.equal(rematchRes.rows[0].val.ok, true);

    const roomAfter = await db.query(`select status, round_number, match_number from public.rooms where id = $1`, [roomId]);
    assert.equal(roomAfter.rows[0].status, "waiting");
    assert.equal(roomAfter.rows[0].round_number, 0);
    assert.equal(roomAfter.rows[0].match_number, 2);

    const leftoverHands = await db.query(`select count(*) from public.player_hands where room_id = $1`, [roomId]);
    const leftoverStates = await db.query(`select count(*) from public.game_states where room_id = $1`, [roomId]);
    const leftoverSecrets = await db.query(`select count(*) from public.game_secrets where room_id = $1`, [roomId]);
    assert.equal(Number(leftoverHands.rows[0].count), 0);
    assert.equal(Number(leftoverStates.rows[0].count), 0);
    assert.equal(Number(leftoverSecrets.rows[0].count), 0);
  });

  test("8. Pre-deploy Migration 7: Challenge mode enforcement & loser-only action", async () => {
    // A. Disabled challenge_mode blocks rpc_assign_challenge
    const disCreate = await db.query(`select public.rpc_create_room($1) as val`, [
      JSON.stringify({
        uid: userA, nickname: "أحمد", avatarId: "avatar_1",
        code: "CHDIS1", maxPlayers: 2, totalRounds: 1, challengeMode: "disabled"
      })
    ]);
    const disRoomId = disCreate.rows[0].val.roomId;
    await db.query(`select public.rpc_join_room($1)`, [
      JSON.stringify({ uid: userB, code: "CHDIS1", nickname: "كريم", avatarId: "avatar_2" })
    ]);
    await db.query(`select public.rpc_set_ready($1)`, [
      JSON.stringify({ uid: userB, roomId: disRoomId, ready: true })
    ]);
    await db.query(`select public.rpc_commit_round($1)`, [
      JSON.stringify({
        uid: userA, roomId: disRoomId, actionType: "start_game", actionId: "dis_start_action_01",
        playerOrder: [userA, userB], expectedRoundVersion: null,
        round: {
          roundId: "r_dis_1", roundNumber: 1, version: 1, status: "finished",
          publicState: { status: "finished", loserId: userB, finishOrder: [userA, userB] },
          secretState: { id: "r_dis_1", status: "finished" },
          hands: { [userA]: [], [userB]: [] }
        },
        newDiscards: [], messages: [],
        completion: { loserId: userB, winnerId: userA, finishOrder: [userA, userB], points: { [userA]: 5, [userB]: 0 } }
      })
    ]);
    await assert.rejects(
      () => db.query(`select public.rpc_assign_challenge($1)`, [JSON.stringify({ uid: userA, roomId: disRoomId })]),
      /نظام الأحكام مقفول في القعدة دي دلوقتي/
    );

    // B. end_of_match blocks mid-match rpc_assign_challenge while status = round_results
    const eomCreate = await db.query(`select public.rpc_create_room($1) as val`, [
      JSON.stringify({
        uid: userA, nickname: "أحمد", avatarId: "avatar_1",
        code: "CHEOM1", maxPlayers: 2, totalRounds: 3, challengeMode: "end_of_match"
      })
    ]);
    const eomRoomId = eomCreate.rows[0].val.roomId;
    await db.query(`select public.rpc_join_room($1)`, [
      JSON.stringify({ uid: userB, code: "CHEOM1", nickname: "كريم", avatarId: "avatar_2" })
    ]);
    await db.query(`select public.rpc_set_ready($1)`, [
      JSON.stringify({ uid: userB, roomId: eomRoomId, ready: true })
    ]);
    await db.query(`select public.rpc_commit_round($1)`, [
      JSON.stringify({
        uid: userA, roomId: eomRoomId, actionType: "start_game", actionId: "eom_start_action_01",
        playerOrder: [userA, userB], expectedRoundVersion: null,
        round: {
          roundId: "r_eom_1", roundNumber: 1, version: 1, status: "finished",
          publicState: { status: "finished", loserId: userB, finishOrder: [userA, userB] },
          secretState: { id: "r_eom_1", status: "finished" },
          hands: { [userA]: [], [userB]: [] }
        },
        newDiscards: [], messages: [],
        completion: { loserId: userB, winnerId: userA, finishOrder: [userA, userB], points: { [userA]: 5, [userB]: 0 } }
      })
    ]);
    await assert.rejects(
      () => db.query(`select public.rpc_assign_challenge($1)`, [JSON.stringify({ uid: userA, roomId: eomRoomId })]),
      /نظام الأحكام مقفول في القعدة دي دلوقتي/
    );

    // C. Host cannot override or complete loser's challenge
    const losCreate = await db.query(`select public.rpc_create_room($1) as val`, [
      JSON.stringify({
        uid: userA, nickname: "أحمد", avatarId: "avatar_1",
        code: "CHLOS1", maxPlayers: 2, totalRounds: 1, challengeMode: "every_round"
      })
    ]);
    const losRoomId = losCreate.rows[0].val.roomId;
    await db.query(`select public.rpc_join_room($1)`, [
      JSON.stringify({ uid: userB, code: "CHLOS1", nickname: "كريم", avatarId: "avatar_2" })
    ]);
    await db.query(`select public.rpc_set_ready($1)`, [
      JSON.stringify({ uid: userB, roomId: losRoomId, ready: true })
    ]);
    await db.query(`select public.rpc_commit_round($1)`, [
      JSON.stringify({
        uid: userA, roomId: losRoomId, actionType: "start_game", actionId: "los_start_action_01",
        playerOrder: [userA, userB], expectedRoundVersion: null,
        round: {
          roundId: "r_los_1", roundNumber: 1, version: 1, status: "finished",
          publicState: { status: "finished", loserId: userB, finishOrder: [userA, userB] },
          secretState: { id: "r_los_1", status: "finished" },
          hands: { [userA]: [], [userB]: [] }
        },
        newDiscards: [], messages: [],
        completion: { loserId: userB, winnerId: userA, finishOrder: [userA, userB], points: { [userA]: 5, [userB]: 0 } }
      })
    ]);

    await assert.rejects(
      () => db.query(`select public.rpc_challenge_action($1)`, [
        JSON.stringify({ uid: userA, roomId: losRoomId, action: "complete", proofText: "تجاوز المضيف" })
      ]),
      /اللاعب اللي لبس الشايب بس هو اللي ينفذ أو يغير الحكم/
    );

    const loserRes = await db.query(`select public.rpc_challenge_action($1) as val`, [
      JSON.stringify({ uid: userB, roomId: losRoomId, action: "complete", proofText: "نفذته بنفسي" })
    ]);
    assert.equal(loserRes.rows[0].val.status, "completed");
  });

  test("9. Pre-deploy Migration 7: Storage metadata verification & 7-day media retention", async () => {
    const medCreate = await db.query(`select public.rpc_create_room($1) as val`, [
      JSON.stringify({
        uid: userA, nickname: "أحمد", avatarId: "avatar_1",
        code: "MED7D1", maxPlayers: 2, totalRounds: 1
      })
    ]);
    const roomId = medCreate.rows[0].val.roomId;
    await db.query(`select public.rpc_join_room($1)`, [
      JSON.stringify({ uid: userB, code: "MED7D1", nickname: "كريم", avatarId: "avatar_2" })
    ]);

    const goodPath = `${roomId}/${userB}/11111111-2222-4333-8444-555555555555.webp`;
    const spoofMimePath = `${roomId}/${userB}/22222222-3333-4444-8555-666666666666.png`;

    await db.query(
      `insert into storage.objects (bucket_id, name, owner, metadata) values
       ('shayeb-media', $1, $3, '{"size": 12000, "mimetype": "image/webp"}'::jsonb),
       ('shayeb-media', $2, $3, '{"size": 12000, "mimetype": "image/webp"}'::jsonb)`,
      [goodPath, spoofMimePath, userB]
    );

    // Rejects mismatched Storage metadata MIME
    await assert.rejects(
      () => db.query(`select public.rpc_attach_media($1)`, [
        JSON.stringify({
          uid: userB, roomId, kind: "image", bucket: "shayeb-media",
          path: spoofMimePath, mimeType: "image/png", sizeBytes: 12000
        })
      ]),
      /بيانات الملف الفعلية لا تطابق المطلوب/
    );

    // Rejects wrong bucket
    await assert.rejects(
      () => db.query(`select public.rpc_attach_media($1)`, [
        JSON.stringify({
          uid: userB, roomId, kind: "image", bucket: "other-bucket",
          path: goodPath, mimeType: "image/webp", sizeBytes: 12000
        })
      ]),
      /مسار الملف غير مسموح/
    );

    // Succeeds when bucket, path, and real Storage metadata match
    const attachRes = await db.query(`select public.rpc_attach_media($1) as val`, [
      JSON.stringify({
        uid: userB, roomId, kind: "image", bucket: "shayeb-media",
        path: goodPath, mimeType: "image/webp", sizeBytes: 12000
      })
    ]);
    const mediaId = attachRes.rows[0].val.mediaId;
    assert.ok(mediaId);

    const mediaRow = await db.query(
      `select expires_at > now() + interval '6 days' as retained from public.media_attachments where id = $1`,
      [mediaId]
    );
    assert.equal(mediaRow.rows[0].retained, true);

    const evMsgs = await db.query(
      `select type, media_id from public.chat_messages where room_id = $1 and media_id = $2`,
      [roomId, mediaId]
    );
    assert.equal(evMsgs.rows.length, 1);
    assert.equal(evMsgs.rows[0].type, "evidence");

    // Closing the room does NOT mark media expired early
    await db.query(`update public.rooms set status = 'closed' where id = $1`, [roomId]);
    const notExpired = await db.query(`select public.rpc_list_expired_media('{}'::jsonb) as val`);
    assert.equal(notExpired.rows[0].val.length, 0);

    // Once expires_at passes, rpc_list_expired_media returns it
    await db.query(`update public.media_attachments set expires_at = now() - interval '1 hour' where id = $1`, [mediaId]);
    const expired = await db.query(`select public.rpc_list_expired_media('{}'::jsonb) as val`);
    assert.equal(expired.rows[0].val.length, 1);
    assert.equal(expired.rows[0].val[0].id, mediaId);
  });
});
