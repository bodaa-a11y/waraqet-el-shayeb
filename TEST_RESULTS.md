# ورقة الشايب (Waraqet El Shayeb) — Verified Build & Test Results (`V5 Mobile & Supabase`)

This document records the **actual automated tests and Android Release APK build executed and verified** after:
- Migrating to Supabase (PostgreSQL migrations 1..7, RLS, RPCs, Edge Functions `game` & `media`, Private Storage)
- Renaming the game to **«ورقة الشايب»** (`com.waraqet.elshayeb`)
- Integrating the custom logo across Android launcher/adaptive/round icons, native splash resources, and PWA icons
- Adding the animated **`CreativeSplashScreen`** startup loading screen and non-blocking `ShayebSoundService`
- Fixing the mobile `_GameTopBar` layout for narrow smartphone screens (`360–430dp`)

**Summary: `69 / 69` automated checks passed (`0` failed) + Android Release APK built cleanly (`57.73 MB`).**

---

## 1. Executed & Passed: Android Release APK Build

- **Command Executed:**
  ```powershell
  flutter build apk --release --dart-define=SUPABASE_URL=https://lzmpwjfgrtlypticedic.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_xYJ1BQgVUUiEVmLvcE3q2Q_hmmRTBxX
  ```
- **Exit Code:** `0` (`Running Gradle task 'assembleRelease'... 889.0s`)
- **Output Artifact:** `build/app/outputs/flutter-apk/app-release.apk` (`60,531,523 bytes` / `57.73 MB`)
- **Security Note:** Only `SUPABASE_URL` and the public `SUPABASE_ANON_KEY` (`sb_publishable_...`) are embedded in the APK; no service-role keys or database passwords exist in Flutter code or binaries.

---

## 2. Executed & Passed: Flutter Widget, Creative Splash & Mobile RTL UI Tests (`8 / 8 passed`)

- **Command Executed:**
  ```powershell
  flutter test test/shayeb_engine_and_ui_test.dart
  ```
- **Exit Code:** `0` (`+8: All tests passed!` at `430x932` portrait mobile viewport)
- **Covered Flows:**
  - `El Shayeb Dart Rules Engine & Domain Tests` (5 suites: deck, pair resolution, scoring/tie-breaks, nickname anti-impersonation, 30 Egyptian challenges)
  - `Face-down card never leaks hidden card rank or suit in semantics or text`
  - `Full Egyptian RTL flow: Home -> Instant Café Room -> Lobby -> Start Game Table`
  - `CreativeSplashScreen displays ورقة الشايب and completes cleanly`

---

## 3. Executed & Passed: Pure Dart Engine, Audio/Theme Assets & Android Branding (`11 / 11 passed`)

- **Command Executed:**
  ```powershell
  & "C:\flutter\bin\cache\dart-sdk\bin\dart.exe" "test\pure_dart_engine_test.dart"
  ```
- **Exit Code:** `0` (`11 / 11 passed`, including PNG magic-header checks across `assets/images/logo/waraqet_el_shayeb_logo.png`, `drawable/`, all 5 `mipmap-*` densities `ic_launcher.png` & `ic_launcher_round.png`, and `AndroidManifest.xml` label `ورقة الشايب`)

---

## 4. Executed & Passed: Supabase PostgreSQL Migrations (1..7), RLS/RPCs, Edge Engine & TypeScript Tests (`50 / 50 passed`)

- **Command Executed:**
  ```powershell
  node --test supabase/tests/sql_and_rls.test.mjs supabase/tests/edge_engine_smoke.test.mjs supabase/tests/predeploy_regressions.test.mjs functions/test/engine.test.mjs functions/test/simulation.test.mjs functions/test/security_and_concurrency.test.mjs functions/test/archive_a_and_b_unified.test.mjs functions/test/multiplayer_functions_e2e.test.mjs
  ```
- **Runtime:** Node.js + `@electric-sql/pglite` in-memory PostgreSQL + native TypeScript stripping
- **Exit Code:** `0` (`pass 50, fail 0` in `5793.9733ms`)

---

## 5. Flutter Static Analysis

- `flutter analyze lib test/shayeb_engine_and_ui_test.dart`: **0 compile errors** (only 6 pre-existing deprecation/strict-raw-type/prefer-const info/warnings).

---

## 6. Deploying Backend Updates to Supabase

```powershell
npx supabase login
npx supabase link --project-ref lzmpwjfgrtlypticedic
npx supabase db push --dry-run --remote
npx supabase db push --remote
npx supabase functions deploy game
npx supabase functions deploy media
# Optional (required only when scheduling media cleanupExpired):
# npx supabase secrets set CLEANUP_CRON_SECRET=<your-secret>
```
