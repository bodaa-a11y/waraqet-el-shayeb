# Integration with latest Cinematic V3 — safe merge instructions for Claude Code

**Files available to the assistant:** `el_shayeb_online_two_themes_v2.zip` — Cinematic V3 was NOT uploaded. This patch was developed against V2. Merge into V3 selectively, without overwriting newer gameplay/animation files blindly.

## New files (copy into V3)

- `scripts/test_backend_emulator.ps1`
- `scripts/run_emulators.ps1`
- `scripts/run_flutter_emulator.ps1`
- `functions/test/firebase_emulator_smoke.mjs`
- `BACKEND_FIREBASE_TESTING.md`

## Existing files (3-way merge, do not overwrite without reviewing V3)

- `functions/src/index.ts`: Secure private room joining by code, server-only rate-limited chat, admin-only challenge catalog seeding, rematch guard and old hand cleanup, recreate public directory entry after rematch.
- `firestore.rules`: All chat creation/modification becomes server-only; clients can read chat if room members, and `chatRate` docs are private.
- `lib/config/firebase_config.dart`: Add fake emulator FirebaseOptions only when `USE_FIREBASE_EMULATOR=true` (matching project ID).
- `lib/main.dart`: Fail loudly when emulator configuration is broken; otherwise preserve existing initialization.
- `lib/features/game/application/game_controller.dart`: Clear stale `publicRound` and `ownHand` on deleted snapshots, surface chat errors instead of silently swallowing them. If V3 added animation coordinator logic, **keep that logic**.
- `functions/test/security_and_concurrency.test.mjs`: Update test to assert server-only message writes.
- `functions/package.json`: `test:emulator`, compatible test flag for Node 22.
- `setup_windows.ps1`: Node 22 test support.
- `README.md`: Link to backend test guide.

## Test contract

1. Run existing TypeScript tests (`node --experimental-strip-types --test functions/test/*.test.mjs`).
2. Install dependencies and compile: `cd functions; npm install; npm run build`.
3. Run real local emulator integration `scripts/test_backend_emulator.ps1` (requires Firebase CLI and Java 21+).
4. Start `scripts/run_emulators.ps1` in terminal A.
5. Start `scripts/run_flutter_emulator.ps1` in terminal B.
6. Two Chrome profiles (normal + Incognito) sign in as separate anonymous users, join by code, chat, start the game, draw, finish a round, rematch.
7. Audit Firestore Rules with the REAL Emulator (the existing static rule string tests do not prove permissions).

## Caveat

The new smoke suite has been syntax-checked but **NOT RUN** on actual Firebase Emulators in this execution environment. Do not mark the backend production-verified until that passes.

## Future backlog

- Verify protected Storage evidence uploads and stop persisting tokenized public download URLs for private media.
- Add App Check enforcement in staging/production, while keeping local emulators workable.
- Add server-side scheduled turn timeout with durable scheduling, not just a client-triggered timeout claim.
- Add room lifecycle cleanup for old chat, attachments, and expired rounds.
- Add load testing and on-device multiplayer tests.
