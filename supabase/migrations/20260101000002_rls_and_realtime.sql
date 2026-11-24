-- =============================================================================
-- Migration 2/6 — Row Level Security, grants, public room directory, Realtime
-- Principle: clients get SELECT on rows they may see, and NOTHING else.
-- =============================================================================

-- Anonymous Supabase sign-ins use the `authenticated` Postgres role (with the
-- `is_anonymous` claim). The `anon` role (no session at all) gets nothing.
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, authenticated;

grant usage on schema private to authenticated;

-- ---------------------------------------------------------------------------
-- Membership helper (SECURITY DEFINER avoids RLS recursion on room_players)
-- ---------------------------------------------------------------------------
create or replace function private.is_room_member(p_room uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.room_players rp
    where rp.room_id = p_room
      and rp.user_id = (select auth.uid())
  );
$$;
revoke all on function private.is_room_member(uuid) from public;
grant execute on function private.is_room_member(uuid) to authenticated;

create or replace function private.round_is_finished(p_room uuid, p_round text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.game_rounds r
    where r.room_id = p_room and r.round_id = p_round and r.status = 'finished'
  );
$$;
revoke all on function private.round_is_finished(uuid, text) from public;
grant execute on function private.round_is_finished(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere (deny by default)
-- ---------------------------------------------------------------------------
alter table public.profiles               enable row level security;
alter table public.rooms                  enable row level security;
alter table public.room_players           enable row level security;
alter table public.game_states            enable row level security;
alter table public.game_secrets           enable row level security;
alter table public.game_rounds            enable row level security;
alter table public.player_hands           enable row level security;
alter table public.discarded_pairs        enable row level security;
alter table public.game_actions           enable row level security;
alter table public.challenges             enable row level security;
alter table public.media_attachments      enable row level security;
alter table public.challenge_assignments  enable row level security;
alter table public.chat_messages          enable row level security;
alter table public.chat_rate              enable row level security;

-- ---------------------------------------------------------------------------
-- profiles: own row only. Players may set nickname/avatar, never statistics.
-- ---------------------------------------------------------------------------
grant select on public.profiles to authenticated;
grant insert (id, nickname, avatar_id) on public.profiles to authenticated;
grant update (nickname, avatar_id)     on public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Room-scoped read-only tables
-- ---------------------------------------------------------------------------
grant select on public.rooms                 to authenticated;
grant select on public.room_players          to authenticated;
grant select on public.game_states           to authenticated;
grant select on public.game_rounds           to authenticated;
grant select on public.player_hands          to authenticated;
grant select on public.discarded_pairs       to authenticated;
grant select on public.game_actions          to authenticated;
grant select on public.challenges            to authenticated;
grant select on public.media_attachments     to authenticated;
grant select on public.challenge_assignments to authenticated;
grant select on public.chat_messages         to authenticated;
-- game_secrets and chat_rate: no grants at all (service_role only)

create policy rooms_select_member on public.rooms
  for select to authenticated using (private.is_room_member(id));

create policy room_players_select_member on public.room_players
  for select to authenticated using (private.is_room_member(room_id));

create policy game_states_select_member on public.game_states
  for select to authenticated using (private.is_room_member(room_id));

create policy game_rounds_select_member on public.game_rounds
  for select to authenticated using (private.is_room_member(room_id));

-- Owner-only hand: opponents can never read another player's card identities.
create policy player_hands_select_owner on public.player_hands
  for select to authenticated
  using (user_id = (select auth.uid()) and private.is_room_member(room_id));

-- Discarded pairs are revealed to members only once the round is finished.
create policy discarded_pairs_select_after_round on public.discarded_pairs
  for select to authenticated
  using (private.is_room_member(room_id) and private.round_is_finished(room_id, round_id));

create policy game_actions_select_own on public.game_actions
  for select to authenticated using (user_id = (select auth.uid()));

create policy challenges_select_enabled on public.challenges
  for select to authenticated using (enabled);

create policy media_select_member on public.media_attachments
  for select to authenticated
  using (deleted_at is null and private.is_room_member(room_id));

create policy challenge_assignments_select_member on public.challenge_assignments
  for select to authenticated using (private.is_room_member(room_id));

-- Chat is read-only for clients: every write (user, reaction, system, evidence)
-- is produced by a SECURITY DEFINER RPC that verifies identity, membership and
-- rate limits. Clients can therefore never forge `system` messages.
create policy chat_select_member on public.chat_messages
  for select to authenticated using (private.is_room_member(room_id));

-- ---------------------------------------------------------------------------
-- Public room directory: exposes NO invite code and NO member list.
-- Runs with the view owner's rights on purpose (security_invoker = false).
-- ---------------------------------------------------------------------------
create or replace view public.public_rooms
with (security_invoker = false)
as
select
  r.id,
  r.title,
  hp.nickname  as host_nickname,
  hp.avatar_id as host_avatar,
  (select count(*) from public.room_players p where p.room_id = r.id)::int as player_count,
  r.max_players,
  r.total_rounds,
  r.direction,
  r.challenge_mode,
  ((select count(*) from public.room_players p where p.room_id = r.id) < r.max_players) as has_space,
  r.status,
  r.updated_at
from public.rooms r
left join public.room_players hp on hp.room_id = r.id and hp.user_id = r.host_id
where r.visibility = 'public' and r.status = 'waiting' and r.expires_at > now();

revoke all on public.public_rooms from public, anon;
grant select on public.public_rooms to authenticated;

-- ---------------------------------------------------------------------------
-- Keep rooms.updated_at moving whenever membership changes, so a single
-- Realtime subscription on the room row is enough to refresh the lobby.
-- ---------------------------------------------------------------------------
create or replace function private.touch_room_on_member_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.rooms set updated_at = now()
  where id = coalesce(new.room_id, old.room_id);
  return null;
end;
$$;
create trigger room_players_touch_room
  after insert or update or delete on public.room_players
  for each row execute function private.touch_room_on_member_change();

-- ---------------------------------------------------------------------------
-- Realtime: only tables whose rows are RLS-protected above are published.
-- (game_secrets / chat_rate / game_actions are intentionally NOT published.)
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['rooms','room_players','game_states','game_rounds',
                             'player_hands','chat_messages','challenge_assignments']
    loop
      if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
      ) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end;
$$;
