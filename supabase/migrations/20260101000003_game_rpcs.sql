-- =============================================================================
-- Migration 3/6 — server-authoritative RPCs (atomic transactions)
--
-- Every RPC:
--   * takes ONE jsonb argument `p` and returns jsonb,
--   * is SECURITY DEFINER with a pinned search_path,
--   * is executable by `service_role` ONLY (Edge Functions), never by clients,
--   * receives the caller's id as p->>'uid' — set by the Edge Function from the
--     VERIFIED user JWT (never from client-supplied JSON),
--   * runs in a single transaction: any exception rolls back ALL writes, so a
--     failed operation can never leave a partially updated game.
-- Errors are raised with SQLSTATE 'SH001', MESSAGE = Arabic text for players,
-- HINT = machine code (not_found | forbidden | conflict | invalid | rate_limited
-- | unauthenticated | stale_version).
-- =============================================================================

create or replace function private.fail(p_code text, p_msg text)
returns void
language plpgsql
as $$
begin
  raise exception '%', p_msg using errcode = 'SH001', hint = p_code;
end;
$$;

create or replace function private.caller(p jsonb)
returns uuid
language plpgsql
as $$
declare v uuid;
begin
  begin
    v := (p->>'uid')::uuid;
  exception when others then
    v := null;
  end;
  if v is null then
    perform private.fail('unauthenticated', 'لازم تسجل دخول الأول عشان تلعب');
  end if;
  return v;
end;
$$;

create or replace function private.clean_nickname(p_raw text)
returns text
language plpgsql
as $$
declare v text := btrim(regexp_replace(coalesce(p_raw, ''), '[<>]', '', 'g'));
begin
  if char_length(v) < 2 or char_length(v) > 24 then
    perform private.fail('invalid', 'الاسم لازم يكون بين حرفين و ٢٤ حرف');
  end if;
  if lower(v) in ('النظام','سيستم','system','admin','أدمن','المشرف') then
    perform private.fail('invalid', 'الاسم ده محجوز للنظام، اختار اسم تاني يا معلم');
  end if;
  return v;
end;
$$;

create or replace function private.clean_avatar(p_raw text)
returns text
language sql
immutable
as $$
  select case when p_raw ~ '^[a-z0-9_]{1,32}$' then p_raw else 'avatar_1' end;
$$;

create or replace function private.sys_msg(p_room uuid, p_text text, p_event text default 'info')
returns void
language sql
as $$
  insert into public.chat_messages (room_id, sender_id, sender_nickname, sender_avatar, type, event_type, text)
  values (p_room, null, 'قهوة الشايب', 'system', 'system', p_event, p_text);
$$;

-- Validated, normalized room settings (shared by create + update)
create or replace function private.validate_settings(p jsonb, p_host_nick text)
returns jsonb
language plpgsql
as $$
declare
  v_max     int  := coalesce((p->>'maxPlayers')::int, 4);
  v_rounds  int  := coalesce((p->>'totalRounds')::int, 5);
  v_dir     text := coalesce(p->>'direction', 'clockwise');
  v_vis     text := coalesce(p->>'visibility', 'private');
  v_mode    text := coalesce(p->>'challengeMode', 'every_round');
  v_timer   int  := coalesce((p->>'turnTimerSeconds')::int, 45);
  v_title   text := btrim(regexp_replace(coalesce(p->>'title', ''), '[<>]', '', 'g'));
begin
  if v_max < 2 or v_max > 6 then
    perform private.fail('invalid', 'عدد اللعيبة لازم يكون بين ٢ و ٦');
  end if;
  if v_rounds not in (1, 3, 5) then
    perform private.fail('invalid', 'عدد الجولات لازم يكون ١ أو ٣ أو ٥');
  end if;
  if v_dir not in ('clockwise', 'counterclockwise') then
    perform private.fail('invalid', 'اتجاه السحب غير صالح');
  end if;
  if v_vis not in ('private', 'public') then
    perform private.fail('invalid', 'نوع القعدة غير صالح');
  end if;
  if v_mode not in ('every_round', 'end_of_match', 'disabled') then
    perform private.fail('invalid', 'نظام الأحكام غير صالح');
  end if;
  if v_timer <> 0 and (v_timer < 15 or v_timer > 120) then
    perform private.fail('invalid', 'وقت الدور لازم يكون بين ١٥ و ١٢٠ ثانية أو مقفول');
  end if;
  if char_length(v_title) < 2 or char_length(v_title) > 36 then
    v_title := 'قعدة ' || p_host_nick;
    if char_length(v_title) > 36 then v_title := left(v_title, 36); end if;
  end if;
  return jsonb_build_object(
    'title', v_title, 'maxPlayers', v_max, 'totalRounds', v_rounds, 'direction', v_dir,
    'visibility', v_vis, 'challengeMode', v_mode, 'turnTimerSeconds', v_timer);
end;
$$;

-- Random non-repeating challenge pick (resets the pool when exhausted)
create or replace function private.pick_challenge(p_used text[], p_exclude text default null)
returns text
language plpgsql
as $$
declare v text;
begin
  select c.id into v from public.challenges c
  where c.enabled and c.id <> all (coalesce(p_used, '{}')) and c.id is distinct from p_exclude
  order by random() limit 1;
  if v is null then
    select c.id into v from public.challenges c
    where c.enabled and c.id is distinct from p_exclude
    order by random() limit 1;
  end if;
  if v is null then
    perform private.fail('conflict', 'مفيش أحكام متاحة دلوقتي');
  end if;
  return v;
