-- =============================================================================
-- El Shayeb Online (الشايب أونلاين) — core schema
-- Migration 1/6. Non-destructive: only CREATE statements, safe to review & apply
-- on an empty project. No pre-existing starter SQL was found in the repository
-- (the Firebase backend used Firestore), so there are no tables to reuse.
--
-- Authority model
--   * Clients (anon / authenticated roles) can only READ rows they are allowed
--     to see (RLS, migration 2). They never INSERT/UPDATE/DELETE game data.
--   * All mutations go through SECURITY DEFINER RPCs (migration 3) which are
--     executable by `service_role` only, i.e. only from our Edge Functions after
--     the user's JWT was verified there.
-- =============================================================================

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------
create or replace function private.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles — player profile + lifetime statistics (stats are server-written)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  nickname       text not null
                   check (char_length(btrim(nickname)) between 2 and 24
                          and nickname !~ '[<>]'
                          and lower(btrim(nickname)) not in
                              ('النظام','سيستم','system','admin','أدمن','المشرف')),
  avatar_id      text not null default 'avatar_1'
                   check (avatar_id ~ '^[a-z0-9_]{1,32}$'),
  games_played   integer not null default 0 check (games_played >= 0),
  rounds_played  integer not null default 0 check (rounds_played >= 0),
  rounds_lost    integer not null default 0 check (rounds_lost >= 0),
  rounds_won     integer not null default 0 check (rounds_won >= 0),
  matches_won    integer not null default 0 check (matches_won >= 0),
  total_points   integer not null default 0 check (total_points >= 0),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- rooms — public / private rooms and settings
