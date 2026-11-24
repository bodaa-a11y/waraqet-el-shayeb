# SUPABASE_SETUP — الشايب أونلاين على Supabase

Project: `https://lzmpwjfgrtlypticedic.supabase.co` (ref `lzmpwjfgrtlypticedic`)

> [!IMPORTANT]
> The **service-role key** and the **database password** must never be put in the Flutter app,
> in git, or in this repo. The client only uses the *publishable / anon* key.

## 1. Dashboard settings (one time)

1. **Authentication → Sign In / Providers → Anonymous sign-ins → Enable.**
   (Without this, `signInAnonymously()` fails with `anonymous_provider_disabled`.)
2. Recommended: **Authentication → Attack Protection → enable CAPTCHA** (Turnstile/hCaptcha)
   before a public launch, to limit anonymous account creation abuse.
3. Optional: **Database → Extensions → enable `pg_cron`** to activate hourly cleanup
   (migration 6 schedules it automatically when the extension exists).

## 2. Install the CLI and link

```powershell
npm install --save-dev supabase
npx supabase login
npx supabase link --project-ref lzmpwjfgrtlypticedic
```

## 3. Apply the database

```powershell
npx supabase db push --dry-run --remote  # first preview, no changes
# Only after reviewing on an empty TEST project and verifying migrations locally:
npx supabase db push --remote       # applies migrations 1..7 in order
```

| Migration | Contents |
|---|---|
| `…01_core_schema.sql` | 14 tables, FKs, checks, indexes, triggers |
| `…02_rls_and_realtime.sql` | RLS on every table, `public_rooms` view, Realtime publication |
| `…03_game_rpcs.sql` | Atomic SECURITY DEFINER RPCs (service_role only) |
| `…04_storage_media.sql` | Private bucket `shayeb-media` (2 MB, image/audio MIME whitelist) |
| `…05_seed_challenges.sql` | The 30 Egyptian challenges `ch_01…ch_30` |
| `…06_housekeeping.sql` | Optional pg_cron cleanup + `leaderboard` view |
| `…07_predeploy_media_and_challenge_fixes.sql` | Media validation, retention and challenge permission fixes |

## 4. Deploy Edge Functions

```powershell
npx supabase functions deploy game
npx supabase functions deploy media

# Optional — required only if you schedule the `media` cleanupExpired job:
npx supabase secrets set CLEANUP_CRON_SECRET=<strong-random-secret>
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically
into Edge Functions — no Supabase keys need to be set manually.

Configured in `supabase/config.toml`:
- `game` keeps gateway **JWT verification ON** (`verify_jwt = true`).
- `media` sets `verify_jwt = false` so external cron schedulers can trigger `action: "cleanupExpired"` using `x-cron-secret`, while all user actions (`getUploadUrl`, `attachMedia`, `getDownloadUrl`) still enforce `auth.getUser(token)` inside the handler.

## 5. Run the Flutter app

```powershell
flutter pub get
flutter run -d chrome                     # uses the defaults in lib/config/supabase_config.dart
# or override explicitly:
flutter run --dart-define=SUPABASE_URL=https://lzmpwjfgrtlypticedic.supabase.co `
            --dart-define=SUPABASE_ANON_KEY=sb_publishable_xYJ1BQgVUUiEVmLvcE3q2Q_hmmRTBxX
```

**Two-window test:** run `flutter run -d chrome` and `flutter run -d windows` (or two browser
profiles). Window A creates a room as «أحمد», window B joins with the 6-char code as «محمد»,
both press جاهز, host starts, chat and draw cards.

## 6. Local development (optional, needs Docker)

```powershell
npx supabase start
npx supabase db reset                         # applies all migrations + seed locally
npx supabase functions serve
flutter run --dart-define=USE_LOCAL_SUPABASE=true --dart-define=SUPABASE_ANON_KEY=<local anon key>
# Android emulator: add --dart-define=LOCAL_SUPABASE_HOST=10.0.2.2
```

## 7. Tests that need no credentials

```powershell
cd supabase/tests; npm install; cd ../..
node --test supabase/tests/ functions/test/
```

## 8. Free-tier notes

- The free plan pauses a project after ~1 week of inactivity; open the dashboard to resume.
- Media is retained 7 days (`media_attachments.expires_at`), keeping Storage well below 1 GB.
- `public_rooms` is polled every 5 s only while the public-rooms screen is open;
  game state, hands, chat and lobby use Realtime (no polling).

## 9. Pre-deploy fixes and limits

Review `PREDEPLOY_AUDIT.md` before applying migrations to a remote database.
The private media upload now returns a durable `mediaId`; obtain signed URLs on demand.
Voice recording in the Flutter challenge screen is still a mock and must be implemented before testing voice upload from the UI.

