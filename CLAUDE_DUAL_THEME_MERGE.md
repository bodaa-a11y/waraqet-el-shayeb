# Integration notes for Claude Code / Antigravity

## Two new, user-approved visual themes

A ready-to-merge patch accompanies the complete `el_shayeb_online` codebase.

- `قهوة البلد` — the first user-provided Egyptian wooden-café concept art.
- `ليالي النيل` — the second user-provided Cairo-sunset/Nile concept art.

The implementation is real Flutter code. It adds background assets, a custom wood/felt tabletop painter, seats for up to 5 opponents, the real local hand and draw-target fan, a theme selector, saved preference, and a settings option. Existing Firebase/Cloud Functions/game engine paths remain unchanged.

## Applying this patch to a newer verified project

1. Unzip `shayeb_dual_theme_patch.zip` over a **copy** of the newer verified project at its root. Preserve the paths from the ZIP, do not double-nest `lib/`.
2. Check for changes in these shared files before blindly overwriting:
   - `lib/features/game/presentation/game_table_screen.dart`
   - `lib/features/results/presentation/results_and_challenges_screens.dart`
   - `lib/main.dart`
   - `pubspec.yaml`
3. Keep newer bug fixes and the canonical backend implementation if any of these overlap.
4. Run `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d chrome`.
5. Check Android and Web at phone and desktop sizes, both online and in local bot mode.
6. Confirm no visual cards are used as the authority for hidden card identities. Only `session.ownHand` and public hand counts may be rendered.

**Do not substitute the photo mockup as an interactive table.** The background photos are ambience only. Draw cards, seats, controls and table surfaces are Flutter widgets / painters. The core game engine is untouched.

## Known limitations

The current environment has Node but not Flutter SDK; `flutter analyze` and widget tests were authored but cannot be executed here. Node 22 requires `--experimental-strip-types` for the existing `.ts`-importing `.mjs` engine tests. Backend Node tests passed 28/28 in this environment with that flag. On the Windows machine with a modern Node 26, original direct `node --test` may work without the flag.