-- ---------------------------------------------------------------------------
create table public.rooms (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique check (code ~ '^[A-Z0-9]{4,8}$'),
  host_id            uuid not null references auth.users (id) on delete cascade,
  title              text not null check (char_length(title) between 2 and 36 and title !~ '[<>]'),
  visibility         text not null default 'private' check (visibility in ('public','private')),
  max_players        smallint not null default 4 check (max_players between 2 and 6),
  total_rounds       smallint not null default 5 check (total_rounds in (1,3,5)),
  direction          text not null default 'clockwise' check (direction in ('clockwise','counterclockwise')),
  challenge_mode     text not null default 'every_round' check (challenge_mode in ('every_round','end_of_match','disabled')),
  turn_timer_seconds smallint not null default 45
                       check (turn_timer_seconds = 0 or turn_timer_seconds between 15 and 120),
  status             text not null default 'waiting'
                       check (status in ('waiting','playing','round_results','finished','closed')),
  round_number       smallint not null default 0 check (round_number >= 0),
  match_number       integer not null default 1 check (match_number >= 1),
  last_loser_id      uuid references auth.users (id) on delete set null,
  banned_user_ids    uuid[] not null default '{}',
  used_challenge_ids text[] not null default '{}',
  expires_at         timestamptz not null default (now() + interval '6 hours'),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index rooms_host_idx on public.rooms (host_id);
create index rooms_public_waiting_idx on public.rooms (updated_at desc)
  where visibility = 'public' and status = 'waiting';
create index rooms_expires_idx on public.rooms (expires_at) where status <> 'closed';
create trigger rooms_touch before update on public.rooms
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- room_players — members, seats, readiness, per-match totals
-- ---------------------------------------------------------------------------
create table public.room_players (
  room_id         uuid not null references public.rooms (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  nickname        text not null check (char_length(btrim(nickname)) between 2 and 24 and nickname !~ '[<>]'),
  avatar_id       text not null default 'avatar_1' check (avatar_id ~ '^[a-z0-9_]{1,32}$'),
  seat            smallint not null check (seat between 0 and 5),
  ready           boolean not null default false,
  is_connected    boolean not null default true,
  temporary_title text,
  score           integer not null default 0 check (score >= 0),
  losses          integer not null default 0 check (losses >= 0),
  first_finishes  integer not null default 0 check (first_finishes >= 0),
  joined_at       timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  primary key (room_id, user_id),
  unique (room_id, seat)
);
create index room_players_user_idx on public.room_players (user_id);
create trigger room_players_touch before update on public.room_players
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- game_states — PUBLIC authoritative round view (counts, turn, no card ids)
-- game_secrets — FULL authoritative round state (service_role only, no policy)
-- ---------------------------------------------------------------------------
create table public.game_states (
  room_id       uuid primary key references public.rooms (id) on delete cascade,
  round_id      text not null,
  round_number  smallint not null,
  version       integer not null check (version >= 0),
  status        text not null check (status in ('playing','finished')),
  public_state  jsonb not null,
  updated_at    timestamptz not null default now()
);

create table public.game_secrets (
  room_id       uuid primary key references public.rooms (id) on delete cascade,
  round_id      text not null,
  version       integer not null check (version >= 0),
  secret_state  jsonb not null,
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- game_rounds — one row per round, results written when the round finishes
-- ---------------------------------------------------------------------------
create table public.game_rounds (
  id            uuid primary key default gen_random_uuid(),
  room_id       uuid not null references public.rooms (id) on delete cascade,
  match_number  integer not null,
  round_number  smallint not null,
  round_id      text not null,
  status        text not null default 'playing' check (status in ('playing','finished')),
  player_order  uuid[] not null,
  finish_order  uuid[] not null default '{}',
  loser_id      uuid references auth.users (id) on delete set null,
  points        jsonb not null default '{}'::jsonb,
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  unique (room_id, match_number, round_number),
  unique (room_id, round_id)
);
create index game_rounds_room_idx on public.game_rounds (room_id, round_number);

-- ---------------------------------------------------------------------------
-- player_hands — PRIVATE hand of each player (owner-only read)
-- ---------------------------------------------------------------------------
create table public.player_hands (
  room_id    uuid not null references public.rooms (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  round_id   text not null,
  version    integer not null check (version >= 0),
  cards      jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

-- ---------------------------------------------------------------------------
-- discarded_pairs — removed pairs (visible to members only after round end)
-- ---------------------------------------------------------------------------
create table public.discarded_pairs (
  id          bigint generated always as identity primary key,
  room_id     uuid not null references public.rooms (id) on delete cascade,
  round_id    text not null,
  turn_number integer not null check (turn_number >= 0),
  user_id     uuid references auth.users (id) on delete set null,
  cards       jsonb not null check (jsonb_typeof(cards) = 'array' and jsonb_array_length(cards) = 2),
  created_at  timestamptz not null default now()
);
create index discarded_pairs_room_round_idx on public.discarded_pairs (room_id, round_id, turn_number);

-- ---------------------------------------------------------------------------
-- game_actions — idempotency + immutable action history
-- ---------------------------------------------------------------------------
create table public.game_actions (
  room_id      uuid not null references public.rooms (id) on delete cascade,
  action_id    text not null check (action_id ~ '^[A-Za-z0-9_-]{8,80}$'),
  user_id      uuid not null references auth.users (id) on delete cascade,
  action_type  text not null check (action_type in ('start_game','draw_card','claim_timeout','next_round')),
  round_id     text,
  round_version integer,
  result       jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  primary key (room_id, action_id)
);
create index game_actions_room_time_idx on public.game_actions (room_id, created_at desc);

-- ---------------------------------------------------------------------------
-- challenges — the 30 Egyptian punishments (seeded in migration 5)
-- ---------------------------------------------------------------------------
create table public.challenges (
  id                         text primary key check (id ~ '^ch_[0-9]{2,3}$'),
  title                      text not null,
  description                text not null,
  category                   text not null check (category in
                               ('acting','voice','poetry','comedy','in_game','group','text','action','creative','photo')),
  proof_type                 text not null check (proof_type in ('none','text','voice','image','in_game','optional')),
  estimated_duration_seconds integer not null check (estimated_duration_seconds between 5 and 600),
  enabled                    boolean not null default true,
  created_at                 timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- media_attachments — metadata only; bytes live in private Storage buckets
-- ---------------------------------------------------------------------------
create table public.media_attachments (
  id                    uuid primary key default gen_random_uuid(),
  room_id               uuid not null references public.rooms (id) on delete cascade,
  owner_id              uuid not null references auth.users (id) on delete cascade,
  kind                  text not null check (kind in ('image','voice')),
  storage_provider      text not null default 'supabase' check (storage_provider in ('supabase','r2')),
  storage_bucket        text not null,
  storage_path          text not null,
  mime_type             text not null,
  size_bytes            integer not null check (size_bytes > 0 and size_bytes <= 5242880),
  duration_ms           integer check (duration_ms is null or (duration_ms > 0 and duration_ms <= 30000)),
  challenge_instance_id text,
  created_at            timestamptz not null default now(),
  expires_at            timestamptz not null default (now() + interval '7 days'),
  deleted_at            timestamptz,
  check (kind <> 'voice' or duration_ms is not null),
  unique (storage_bucket, storage_path)
);
create index media_room_idx on public.media_attachments (room_id, created_at desc);
create index media_expiry_idx on public.media_attachments (expires_at) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- challenge_assignments — punishments assigned to round losers
-- ---------------------------------------------------------------------------
create table public.challenge_assignments (
  instance_id   text primary key check (instance_id ~ '^ch_round_[0-9]+_[0-9a-f]{8}$'),
  room_id       uuid not null references public.rooms (id) on delete cascade,
  match_number  integer not null,
  round_number  smallint not null,
  loser_id      uuid not null references auth.users (id) on delete cascade,
  loser_nickname text not null,
  challenge_id  text not null references public.challenges (id),
  status        text not null default 'pending' check (status in ('pending','completed','skipped')),
  redraw_count  smallint not null default 0 check (redraw_count between 0 and 2),
  proof_text    text check (proof_text is null or char_length(proof_text) <= 300),
  media_id      uuid references public.media_attachments (id) on delete set null,
  assigned_at   timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index challenge_assignments_room_idx on public.challenge_assignments (room_id, assigned_at desc);
create trigger challenge_assignments_touch before update on public.challenge_assignments
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- chat_messages — realtime room chat. Writes only via rpc_send_chat / server.
-- ---------------------------------------------------------------------------
create table public.chat_messages (
  id                    uuid primary key default gen_random_uuid(),
  room_id               uuid not null references public.rooms (id) on delete cascade,
  sender_id             uuid references auth.users (id) on delete cascade,
  sender_nickname       text not null,
  sender_avatar         text not null default 'avatar_1',
  type                  text not null check (type in ('user','reaction','system','evidence')),
  event_type            text,
  text                  text not null check (char_length(text) between 1 and 600),
  media_id              uuid references public.media_attachments (id) on delete set null,
  challenge_instance_id text,
  created_at            timestamptz not null default now(),
  -- A system message has no human sender; a human message always has one.
  check ((type = 'system') = (sender_id is null))
);
create index chat_room_time_idx on public.chat_messages (room_id, created_at);

-- Per-user chat throttle state (server-private)
create table public.chat_rate (
  room_id      uuid not null references public.rooms (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  last_sent_at timestamptz not null default now(),
  primary key (room_id, user_id)
);
