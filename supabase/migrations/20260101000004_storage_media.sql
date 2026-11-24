-- =============================================================================
-- Migration 4/6 — private Storage bucket for chat images / voice / evidence
--
-- Access model (no client policies on storage.objects on purpose):
--   * UPLOAD : Edge Function `media` validates (membership, kind, size, duration,
--              MIME) then issues a one-time SIGNED UPLOAD URL for a server-chosen
--              path  <room_id>/<user_id>/<uuid>.<ext>.
--   * ATTACH : rpc_attach_media verifies the object exists, re-checks its real
--              size and records metadata + the chat message.
--   * READ   : Edge Function issues SHORT-LIVED SIGNED DOWNLOAD URLS (60 s)
--              after checking room membership and expiry.
--   * CLEANUP: Edge Function `media` (action cleanup, cron-secret protected)
--              removes objects older than 7 days through the Storage API.
-- Because RLS is enabled on storage.objects and no policy grants clients access,
-- the bucket can only be reached through those server-issued URLs.
-- =============================================================================
do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values (
      'shayeb-media', 'shayeb-media', false, 2097152,
      array['image/webp','image/jpeg','image/png',
            'audio/ogg','audio/webm','audio/mp4','audio/aac','audio/mpeg']
    )
    on conflict (id) do update
      set public = false,
          file_size_limit = excluded.file_size_limit,
          allowed_mime_types = excluded.allowed_mime_types;
  end if;
end;
$$;
