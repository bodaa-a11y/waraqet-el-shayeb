import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getAdminClient, getCallerUid } from "../_shared/client.ts";
import {
  makeRound,
  drawCard as executeDraw,
  autoDrawOnTimeout,
  publicView,
  roundPoints,
  rankMatchPlayers,
  generateRoomCode,
  GameRuleError,
  type RoundState,
} from "../_shared/engine/index.ts";

function extractAction(req: Request, body: Record<string, unknown>): string {
  const url = new URL(req.url);
  const pathParts = url.pathname.split("/").filter(Boolean);
  // /functions/v1/game/<action> or /game/<action>
  if (pathParts.length > 0 && pathParts[pathParts.length - 1] !== "game") {
    return pathParts[pathParts.length - 1]!;
  }
  return typeof body.action === "string" ? body.action : "";
}

function toDiscardedPairs(
  cards: readonly unknown[],
  turnNumber: number,
  userId: string | null,
): Array<{ turnNumber: number; userId: string | null; cards: [unknown, unknown] }> {
  const out: Array<{ turnNumber: number; userId: string | null; cards: [unknown, unknown] }> = [];
  for (let i = 0; i + 1 < cards.length; i += 2) {
    out.push({ turnNumber, userId, cards: [cards[i], cards[i + 1]] });
  }
  return out;
}

function parseSqlError(err: unknown): { message: string; code: string; status: number } {
  const e = err as { code?: string; hint?: string; message?: string } | null;
  const raw = typeof e?.message === "string" ? e.message : "";
  // Only our controlled SQLSTATE SH001 messages are safe for player display.
  const knownHints = new Set([
    "unauthenticated", "forbidden", "not_found", "conflict", "invalid",
    "rate_limited", "stale_version",
  ]);
  if (e?.code === "SH001" && typeof e.hint === "string" && knownHints.has(e.hint)) {
    const statusMap: Record<string, number> = {
      unauthenticated: 401, forbidden: 403, not_found: 404,
      conflict: 409, invalid: 400, rate_limited: 429, stale_version: 409,
    };
    return { message: raw || "تعذر تنفيذ العملية", code: e.hint, status: statusMap[e.hint] };
  }
  if (raw.includes("unauthenticated")) {
    return { message: "لازم تسجل دخول الأول", code: "unauthenticated", status: 401 };
  }
  // Diagnostics belong in protected server logs, never in client error text.
  console.error("game action failed", e);
  return { message: "حصلت مشكلة في السيرفر، جرّب تاني", code: "internal_error", status: 500 };
}

