# MIGRATION_REPORT — Firebase ➜ Supabase

## Mapping

| Firebase | Supabase |
|---|---|
| Anonymous Auth | Supabase Anonymous Sign-ins (`auth.signInAnonymously()`), session persisted by `supabase_flutter` → restored after restart |
| Firestore `users/{uid}` | `profiles` |
| `rooms/{id}` (+ embedded players/scores) | `rooms` + `room_players` |
| `rooms/{id}/state/current` | `game_states.public_state` |
| `rooms/{id}/secret/round` | `game_secrets` (no RLS policy) |
| `rooms/{id}/hands/{uid}` | `player_hands` (owner-only RLS) |
| `rooms/{id}/messages` | `chat_messages` |
| `rooms/{id}/actions` | `game_actions` (unique `action_id`) |
| `publicRooms` mirror | `public_rooms` view (no mirror to keep in sync) |
| Firestore transactions | single-transaction PL/pgSQL RPCs with row locks + version check |
| Cloud Functions v2 callables (14) | Edge Function `game` (one endpoint, `action` field; aliases kept) |
| Firebase Storage + rules | private bucket `shayeb-media` + Edge Function `media` (signed URLs) |
| Firestore listeners | Realtime `stream()` / `onPostgresChanges` |
| `firestore.rules`, `storage.rules` | RLS policies (migration 2) + bucket config (migration 4) |

## What was preserved unchanged

- The TypeScript rules engine (`functions/src/engine` → copied to `supabase/functions/_shared/engine`;
  only `shuffle.ts` gained a WebCrypto fallback for portability).
- Dart rules engine, offline practice mode with bots, both themes (قهوة البلد / ليالي النيل),
  cinematic animation modules, 16 sound assets, Egyptian Arabic RTL strings.
- Public API of `ShayebGameBridge` (same method names/arguments) so UI code did not change;
  Firestore snapshot types were replaced by small `ShayebDocSnapshot` / `ShayebQuerySnapshot` adapters.

## Flutter changes

- `pubspec.yaml`: removed `firebase_*`, `cloud_*`; added `supabase_flutter`, `http`.
- `lib/config/supabase_config.dart` (new), `lib/config/firebase_config.dart` (removed).
- `lib/main.dart`: `Supabase.initialize(...)`.
- `lib/shayeb_game_bridge.dart`: rewritten on Supabase.
- `lib/core/media/media_storage_service.dart` (new): abstract `MediaStorageService` + Supabase impl.
- `game_controller.dart`, `rooms_screens.dart`, `shayeb_table_screen.dart`: Firebase types removed.
  (The internal flag `isOnlineFirebase` keeps its name to avoid touching every screen; it now means "online".)

## Fixes made during migration

- `rpc_attach_media`: inline `CASE` inside `IF … > CASE … END THEN` broke the PL/pgSQL parser
  ("syntax error at end of input") → computed `v_max_size` first.
- `media` function called non-exposed `private.is_room_member` (and `auth.uid()` is null for service
  role) → explicit `room_players` lookup by verified uid; file extension now derived from MIME.
- `getRoomState` now returns the flat room shape + `scores/losses/firstFinishes/activeChallenge`
  expected by `RoomStateModel.fromMap`.
- RLS test now switches to the `authenticated` role (superuser bypasses RLS, which hid real behaviour).

## Legacy files

`functions/` (Firebase Cloud Functions), `firebase.json`, `firestore.rules`, `storage.rules`,
`.firebaserc` are kept for reference/rollback and for the engine unit tests in `functions/test`.
They are not used by the app anymore and can be deleted after the Supabase deployment is verified.
