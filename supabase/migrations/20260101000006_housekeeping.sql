-- =============================================================================
-- Migration 6/6 — Housekeeping & Maintenance (pg_cron optional hook & helper views)
-- =============================================================================

-- If pg_cron extension is available on the Supabase project, schedule hourly cleanup
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') or
     exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    begin
      create extension if not exists pg_cron with schema extensions;
      -- Schedule hourly cleanup of expired rooms and orphaned media
      perform cron.schedule(
        'shayeb-hourly-cleanup',
        '0 * * * *',
        'select public.rpc_close_expired_rooms(''{}''::jsonb);'
      );
    exception when others then
      -- If user permissions do not allow configuring pg_cron, Edge Function cron fallback is used
      null;
    end;
  end if;
end;
$$;

-- Summary view for player statistics ranking (security_invoker = false so
-- authenticated clients can read rankings across players despite profiles RLS)
create or replace view public.leaderboard
with (security_invoker = false)
as
select
  p.id,
  p.nickname,
  p.avatar_id,
  p.games_played,
  p.rounds_won,
  p.rounds_lost,
  p.matches_won,
  p.total_points,
  dense_rank() over (order by p.total_points desc, p.matches_won desc, p.rounds_won desc) as rank
from public.profiles p
where p.games_played > 0
order by p.total_points desc, p.matches_won desc, p.rounds_won desc
limit 100;

revoke all on public.leaderboard from public, anon;
grant select on public.leaderboard to authenticated;