Deno.serve(async (req: Request) => {
  const corsRes = handleCors(req);
  if (corsRes) return corsRes;

  if (req.method !== "POST") {
    return errorResponse("طريقة الطلب غير مسموحة", "method_not_allowed", 405);
  }

  try {
    const adminClient = getAdminClient();
    const uid = await getCallerUid(req, adminClient);

    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch {
      body = {};
    }

    const action = extractAction(req, body);
    if (!action) {
      return errorResponse("لم يتم تحديد العملية المطلوبة", "missing_action", 400);
    }

    switch (action) {
      // ----------------------------------------------------------------------
      // 1. createRoom
      // ----------------------------------------------------------------------
      case "createRoom": {
        let code = "";
        for (let attempt = 0; attempt < 8; attempt++) {
          code = generateRoomCode(6);
          const { data, error } = await adminClient.rpc("rpc_create_room", {
            p: { ...body, uid, code },
          });
          if (!error) {
            return jsonResponse(data);
          }
          if (error.message.includes("code_taken")) {
            continue;
          }
          throw error;
        }
        return errorResponse("مش قادرين نطلع كود قعدة جديد دلوقتي، جرّب تاني", "resource_exhausted", 429);
      }

      // ----------------------------------------------------------------------
      // 2. joinRoomByCode & joinRoom
      // ----------------------------------------------------------------------
      case "joinRoom":
      case "joinRoomByCode": {
        const { data, error } = await adminClient.rpc("rpc_join_room", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 3. leaveRoom & kickPlayer
      // ----------------------------------------------------------------------
      case "leaveRoom": {
        const { data, error } = await adminClient.rpc("rpc_leave_room", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      case "kickPlayer": {
        const { data, error } = await adminClient.rpc("rpc_kick_player", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 4. setPlayerReady & setReady
      // ----------------------------------------------------------------------
      case "setReady":
      case "setPlayerReady": {
        const { data, error } = await adminClient.rpc("rpc_set_ready", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 5. updateRoomSettings & updateSettings
      // ----------------------------------------------------------------------
      case "updateSettings":
      case "updateRoomSettings": {
        const { data, error } = await adminClient.rpc("rpc_update_settings", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 6. startGame & startMatch
      // ----------------------------------------------------------------------
      case "startGame":
      case "startMatch": {
        const roomId = String(body.roomId || "");
        if (!roomId) return errorResponse("معرّف القعدة مطلوب", "invalid_argument", 400);

        const { data: ctx, error: ctxErr } = await adminClient.rpc("rpc_get_game_context", {
          p: { roomId, uid },
        });
        if (ctxErr) throw ctxErr;

        const room = ctx.room;
        if (room.hostId !== uid) {
          return errorResponse("صاحب القعدة بس هو اللي يقدر يبدأ اللعب", "forbidden", 403);
        }
        if (room.status !== "waiting") {
          return errorResponse("اللعبة شغالة بالفعل", "conflict", 409);
        }

        const players = room.players as Array<{ uid: string; ready: boolean; seat: number }>;
        if (players.length < 2 || !players.every((p) => p.ready || p.uid === room.hostId)) {
          return errorResponse("لازم على الأقل ٢ لعيبة وكلهم يكونوا جاهزين", "conflict", 409);
        }

        const playerOrder = players.map((p) => p.uid);
        const round = makeRound(playerOrder, {
          roundNumber: 1,
          direction: room.direction,
          turnTimerSeconds: room.turnTimerSeconds ?? 45,
          shuffleInitialFinishTies: true,
        });

        const pub = publicView(round);
        const actionId = `start_${roomId}_r1_${Date.now()}`;

        let completion = null;
        if (round.status === "finished") {
          const points = roundPoints(round.finishOrder);
          completion = {
            loserId: round.loserId,
            winnerId: round.finishOrder[0] || null,
            finishOrder: round.finishOrder,
            points,
          };
        }

        const { data: commitRes, error: commitErr } = await adminClient.rpc("rpc_commit_round", {
          p: {
            uid,
            roomId,
            actionType: "start_game",
            actionId,
            playerOrder,
            expectedRoundVersion: null,
            round: {
              roundId: round.id,
              roundNumber: 1,
              version: round.version,
              status: round.status,
              publicState: pub,
              secretState: round,
              hands: round.hands,
            },
            newDiscards: toDiscardedPairs(round.discarded, 0, null),
            messages: [],
            completion,
            result: { ok: true, roundId: round.id, version: round.version },
          },
        });
        if (commitErr) throw commitErr;
        return jsonResponse(commitRes);
      }

      // ----------------------------------------------------------------------
      // 7. drawCard & claimTurnTimeout
      // ----------------------------------------------------------------------
      case "drawCard": {
        const roomId = String(body.roomId || "");
        const actionId = String(body.actionId || "").trim();
        const cardIndex = Number(body.cardIndex ?? body.selectedCardPosition);
        const expectedVersion = Number(body.expectedVersion ?? body.expectedStateVersion);

        if (!roomId || !actionId) {
          return errorResponse("بيانات السحب غير مكتملة", "invalid_argument", 400);
        }
        if (!Number.isSafeInteger(cardIndex) || !Number.isSafeInteger(expectedVersion)) {
          return errorResponse("رقم الورقة أو إصدار الدور غير صالح", "invalid_argument", 400);
        }

        const { data: ctx, error: ctxErr } = await adminClient.rpc("rpc_get_game_context", {
          p: { roomId, uid },
        });
        if (ctxErr) throw ctxErr;

        // Idempotency check before checking playing state / calling executeDraw
        const { data: priorAction } = await adminClient
          .from("game_actions")
          .select("user_id, result")
          .eq("room_id", roomId)
          .eq("action_id", actionId)
          .maybeSingle();
        if (priorAction) {
          if (priorAction.user_id !== uid) {
            return errorResponse("الحركة دي تخص لاعب تاني", "forbidden", 403);
          }
          return jsonResponse({ ...(priorAction.result as Record<string, unknown>), applied: false, alreadyApplied: true });
        }

        const room = ctx.room;
        if (room.status !== "playing") {
          return errorResponse("الجولة مش شغالة دلوقتي", "conflict", 409);
        }
        const prevRound = ctx.secret as RoundState | undefined;
        if (!prevRound) {
          return errorResponse("بيانات الجولة مش موجودة", "not_found", 404);
        }

        let nextRound: RoundState;
        try {
          nextRound = executeDraw(prevRound, {
            actorId: uid,
            cardIndex,
            expectedVersion,
          });
        } catch (engineErr) {
          if (engineErr instanceof GameRuleError) {
            return errorResponse(engineErr.message, engineErr.code, 409);
          }
          throw engineErr;
        }

        const pub = publicView(nextRound);
        const players = room.players as Array<{ uid: string; nickname: string }>;
        const actorName = players.find((p) => p.uid === uid)?.nickname ?? "لاعب";
        const targetId = nextRound.lastMove?.targetId;
        const targetName = players.find((p) => p.uid === targetId)?.nickname ?? "لاعب";

        const messages: Array<{ text: string; eventType: string }> = [];
        if ((nextRound.lastMove?.pairsRemoved ?? 0) > 0) {
          messages.push({
            text: `عاش! ${actorName} سحب من ${targetName} ونزل جوز 🎯`,
            eventType: "pair_matched",
          });
        }
        for (const esc of nextRound.lastMove?.finishedPlayerIds ?? []) {
          const escName = players.find((p) => p.uid === esc)?.nickname ?? "لاعب";
          messages.push({
            text: `${escName} صفّى ورقه وفلت من الشايب! 🏃‍♂️✨`,
            eventType: "player_escaped",
          });
        }

        let completion = null;
        if (nextRound.status === "finished") {
          const points = roundPoints(nextRound.finishOrder);
          completion = {
            loserId: nextRound.loserId,
            winnerId: nextRound.finishOrder[0] || null,
            finishOrder: nextRound.finishOrder,
            points,
          };
        }

        const { data: commitRes, error: commitErr } = await adminClient.rpc("rpc_commit_round", {
          p: {
            uid,
            roomId,
            actionType: "draw_card",
            actionId,
            playerOrder: null,
            expectedRoundVersion: expectedVersion,
            round: {
              roundId: nextRound.id,
              roundNumber: room.roundNumber,
              version: nextRound.version,
              status: nextRound.status,
              publicState: pub,
              secretState: nextRound,
              hands: nextRound.hands,
            },
            newDiscards: toDiscardedPairs(nextRound.discarded.slice(prevRound.discarded.length), nextRound.turnNumber, uid),
            messages,
            completion,
            result: {
              applied: true,
              alreadyApplied: false,
              version: nextRound.version,
              pairsRemoved: nextRound.lastMove?.pairsRemoved ?? 0,
              roundFinished: nextRound.status === "finished",
            },
          },
        });
        if (commitErr) throw commitErr;
        return jsonResponse(commitRes);
      }

      case "claimTurnTimeout": {
        const roomId = String(body.roomId || "");
        const expectedVersion = Number(body.expectedVersion ?? -1);
        if (!roomId || expectedVersion < 0) {
          return errorResponse("بيانات انتهاء الوقت غير صالحة", "invalid_argument", 400);
        }

        const { data: ctx, error: ctxErr } = await adminClient.rpc("rpc_get_game_context", {
          p: { roomId, uid },
        });
        if (ctxErr) throw ctxErr;

        const room = ctx.room;
        if (room.status !== "playing") {
          return jsonResponse({ applied: false, reason: "not_playing" });
        }
        const prevRound = ctx.secret as RoundState | undefined;
        if (!prevRound || prevRound.version !== expectedVersion) {
          return jsonResponse({ applied: false, reason: "version_changed" });
        }

        const nowMs = Date.now();
        if (!prevRound.turnDeadlineMs || nowMs < prevRound.turnDeadlineMs - 1000) {
          return jsonResponse({ applied: false, reason: "deadline_not_reached" });
        }

        const timedOutUid = prevRound.currentPlayerId!;
        const players = room.players as Array<{ uid: string; nickname: string }>;
        const timedOutName = players.find((p) => p.uid === timedOutUid)?.nickname ?? "لاعب";

        const nextRound = autoDrawOnTimeout(prevRound, expectedVersion, nowMs);
        const pub = publicView(nextRound);
        const actionId = `timeout_${roomId}_v${expectedVersion}_${nowMs}`;

        const messages: Array<{ text: string; eventType: string }> = [
          {
            text: `وقت ${timedOutName} خلص! النظام سحب له ورقة عشوائية ⏱️`,
            eventType: "turn_timeout",
          },
        ];

        let completion = null;
        if (nextRound.status === "finished") {
          const points = roundPoints(nextRound.finishOrder);
          completion = {
            loserId: nextRound.loserId,
            winnerId: nextRound.finishOrder[0] || null,
            finishOrder: nextRound.finishOrder,
            points,
          };
        }

        const { data: commitRes, error: commitErr } = await adminClient.rpc("rpc_commit_round", {
          p: {
            uid,
            roomId,
            actionType: "claim_timeout",
            actionId,
            playerOrder: null,
            expectedRoundVersion: expectedVersion,
            round: {
              roundId: nextRound.id,
              roundNumber: room.roundNumber,
              version: nextRound.version,
              status: nextRound.status,
              publicState: pub,
              secretState: nextRound,
              hands: nextRound.hands,
            },
            newDiscards: toDiscardedPairs(nextRound.discarded.slice(prevRound.discarded.length), nextRound.turnNumber, timedOutUid),
            messages,
            completion,
            result: { applied: true, version: nextRound.version },
          },
        });
        if (commitErr) throw commitErr;
        return jsonResponse(commitRes);
      }

      // ----------------------------------------------------------------------
      // 8. getRoomState & getMatchStandings
      // ----------------------------------------------------------------------
      case "getRoomState":
      case "getMatchStandings": {
        const roomId = String(body.roomId || "");
        if (!roomId) return errorResponse("معرّف القعدة مطلوب", "invalid_argument", 400);

        const { data: ctx, error: ctxErr } = await adminClient.rpc("rpc_get_game_context", {
          p: { roomId, uid },
        });
        if (ctxErr) throw ctxErr;

        const room = ctx.room;
        const [pubSnap, handSnap] = await Promise.all([
          adminClient.from("game_states").select("public_state").eq("room_id", roomId).maybeSingle(),
          adminClient.from("player_hands").select("cards").eq("room_id", roomId).eq("user_id", uid).maybeSingle(),
        ]);

        const players = room.players as Array<{ uid: string; score: number; losses: number; firstFinishes: number }>;
        const scores: Record<string, number> = {};
        const losses: Record<string, number> = {};
        const firstFinishes: Record<string, number> = {};
        for (const p of players) {
          scores[p.uid] = p.score;
          losses[p.uid] = p.losses;
          firstFinishes[p.uid] = p.firstFinishes;
        }

        const standings = rankMatchPlayers(players.map((p) => p.uid), scores, losses, firstFinishes);

        // Latest challenge of the current match (shape matches Flutter ActiveChallengeModel)
        const { data: ca } = await adminClient
          .from("challenge_assignments")
          .select("instance_id, round_number, loser_id, loser_nickname, status, redraw_count, proof_text, media_id, challenges(id, title, description, category, proof_type, estimated_duration_seconds)")
          .eq("room_id", roomId)
          .eq("match_number", room.matchNumber)
          .order("assigned_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        // deno-lint-ignore no-explicit-any
        const ch: any = ca ? (Array.isArray(ca.challenges) ? ca.challenges[0] : ca.challenges) : null;
        const activeChallenge = ca && ch
          ? {
            instanceId: ca.instance_id,
            roundNumber: ca.round_number,
            loserUid: ca.loser_id,
            loserNickname: ca.loser_nickname,
            status: ca.status,
            redrawCount: ca.redraw_count,
            proofText: ca.proof_text,
            proofMediaId: ca.media_id,
            challenge: {
              id: ch.id,
              title: ch.title,
              description: ch.description,
              category: ch.category,
              proofType: ch.proof_type,
              estimatedDurationSeconds: ch.estimated_duration_seconds,
            },
          }
          : null;

        return jsonResponse({
          ...room,
          roomId,
          scores,
          losses,
          firstFinishes,
          activeChallenge,
          room,
          publicRound: pubSnap.data?.public_state ?? null,
          ownHand: handSnap.data?.cards ?? [],
          standings,
        });
      }

      // ----------------------------------------------------------------------
      // 9. advanceToNextRound & nextRound
      // ----------------------------------------------------------------------
      case "nextRound":
      case "advanceToNextRound": {
        const roomId = String(body.roomId || "");
        if (!roomId) return errorResponse("معرّف القعدة مطلوب", "invalid_argument", 400);

        const { data: ctx, error: ctxErr } = await adminClient.rpc("rpc_get_game_context", {
          p: { roomId, uid },
        });
        if (ctxErr) throw ctxErr;

        const room = ctx.room;
        if (room.hostId !== uid) {
          return errorResponse("صاحب القعدة بس هو اللي يبدأ الجولة الجديدة", "forbidden", 403);
        }
        if (room.status !== "round_results" || room.roundNumber >= room.totalRounds) {
          return errorResponse("مفيش جولة تانية متاحة", "conflict", 409);
        }

        const nextRoundNumber = room.roundNumber + 1;
        const players = room.players as Array<{ uid: string }>;
        const playerOrder = players.map((p) => p.uid);

        const round = makeRound(playerOrder, {
          roundNumber: nextRoundNumber,
          direction: room.direction,
          turnTimerSeconds: room.turnTimerSeconds ?? 45,
          shuffleInitialFinishTies: true,
        });

        const pub = publicView(round);
        const actionId = `next_${roomId}_r${nextRoundNumber}_${Date.now()}`;

        let completion = null;
        if (round.status === "finished") {
          const points = roundPoints(round.finishOrder);
          completion = {
            loserId: round.loserId,
            winnerId: round.finishOrder[0] || null,
            finishOrder: round.finishOrder,
            points,
          };
        }

        const { data: commitRes, error: commitErr } = await adminClient.rpc("rpc_commit_round", {
          p: {
            uid,
            roomId,
            actionType: "next_round",
            actionId,
            playerOrder,
            expectedRoundVersion: null,
            round: {
              roundId: round.id,
              roundNumber: nextRoundNumber,
              version: round.version,
              status: round.status,
              publicState: pub,
              secretState: round,
              hands: round.hands,
            },
            newDiscards: toDiscardedPairs(round.discarded, 0, null),
            messages: [],
            completion,
            result: { ok: true, roundId: round.id, roundNumber: nextRoundNumber },
          },
        });
        if (commitErr) throw commitErr;
        return jsonResponse(commitRes);
      }

      // ----------------------------------------------------------------------
      // 10. assignChallenge
      // ----------------------------------------------------------------------
      case "assignChallenge": {
        const { data, error } = await adminClient.rpc("rpc_assign_challenge", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 11. completeChallenge & redrawChallenge & handleChallengeAction
      // ----------------------------------------------------------------------
      case "completeChallenge": {
        const actionType = body.skip === true ? "skip" : "complete";
        const { data, error } = await adminClient.rpc("rpc_challenge_action", {
          p: { ...body, uid, action: actionType },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      case "redrawChallenge": {
        const { data, error } = await adminClient.rpc("rpc_challenge_action", {
          p: { ...body, uid, action: "redraw" },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      case "handleChallengeAction": {
        const { data, error } = await adminClient.rpc("rpc_challenge_action", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 12. sendChatMessage & sendRoomMessage
      // ----------------------------------------------------------------------
      case "sendRoomMessage":
      case "sendChatMessage": {
        const { data, error } = await adminClient.rpc("rpc_send_chat", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 13. restartMatch & rematchRoom
      // ----------------------------------------------------------------------
      case "rematchRoom":
      case "restartMatch": {
        const { data, error } = await adminClient.rpc("rpc_restart_match", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      // ----------------------------------------------------------------------
      // 14. saveProfile
      // ----------------------------------------------------------------------
      case "saveProfile": {
        const { data, error } = await adminClient.rpc("rpc_save_profile", {
          p: { ...body, uid },
        });
        if (error) throw error;
        return jsonResponse(data);
      }

      default:
        return errorResponse(`العملية «${action}» غير معروفة`, "unknown_action", 400);
    }
  } catch (err) {
    const { message, code, status } = parseSqlError(err);
    return errorResponse(message, code, status);
  }
});
