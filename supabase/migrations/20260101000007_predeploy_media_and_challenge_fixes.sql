-- Versioned patch on top of V4 (1..6); safe for a previously migrated project.
-- This migration does not delete tables or existing data.
-- Fixes: signed-media metadata checks; retention, unwanted challenges, host override.

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
  v_real_mime text;
  v_room_status text;
  v_room_expires timestamptz;
  v_max_size int;
  me public.room_players;
  v_last timestamptz;
  v_id uuid;
  a public.challenge_assignments;
begin
  select * into me from public.room_players where room_id = v_room and user_id = v_uid;
  if not found then perform private.fail('forbidden', 'إنت مش عضو في القعدة دي'); end if;
  select status, expires_at into v_room_status, v_room_expires
    from public.rooms where id = v_room;
  if v_room_status = 'closed' or v_room_expires <= now() then
    perform private.fail('conflict', 'القعدة انتهت ومش متاح رفع ملفات جديدة');
  end if;
  if v_kind not in ('image', 'voice') then perform private.fail('invalid', 'نوع الملف غير مدعوم'); end if;
  if v_bucket <> 'shayeb-media'
     or v_path is null or split_part(v_path, '/', 1) <> v_room::text
     or split_part(v_path, '/', 2) <> v_uid::text then
    perform private.fail('forbidden', 'مسار الملف غير مسموح');
  end if;
  if v_path !~ ('^' || v_room::text || '/' || v_uid::text ||
                  '/[0-9a-f-]{36}\.(webp|jpg|png|ogg|webm|m4a|aac|mp3)$') then
    perform private.fail('invalid', 'اسم الملف غير صالح');
  end if;
  if lower(split_part(v_path, '.', 2)) <> (case v_mime
      when 'image/webp' then 'webp' when 'image/jpeg' then 'jpg'
      when 'image/png' then 'png' when 'audio/ogg' then 'ogg'
      when 'audio/webm' then 'webm' when 'audio/mp4' then 'm4a'
      when 'audio/aac' then 'aac' when 'audio/mpeg' then 'mp3'
      else '' end) then
    perform private.fail('invalid', 'امتداد الملف لا يطابق نوعه');
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
    execute 'select coalesce((metadata->>''size'')::bigint, -1), metadata->>''mimetype''
             from storage.objects where bucket_id = $1 and name = $2'
      into v_real_size, v_real_mime using v_bucket, v_path;
    if v_real_size is null then
      perform private.fail('invalid', 'الملف لسه ما اترفعش');
    end if;
    if v_real_size <= 0 or v_real_mime is distinct from v_mime then
      perform private.fail('invalid', 'بيانات الملف الفعلية لا تطابق المطلوب');
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
    (room_id, owner_id, kind, storage_bucket, storage_path, mime_type,
     size_bytes, duration_ms, challenge_instance_id, expires_at)
  values (v_room, v_uid, v_kind, v_bucket, v_path, v_mime, v_size, v_dur,
          v_inst, greatest(now(), v_room_expires) + interval '7 days')
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

create or replace function public.rpc_list_expired_media(p jsonb)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'bucket', storage_bucket, 'path', storage_path)), '[]'::jsonb)
  from (select * from public.media_attachments
         where deleted_at is null and expires_at <= now()
         order by expires_at limit 200) x;
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
  if r.challenge_mode = 'disabled' or
     (r.challenge_mode = 'end_of_match' and r.status <> 'finished') then
    perform private.fail('conflict', 'نظام الأحكام مقفول في القعدة دي دلوقتي');
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
  if a.loser_id <> v_uid then
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

-- Keep these callable only through the authenticated Edge Function's service role.
revoke all on function public.rpc_attach_media(jsonb), public.rpc_list_expired_media(jsonb),
  public.rpc_assign_challenge(jsonb), public.rpc_challenge_action(jsonb)
  from public, anon, authenticated;
grant execute on function public.rpc_attach_media(jsonb), public.rpc_list_expired_media(jsonb),
  public.rpc_assign_challenge(jsonb), public.rpc_challenge_action(jsonb)
  to service_role;