end;
$$;

-- Full room snapshot for the server (never contains hands)
create or replace function private.room_json(p_room uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', r.id, 'code', r.code, 'hostId', r.host_id, 'title', r.title,
    'visibility', r.visibility, 'maxPlayers', r.max_players, 'totalRounds', r.total_rounds,
    'direction', r.direction, 'challengeMode', r.challenge_mode,
    'turnTimerSeconds', r.turn_timer_seconds, 'status', r.status,
    'roundNumber', r.round_number, 'matchNumber', r.match_number,
    'lastLoserId', r.last_loser_id,
    'players', coalesce((
      select jsonb_agg(jsonb_build_object(
        'uid', rp.user_id, 'nickname', rp.nickname, 'avatarId', rp.avatar_id,
        'seat', rp.seat, 'ready', rp.ready, 'isConnected', rp.is_connected,
        'temporaryTitle', rp.temporary_title, 'score', rp.score,
        'losses', rp.losses, 'firstFinishes', rp.first_finishes) order by rp.seat)
      from public.room_players rp where rp.room_id = r.id), '[]'::jsonb))
  from public.rooms r where r.id = p_room;
$$;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
create or replace function public.rpc_save_profile(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_nick text := private.clean_nickname(p->>'nickname');
  v_av text := private.clean_avatar(p->>'avatarId');
begin
  insert into public.profiles (id, nickname, avatar_id)
  values (v_uid, v_nick, v_av)
  on conflict (id) do update set nickname = excluded.nickname, avatar_id = excluded.avatar_id;
  return jsonb_build_object('ok', true, 'nickname', v_nick, 'avatarId', v_av);
end;
$$;

-- ---------------------------------------------------------------------------
-- Rooms
-- ---------------------------------------------------------------------------
create or replace function public.rpc_create_room(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_nick text := private.clean_nickname(p->>'nickname');
  v_av text := private.clean_avatar(p->>'avatarId');
  v_code text := upper(btrim(coalesce(p->>'code', '')));
  v_s jsonb := private.validate_settings(p, v_nick);
  v_room uuid;
begin
  if v_code !~ '^[A-Z0-9]{4,8}$' then
    perform private.fail('invalid', 'كود القعدة غير صالح');
  end if;

  insert into public.profiles (id, nickname, avatar_id)
  values (v_uid, v_nick, v_av)
  on conflict (id) do update set nickname = excluded.nickname, avatar_id = excluded.avatar_id;

  begin
    insert into public.rooms (code, host_id, title, visibility, max_players, total_rounds,
                              direction, challenge_mode, turn_timer_seconds)
    values (v_code, v_uid, v_s->>'title', v_s->>'visibility', (v_s->>'maxPlayers')::int,
            (v_s->>'totalRounds')::int, v_s->>'direction', v_s->>'challengeMode',
            (v_s->>'turnTimerSeconds')::int)
    returning id into v_room;
  exception when unique_violation then
    perform private.fail('conflict', 'code_taken');
  end;

  insert into public.room_players (room_id, user_id, nickname, avatar_id, seat, ready, is_connected)
  values (v_room, v_uid, v_nick, v_av, 0, true, true);

  perform private.sys_msg(v_room, v_nick || ' فتح القعدة! مستنيين باقي الشلة ☕', 'room_created');
  return jsonb_build_object('roomId', v_room, 'code', v_code);
end;
$$;

create or replace function public.rpc_join_room(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_nick text := private.clean_nickname(p->>'nickname');
  v_av text := private.clean_avatar(p->>'avatarId');
  v_code text := upper(btrim(coalesce(p->>'code', '')));
  v_by_id uuid;
  r public.rooms;
  v_seat int;
  v_count int;
begin
  if v_code <> '' then
    -- Invite code is verified HERE, on the server, against the database.
    select * into r from public.rooms where code = v_code for update;
  else
    begin
      v_by_id := (p->>'roomId')::uuid;
    exception when others then
      v_by_id := null;
    end;
    if v_by_id is null then
      perform private.fail('invalid', 'لازم تكتب كود القعدة');
    end if;
    select * into r from public.rooms where id = v_by_id for update;
  end if;

  if not found or r.status = 'closed' then
    perform private.fail('not_found', 'كود القعدة ده مش موجود، اتأكد من الكود يا نجم');
  end if;

  -- Reconnect of an existing member
  if exists (select 1 from public.room_players where room_id = r.id and user_id = v_uid) then
    update public.room_players
       set is_connected = true,
           nickname = case when r.status = 'waiting' then v_nick else nickname end,
           avatar_id = case when r.status = 'waiting' then v_av else avatar_id end
     where room_id = r.id and user_id = v_uid;
    return jsonb_build_object('roomId', r.id, 'code', r.code, 'reconnected', true);
  end if;

  -- A private room can only be entered with its code (a bare room id is not enough)
  if v_code = '' and r.visibility = 'private' then
    perform private.fail('forbidden', 'القعدة الخاصة لازم تدخلها بالكود');
  end if;
  if v_uid = any (r.banned_user_ids) then
    perform private.fail('forbidden', 'صاحب القعدة خرجك من القعدة دي');
  end if;
  if r.status <> 'waiting' then
    perform private.fail('conflict', 'اللعب بدأ خلاص في القعدة دي!');
  end if;
  select count(*) into v_count from public.room_players where room_id = r.id;
  if v_count >= r.max_players then
    perform private.fail('conflict', 'القعدة كومبليت ومفيش كراسي فاضية!');
  end if;

  select s into v_seat from generate_series(0, 5) s
   where not exists (select 1 from public.room_players where room_id = r.id and seat = s)
   order by s limit 1;

  insert into public.profiles (id, nickname, avatar_id)
  values (v_uid, v_nick, v_av)
  on conflict (id) do update set nickname = excluded.nickname, avatar_id = excluded.avatar_id;

  insert into public.room_players (room_id, user_id, nickname, avatar_id, seat, ready, is_connected)
  values (r.id, v_uid, v_nick, v_av, v_seat, false, true);

  perform private.sys_msg(r.id, v_nick || ' دخل القعدة! منور يا معلم 🔥', 'player_joined');
  return jsonb_build_object('roomId', r.id, 'code', r.code, 'reconnected', false);
end;
$$;

create or replace function public.rpc_leave_room(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  r public.rooms;
  me public.room_players;
  v_next uuid;
  v_next_nick text;
begin
  select * into r from public.rooms where id = (p->>'roomId')::uuid for update;
  if not found then return jsonb_build_object('ok', true); end if;
  select * into me from public.room_players where room_id = r.id and user_id = v_uid;
  if not found then return jsonb_build_object('ok', true); end if;

  if r.status in ('waiting', 'finished') then
    delete from public.room_players where room_id = r.id and user_id = v_uid;
    select user_id, nickname into v_next, v_next_nick
      from public.room_players where room_id = r.id order by seat limit 1;
    if v_next is null then
      update public.rooms set status = 'closed' where id = r.id;
      return jsonb_build_object('ok', true, 'closed', true);
    end if;
    if r.host_id = v_uid then
      update public.rooms set host_id = v_next where id = r.id;
      update public.room_players set ready = true where room_id = r.id and user_id = v_next;
      perform private.sys_msg(r.id, me.nickname || ' قام من القعدة وبقى ' || v_next_nick || ' هو صاحب القعدة', 'player_left');
    else
      perform private.sys_msg(r.id, me.nickname || ' قام من القعدة', 'player_left');
    end if;
    return jsonb_build_object('ok', true);
  end if;

  -- Mid-match: keep the seat, mark disconnected so the player can reconnect
  update public.room_players set is_connected = false where room_id = r.id and user_id = v_uid;
  if r.host_id = v_uid then
    select user_id into v_next from public.room_players
      where room_id = r.id and user_id <> v_uid
      order by is_connected desc, seat limit 1;
    if v_next is not null then
      update public.rooms set host_id = v_next where id = r.id;
    end if;
  end if;
  perform private.sys_msg(r.id, me.nickname || ' خرج مؤقتاً والنظام هيسحب مكانه لو دوره اتأخر', 'player_disconnected');
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.rpc_kick_player(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_target uuid := (p->>'targetUid')::uuid;
  r public.rooms;
  t public.room_players;
begin
  if v_target = v_uid then
    perform private.fail('invalid', 'مينفعش تطرد نفسك!');
  end if;
  select * into r from public.rooms where id = (p->>'roomId')::uuid for update;
  if not found then perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت'); end if;
  if r.host_id <> v_uid then
    perform private.fail('forbidden', 'صاحب القعدة بس هو اللي يقدر يخرج لاعب');
  end if;
  if r.status <> 'waiting' then
    perform private.fail('conflict', 'مينفعش تخرج حد بعد بداية الجولة');
  end if;
  select * into t from public.room_players where room_id = r.id and user_id = v_target;
  if not found then return jsonb_build_object('ok', true); end if;
  delete from public.room_players where room_id = r.id and user_id = v_target;
  update public.rooms set banned_user_ids = array_append(banned_user_ids, v_target) where id = r.id;
  perform private.sys_msg(r.id, 'تم استبعاد ' || t.nickname || ' من القعدة', 'player_kicked');
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.rpc_set_ready(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  r public.rooms;
  me public.room_players;
  v_ready boolean;
begin
  if jsonb_typeof(p->'ready') is distinct from 'boolean' then
    perform private.fail('invalid', 'قيمة الجاهزية غير صالحة');
  end if;
  v_ready := (p->>'ready')::boolean;
  select * into r from public.rooms where id = (p->>'roomId')::uuid for update;
  if not found then perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت'); end if;
  select * into me from public.room_players where room_id = r.id and user_id = v_uid;
  if not found then perform private.fail('forbidden', 'إنت مش عضو في القعدة دي'); end if;
  if r.status <> 'waiting' then
    perform private.fail('conflict', 'اللعبة بدأت خلاص');
  end if;
  update public.room_players set ready = v_ready where room_id = r.id and user_id = v_uid;
  if v_ready then
    perform private.sys_msg(r.id, me.nickname || ' جاهز للعب! ✅', 'player_ready');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.rpc_update_settings(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  r public.rooms;
  v_nick text;
  v_s jsonb;
  v_count int;
begin
  select * into r from public.rooms where id = (p->>'roomId')::uuid for update;
  if not found then perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت'); end if;
  if r.host_id <> v_uid then
    perform private.fail('forbidden', 'صاحب القعدة بس هو اللي يقدر يغير الإعدادات');
  end if;
  if r.status <> 'waiting' then
    perform private.fail('conflict', 'مينفعش تغير الإعدادات بعد ما اللعب يبدأ');
  end if;
  select nickname into v_nick from public.room_players where room_id = r.id and user_id = v_uid;
  v_s := private.validate_settings(p, coalesce(v_nick, 'المعلم'));
  select count(*) into v_count from public.room_players where room_id = r.id;
  if (v_s->>'maxPlayers')::int < v_count then
    perform private.fail('conflict', 'عدد اللعيبة الحالي أكبر من الحد الأقصى الجديد');
  end if;
  update public.rooms set
    title = v_s->>'title', visibility = v_s->>'visibility',
    max_players = (v_s->>'maxPlayers')::int, total_rounds = (v_s->>'totalRounds')::int,
    direction = v_s->>'direction', challenge_mode = v_s->>'challengeMode',
    turn_timer_seconds = (v_s->>'turnTimerSeconds')::int
  where id = r.id;
  perform private.sys_msg(r.id, 'صاحب القعدة حدّث إعدادات اللعب ⚙️', 'settings_updated');
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.rpc_restart_match(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  r public.rooms;
begin
  select * into r from public.rooms where id = (p->>'roomId')::uuid for update;
  if not found then perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت'); end if;
  if not exists (select 1 from public.room_players where room_id = r.id and user_id = v_uid) then
    perform private.fail('forbidden', 'إنت مش عضو في القعدة دي');
  end if;
  if r.host_id <> v_uid then
    perform private.fail('forbidden', 'صاحب القعدة بس هو اللي يقدر يعيد الماتش');
  end if;
  if r.status <> 'finished' then
    perform private.fail('conflict', 'مينفعش تعيد الماتش قبل ما يخلص');
  end if;

  update public.room_players
     set score = 0, losses = 0, first_finishes = 0, ready = true, temporary_title = null
   where room_id = r.id;
  -- Drop stale round data so old cards can never be served after a rematch
  delete from public.player_hands where room_id = r.id;
  delete from public.game_secrets where room_id = r.id;
  delete from public.game_states where room_id = r.id;
  update public.rooms
     set status = 'waiting', round_number = 0, match_number = match_number + 1,
         last_loser_id = null, used_challenge_ids = '{}'
   where id = r.id;
  perform private.sys_msg(r.id, 'هنعيدها من الأول! القعدة رجعت جاهزة لماتش جديد 🔄🔥', 'rematch_ready');
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------------
create or replace function public.rpc_send_chat(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_room uuid := (p->>'roomId')::uuid;
  v_type text := coalesce(p->>'type', 'user');
  v_text text := btrim(regexp_replace(coalesce(p->>'text', ''), '[<>]', '', 'g'));
  me public.room_players;
  v_last timestamptz;
  v_id uuid;
begin
  -- Clients can only ever send user/reaction messages; 'system' and 'evidence'
  -- are produced exclusively by server code paths.
  if v_type not in ('user', 'reaction') then
    perform private.fail('invalid', 'نوع الرسالة غير متاح');
  end if;
  if char_length(v_text) < 1 or char_length(v_text) > 300 then
    perform private.fail('invalid', 'الرسالة فاضية أو طويلة');
  end if;
  select * into me from public.room_players where room_id = v_room and user_id = v_uid;
  if not found then perform private.fail('forbidden', 'إنت مش عضو في القعدة دي'); end if;

  select last_sent_at into v_last from public.chat_rate
   where room_id = v_room and user_id = v_uid for update;
  if v_last is not null and clock_timestamp() - v_last < interval '750 milliseconds' then
    perform private.fail('rate_limited', 'بالراحة يا معلم، استنى لحظة بين الرسايل');
  end if;
  insert into public.chat_rate (room_id, user_id, last_sent_at)
  values (v_room, v_uid, clock_timestamp())
  on conflict (room_id, user_id) do update set last_sent_at = excluded.last_sent_at;

  -- Sender identity comes from the membership row, never from client input
  insert into public.chat_messages (room_id, sender_id, sender_nickname, sender_avatar, type, text)
  values (v_room, v_uid, me.nickname, me.avatar_id, v_type, v_text)
  returning id into v_id;
  return jsonb_build_object('messageId', v_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Challenges
-- ---------------------------------------------------------------------------
create or replace function private.assign_challenge(p_room uuid, p_loser uuid, p_loser_nick text)
returns text
language plpgsql
as $$
declare
  r public.rooms;
  v_ch text;
  v_inst text;
begin
  select * into r from public.rooms where id = p_room;
  v_ch := private.pick_challenge(r.used_challenge_ids);
  v_inst := 'ch_round_' || r.round_number || '_' || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
  insert into public.challenge_assignments
    (instance_id, room_id, match_number, round_number, loser_id, loser_nickname, challenge_id)
  values (v_inst, p_room, r.match_number, r.round_number, p_loser, p_loser_nick, v_ch);
  update public.rooms set used_challenge_ids = array_append(used_challenge_ids, v_ch) where id = p_room;
  return v_inst;
end;
$$;

create or replace function public.rpc_assign_challenge(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  r public.rooms;
  v_loser uuid;
  v_nick text;
  v_inst text;
begin
  select * into r from public.rooms where id = (p->>'roomId')::uuid for update;
  if not found then perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت'); end if;
  if not exists (select 1 from public.room_players where room_id = r.id and user_id = v_uid) then
    perform private.fail('forbidden', 'إنت مش عضو في القعدة دي');
  end if;
  if r.status not in ('round_results', 'finished') or r.last_loser_id is null then
    perform private.fail('conflict', 'مفيش جولة خلصت عشان نوزع حكم');
  end if;
  select instance_id into v_inst from public.challenge_assignments
   where room_id = r.id and match_number = r.match_number and round_number = r.round_number
   order by assigned_at desc limit 1;
  if v_inst is null then
    v_loser := r.last_loser_id;
    select nickname into v_nick from public.room_players where room_id = r.id and user_id = v_loser;
    v_inst := private.assign_challenge(r.id, v_loser, coalesce(v_nick, 'اللاعب'));
  end if;
  return jsonb_build_object('instanceId', v_inst);
end;
$$;

create or replace function public.rpc_challenge_action(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_action text := coalesce(p->>'action', 'complete');
  v_proof text := nullif(btrim(left(regexp_replace(coalesce(p->>'proofText', ''), '[<>]', '', 'g'), 300)), '');
  v_media uuid := nullif(p->>'mediaId', '')::uuid;
  r public.rooms;
  a public.challenge_assignments;
  ch public.challenges;
  v_new text;
begin
  if v_action not in ('complete', 'skip', 'redraw') then
    perform private.fail('invalid', 'إجراء الحكم غير صالح');
  end if;
  select * into r from public.rooms where id = (p->>'roomId')::uuid for update;
  if not found then perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت'); end if;
  if not exists (select 1 from public.room_players where room_id = r.id and user_id = v_uid) then
    perform private.fail('forbidden', 'إنت مش عضو في القعدة دي');
  end if;
  select * into a from public.challenge_assignments
   where room_id = r.id and match_number = r.match_number
   order by assigned_at desc limit 1 for update;
  if not found then perform private.fail('conflict', 'مفيش حكم مطلوب دلوقتي'); end if;
  if a.loser_id <> v_uid and r.host_id <> v_uid then
    perform private.fail('forbidden', 'اللاعب اللي لبس الشايب بس هو اللي ينفذ أو يغير الحكم');
  end if;
  if a.status <> 'pending' then
    perform private.fail('conflict', 'الحكم ده اتحسم خلاص');
  end if;

  if v_action = 'redraw' then
    if a.redraw_count >= 2 then
      perform private.fail('conflict', 'استنفذت محاولات تغيير الحكم في الجولة دي!');
    end if;
    v_new := private.pick_challenge(r.used_challenge_ids, a.challenge_id);
    update public.challenge_assignments
       set challenge_id = v_new, redraw_count = redraw_count + 1
     where instance_id = a.instance_id;
    update public.rooms set used_challenge_ids = array_append(used_challenge_ids, v_new) where id = r.id;
    select * into ch from public.challenges where id = v_new;
    perform private.sys_msg(r.id, a.loser_nickname || ' غيّر الحكم.. الحكم الجديد: «' || ch.title || '» 🎲', 'challenge_redrawn');
    return jsonb_build_object('instanceId', a.instance_id, 'status', 'pending', 'challengeId', v_new);
  end if;

  if v_media is not null and not exists (
       select 1 from public.media_attachments m
        where m.id = v_media and m.room_id = r.id and m.owner_id = a.loser_id and m.deleted_at is null) then
    perform private.fail('invalid', 'الملف المرفق مش تابع للحكم ده');
  end if;

  select * into ch from public.challenges where id = a.challenge_id;
  update public.challenge_assignments
     set status = case when v_action = 'complete' then 'completed' else 'skipped' end,
         proof_text = v_proof,
         media_id = coalesce(v_media, media_id)
   where instance_id = a.instance_id;

  if v_action = 'complete' then
    if a.challenge_id = 'ch_21' then
      update public.room_players set temporary_title = 'شايب المعمورة 👴'
       where room_id = r.id and user_id = a.loser_id;
    end if;
    perform private.sys_msg(r.id,
      a.loser_nickname || ' نفّذ الحكم «' || ch.title || '» برجولة! 👏🔥' ||
      case when v_proof is not null then E'\n💬 «' || v_proof || '»' else '' end,
      'challenge_completed');
  else
    perform private.sys_msg(r.id, a.loser_nickname || ' عدّى الحكم المرة دي 😅', 'challenge_skipped');
  end if;
  return jsonb_build_object('instanceId', a.instance_id,
                            'status', case when v_action = 'complete' then 'completed' else 'skipped' end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Game context (read by Edge Functions before running the TypeScript engine)
-- ---------------------------------------------------------------------------
create or replace function public.rpc_get_game_context(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_room uuid := (p->>'roomId')::uuid;
  v_secret jsonb;
  v_ver int;
begin
  if not exists (select 1 from public.rooms where id = v_room) then
    perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت');
  end if;
  if not exists (select 1 from public.room_players where room_id = v_room and user_id = v_uid) then
    perform private.fail('forbidden', 'إنت مش عضو في القعدة دي');
  end if;
  select secret_state, version into v_secret, v_ver from public.game_secrets where room_id = v_room;
  return jsonb_build_object('room', private.room_json(v_room), 'secret', v_secret, 'roundVersion', v_ver);
end;
$$;

-- ---------------------------------------------------------------------------
-- Atomic round commit — the ONLY write path for gameplay transitions.
-- The TypeScript engine computes the next state; this function verifies the
-- transition against the locked row and persists everything or nothing.
-- ---------------------------------------------------------------------------
create or replace function private.apply_round_completion(p_room uuid, p_round_id text, c jsonb)
returns jsonb
language plpgsql
as $$
declare
  r public.rooms;
  v_loser uuid := (c->>'loserId')::uuid;
  v_winner uuid := nullif(c->>'winnerId', '')::uuid;
  v_loser_nick text;
  v_over boolean;
  v_inst text;
  v_title text;
  v_assign boolean;
  v_msg text;
begin
  select * into r from public.rooms where id = p_room;
  v_over := r.round_number >= r.total_rounds;

  update public.room_players rp
     set score = rp.score + coalesce((c->'points'->>(rp.user_id::text))::int, 0),
         losses = rp.losses + case when rp.user_id = v_loser then 1 else 0 end,
         first_finishes = rp.first_finishes + case when rp.user_id is not distinct from v_winner then 1 else 0 end
   where rp.room_id = p_room;

  update public.game_rounds
     set status = 'finished', finish_order = (select coalesce(array_agg(x::uuid), '{}') from jsonb_array_elements_text(c->'finishOrder') x),
         loser_id = v_loser, points = c->'points', finished_at = now()
   where room_id = p_room and round_id = p_round_id;

  update public.rooms
     set status = case when v_over then 'finished' else 'round_results' end,
         last_loser_id = v_loser
   where id = p_room;

  select nickname into v_loser_nick from public.room_players where room_id = p_room and user_id = v_loser;
  v_assign := r.challenge_mode = 'every_round' or (r.challenge_mode = 'end_of_match' and v_over);
  if v_assign then
    v_inst := private.assign_challenge(p_room, v_loser, coalesce(v_loser_nick, 'اللاعب'));
    select c2.title into v_title from public.challenge_assignments a
      join public.challenges c2 on c2.id = a.challenge_id where a.instance_id = v_inst;
  end if;
  v_msg := 'الشايب لبس في ' || coalesce(v_loser_nick, 'لاعب') || '! 👴👑' ||
           case when v_title is not null then ' والحكم عليه: «' || v_title || '»' else '' end;
  perform private.sys_msg(p_room, v_msg, 'round_finished');

  -- Lifetime statistics (server-side only)
  insert into public.profiles (id, nickname, avatar_id)
  select rp.user_id, rp.nickname, rp.avatar_id from public.room_players rp where rp.room_id = p_room
  on conflict (id) do nothing;
  update public.profiles pr
     set rounds_played = pr.rounds_played + 1,
         rounds_lost = pr.rounds_lost + case when pr.id = v_loser then 1 else 0 end,
         rounds_won = pr.rounds_won + case when pr.id is not distinct from v_winner then 1 else 0 end,
         total_points = pr.total_points + coalesce((c->'points'->>(pr.id::text))::int, 0)
   where pr.id in (select user_id from public.room_players where room_id = p_room);

  if v_over then
    update public.profiles pr set games_played = pr.games_played + 1
     where pr.id in (select user_id from public.room_players where room_id = p_room);
    update public.profiles pr set matches_won = pr.matches_won + 1
     where pr.id in (
       select rp.user_id from public.room_players rp
        where rp.room_id = p_room
          and (rp.score, -rp.losses, rp.first_finishes) = (
            select score, -losses, first_finishes from public.room_players
             where room_id = p_room
             order by score desc, losses asc, first_finishes desc limit 1));
  end if;
  return jsonb_build_object('matchOver', v_over, 'instanceId', v_inst);
end;
$$;

create or replace function public.rpc_commit_round(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_room uuid := (p->>'roomId')::uuid;
  v_type text := p->>'actionType';
  v_action_id text := p->>'actionId';
  v_expected int := nullif(p->>'expectedRoundVersion', '')::int;
  rd jsonb := p->'round';
  r public.rooms;
  gs public.game_states;
  v_prev jsonb;
  v_order uuid[];
  v_db_order uuid[];
  v_count int;
  v_ready_ok boolean;
  v_round_number int;
  v_comp jsonb;
  v_result jsonb;
  d jsonb;
  m jsonb;
  h record;
begin
  if v_type not in ('start_game', 'draw_card', 'claim_timeout', 'next_round') then
    perform private.fail('invalid', 'نوع الحركة غير صالح');
  end if;
  select * into r from public.rooms where id = v_room for update;     -- serialises all writers
  if not found then perform private.fail('not_found', 'القعدة دي مش موجودة أو قفلت'); end if;
  if not exists (select 1 from public.room_players where room_id = v_room and user_id = v_uid) then
    perform private.fail('forbidden', 'إنت مش عضو في القعدة دي');
  end if;

  -- Idempotency: a repeated action id returns the stored result and changes nothing
  select result into v_prev from public.game_actions where room_id = v_room and action_id = v_action_id;
  if found then
    if (select user_id from public.game_actions where room_id = v_room and action_id = v_action_id) <> v_uid then
      perform private.fail('forbidden', 'الحركة دي تخص لاعب تاني');
    end if;
    return v_prev || jsonb_build_object('applied', false, 'alreadyApplied', true);
  end if;

  v_round_number := (rd->>'roundNumber')::int;

  if v_type in ('start_game', 'next_round') then
    select array_agg(x::uuid order by ord) into v_order
      from jsonb_array_elements_text(p->'playerOrder') with ordinality t(x, ord);
    select array_agg(user_id order by seat) into v_db_order from public.room_players where room_id = v_room;
    if v_order is distinct from v_db_order then
      perform private.fail('conflict', 'اللاعيبة اتغيروا، جرّب تاني');
    end if;
    if r.host_id <> v_uid then
      perform private.fail('forbidden', case when v_type = 'start_game'
        then 'صاحب القعدة بس هو اللي يقدر يبدأ اللعب' else 'صاحب القعدة بس هو اللي يبدأ الجولة الجديدة' end);
    end if;
    if v_type = 'start_game' then
      if r.status <> 'waiting' then perform private.fail('conflict', 'اللعبة شغالة بالفعل'); end if;
      select count(*), bool_and(ready or user_id = r.host_id) into v_count, v_ready_ok
        from public.room_players where room_id = v_room;
      if v_count < 2 or not v_ready_ok then
        perform private.fail('conflict', 'لازم على الأقل ٢ لعيبة وكلهم يكونوا جاهزين');
      end if;
      if v_round_number <> 1 then perform private.fail('invalid', 'رقم الجولة غير صحيح'); end if;
    else
      if r.status <> 'round_results' or r.round_number >= r.total_rounds or v_round_number <> r.round_number + 1 then
        perform private.fail('conflict', 'مفيش جولة تانية متاحة');
      end if;
    end if;
  else
    select * into gs from public.game_states where room_id = v_room;
    if r.status <> 'playing' or not found then
      perform private.fail('conflict', 'الجولة مش شغالة دلوقتي');
    end if;
    if gs.version is distinct from v_expected then
      perform private.fail('stale_version', 'الدور اتغير، حدّث وجرّب تاني');
    end if;
    v_round_number := gs.round_number;
  end if;

  -- ---- persist round state -------------------------------------------------
  insert into public.game_states (room_id, round_id, round_number, version, status, public_state)
  values (v_room, rd->>'roundId', v_round_number, (rd->>'version')::int, rd->>'status', rd->'publicState')
  on conflict (room_id) do update
    set round_id = excluded.round_id, round_number = excluded.round_number, version = excluded.version,
        status = excluded.status, public_state = excluded.public_state, updated_at = now();

  insert into public.game_secrets (room_id, round_id, version, secret_state)
  values (v_room, rd->>'roundId', (rd->>'version')::int, rd->'secretState')
  on conflict (room_id) do update
    set round_id = excluded.round_id, version = excluded.version,
        secret_state = excluded.secret_state, updated_at = now();

  for h in select key as uid, value as cards from jsonb_each(rd->'hands') loop
    insert into public.player_hands (room_id, user_id, round_id, version, cards)
    values (v_room, h.uid::uuid, rd->>'roundId', (rd->>'version')::int, h.cards)
    on conflict (room_id, user_id) do update
      set round_id = excluded.round_id, version = excluded.version, cards = excluded.cards, updated_at = now();
  end loop;

  for d in select * from jsonb_array_elements(coalesce(p->'newDiscards', '[]'::jsonb)) loop
    insert into public.discarded_pairs (room_id, round_id, turn_number, user_id, cards)
    values (v_room, rd->>'roundId', coalesce((d->>'turnNumber')::int, 0), nullif(d->>'userId', '')::uuid, d->'cards');
  end loop;

  if v_type in ('start_game', 'next_round') then
    insert into public.game_rounds (room_id, match_number, round_number, round_id, player_order)
    values (v_room, r.match_number, v_round_number, rd->>'roundId', v_order);
    update public.rooms set status = 'playing', round_number = v_round_number where id = v_room;
    perform private.sys_msg(v_room,
      case when v_type = 'start_game'
        then 'اللعبة بدأت! ٤٩ ورقة اتوزعوا والأجواز اتشالت.. مين هيلبس الشايب؟ 🃏🔥'
        else 'الجولة رقم ' || v_round_number || ' بدأت! ركّز يا معلم 🃏' end,
      case when v_type = 'start_game' then 'match_started' else 'round_started' end);
  end if;

  for m in select * from jsonb_array_elements(coalesce(p->'messages', '[]'::jsonb)) loop
    perform private.sys_msg(v_room, left(m->>'text', 600), coalesce(m->>'eventType', 'info'));
  end loop;

  v_comp := p->'completion';
  v_result := coalesce(p->'result', '{}'::jsonb);
  if v_comp is not null and jsonb_typeof(v_comp) = 'object' then
    v_result := v_result || private.apply_round_completion(v_room, rd->>'roundId', v_comp);
  end if;

  insert into public.game_actions (room_id, action_id, user_id, action_type, round_id, round_version, result)
  values (v_room, v_action_id, v_uid, v_type, rd->>'roundId', (rd->>'version')::int, v_result);

  return v_result || jsonb_build_object('applied', true, 'alreadyApplied', false);
end;
$$;

-- ---------------------------------------------------------------------------
-- Media + housekeeping RPCs
-- ---------------------------------------------------------------------------
create or replace function public.rpc_attach_media(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  v_room uuid := (p->>'roomId')::uuid;
  v_kind text := p->>'kind';
  v_bucket text := p->>'bucket';
  v_path text := p->>'path';
  v_mime text := p->>'mimeType';
  v_size int := (p->>'sizeBytes')::int;
  v_dur int := nullif(p->>'durationMs', '')::int;
  v_inst text := nullif(p->>'challengeInstanceId', '');
  v_real_size bigint;
  v_max_size int;
  me public.room_players;
  v_last timestamptz;
  v_id uuid;
  a public.challenge_assignments;
begin
  select * into me from public.room_players where room_id = v_room and user_id = v_uid;
  if not found then perform private.fail('forbidden', 'إنت مش عضو في القعدة دي'); end if;
  if v_kind not in ('image', 'voice') then perform private.fail('invalid', 'نوع الملف غير مدعوم'); end if;
  if v_path is null or split_part(v_path, '/', 1) <> v_room::text or split_part(v_path, '/', 2) <> v_uid::text then
    perform private.fail('forbidden', 'مسار الملف غير مسموح');
  end if;
  if v_kind = 'voice' and (v_dur is null or v_dur > 30000 or v_dur <= 0) then
    perform private.fail('invalid', 'الفويس لازم يكون أقل من ٣٠ ثانية');
  end if;
  v_max_size := case when v_kind = 'image' then 2097152 else 1048576 end;
  if v_size is null or v_size <= 0 or v_size > v_max_size then
    perform private.fail('invalid', 'حجم الملف أكبر من المسموح');
  end if;
  if (v_kind = 'image' and v_mime not in ('image/webp', 'image/jpeg', 'image/png'))
     or (v_kind = 'voice' and v_mime not in ('audio/ogg', 'audio/webm', 'audio/mp4', 'audio/aac', 'audio/mpeg')) then
    perform private.fail('invalid', 'صيغة الملف غير مدعومة');
  end if;
  -- the object must really exist in Storage (uploaded by this user's own signed upload)
  if to_regclass('storage.objects') is not null then
    execute 'select coalesce((metadata->>''size'')::bigint, -1) from storage.objects where bucket_id = $1 and name = $2'
      into v_real_size using v_bucket, v_path;
    if v_real_size is null then
      perform private.fail('invalid', 'الملف لسه ما اترفعش');
    end if;
    if v_real_size > v_max_size then
      perform private.fail('invalid', 'حجم الملف أكبر من المسموح');
    end if;
    if v_real_size > 0 then v_size := v_real_size::int; end if;
  end if;

  select last_sent_at into v_last from public.chat_rate where room_id = v_room and user_id = v_uid for update;
  if v_last is not null and clock_timestamp() - v_last < interval '750 milliseconds' then
    perform private.fail('rate_limited', 'بالراحة يا معلم، استنى لحظة بين الرسايل');
  end if;
  insert into public.chat_rate (room_id, user_id, last_sent_at) values (v_room, v_uid, clock_timestamp())
  on conflict (room_id, user_id) do update set last_sent_at = excluded.last_sent_at;

  insert into public.media_attachments
    (room_id, owner_id, kind, storage_bucket, storage_path, mime_type, size_bytes, duration_ms, challenge_instance_id)
  values (v_room, v_uid, v_kind, v_bucket, v_path, v_mime, v_size, v_dur, v_inst)
  returning id into v_id;

  if v_inst is not null then
    select * into a from public.challenge_assignments
     where instance_id = v_inst and room_id = v_room and loser_id = v_uid and status = 'pending' for update;
    if found then
      update public.challenge_assignments set media_id = v_id where instance_id = v_inst;
    end if;
  end if;

  insert into public.chat_messages (room_id, sender_id, sender_nickname, sender_avatar, type, text, media_id, challenge_instance_id)
  values (v_room, v_uid, me.nickname, me.avatar_id, 'evidence',
          case v_kind when 'image' then 'بعت صورة 📷' else 'بعت فويس 🎙️' end, v_id, v_inst);
  return jsonb_build_object('mediaId', v_id);
end;
$$;

create or replace function public.rpc_media_for_signing(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := private.caller(p);
  m public.media_attachments;
begin
  select * into m from public.media_attachments where id = (p->>'mediaId')::uuid;
  if not found or m.deleted_at is not null or m.expires_at <= now() then
    perform private.fail('not_found', 'الملف ده انتهت مدته أو اتحذف');
  end if;
  if not exists (select 1 from public.room_players where room_id = m.room_id and user_id = v_uid) then
    perform private.fail('forbidden', 'إنت مش عضو في القعدة دي');
  end if;
  return jsonb_build_object('bucket', m.storage_bucket, 'path', m.storage_path, 'mimeType', m.mime_type, 'kind', m.kind);
end;
$$;

create or replace function public.rpc_list_expired_media(p jsonb)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'bucket', storage_bucket, 'path', storage_path)), '[]'::jsonb)
  from (select * from public.media_attachments
         where deleted_at is null and (expires_at <= now()
               or room_id in (select id from public.rooms where status = 'closed' or expires_at <= now() - interval '7 days'))
         order by expires_at limit 200) x;
$$;

create or replace function public.rpc_mark_media_deleted(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_n int;
begin
  update public.media_attachments set deleted_at = now()
   where deleted_at is null
     and id in (select x::uuid from jsonb_array_elements_text(p->'ids') x);
  get diagnostics v_n = row_count;
  return jsonb_build_object('deleted', v_n);
end;
$$;

create or replace function public.rpc_close_expired_rooms(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_n int;
begin
  update public.rooms set status = 'closed'
   where status <> 'closed' and expires_at <= now();
  get diagnostics v_n = row_count;
  return jsonb_build_object('closed', v_n);
end;
$$;

-- ---------------------------------------------------------------------------
-- Lock the RPC surface: service_role (Edge Functions) ONLY
-- ---------------------------------------------------------------------------
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'rpc\_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end;
$$;
