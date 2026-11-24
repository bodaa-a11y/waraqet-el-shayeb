# El Shayeb Online (الشايب أونلاين) — Cinematic Animation Architecture (`V3`)

## 1. Overview & Guiding Principles

The **El Shayeb Online** Cinematic Animation System (`lib/features/game/animations/`) transforms the server-authoritative Egyptian multiplayer card game into a 60fps, high-polish interactive experience across both official visual themes (**`قهوة البلد` / Ahwa Classic** and **`ليالي النيل` / Nile Royal**) while strictly upholding three core engineering invariants:

1. **Server-Authoritative Truth:** Visual animations are reactive projections of authoritative Firestore snapshots (`rooms/{roomId}` + `rooms/{roomId}/state/current`) or the local offline-bot state engine. Animations never mutate game state or invent fake outcomes.
2. **Zero Card-Identity Leakage:** Opponent draw animations (`CardDrawAnimation`) and dealing trajectories (`CardDealingAnimation`) render only the face-down Egyptian arabesque card back (`_EgyptianCardBackPainter`) until the authoritative private hand document (`rooms/{roomId}/hands/{uid}`) updates on the card owner's device.
3. **Deterministic Event Deduplication & Reconnection Guard:** Every animation event has a deterministic `eventId` derived from `(roomId, roundId, version, eventType)`. Repeated Firestore listener snapshots with the same `version` never re-trigger animations, and a client reconnecting mid-round (`turnNumber > 0`) synchronizes directly to the live board state without replaying historical shuffle or deal cinematics.

---

## 2. Complete 14-Module Animation Directory (`lib/features/game/animations/`)

| # | Module File | Key Widget / Class | Responsibility |
|---|---|---|---|
| 1 | `game_animation_coordinator.dart` | `GameAnimationCoordinator`, `GameEffectsQuality`, `AvatarMotionState`, `GameAnimationEvent` | Deduplicates Firestore snapshots into one-shot visual/sound triggers, guards mid-round reconnections, and resolves all 8 expressive avatar states. |
| 2 | `card_shuffling_animation.dart` | `CardShufflingAnimation` | 7-stage physical deck shuffle at round start: deck rise, split left/right, riffle interleave, rotational jitter, gold dust particles, settle & pulse. |
| 3 | `card_dealing_animation.dart` | `CardDealingAnimation` | Batched staggered dealing trajectories from the central deck to 2–6 radial player seats (`clockwise` / `counterclockwise`) with landing bounce. |
| 4 | `card_draw_animation.dart` | `CardDrawAnimation` | Quadratic Bezier curved flight path from `drawTargetId` seat to `currentPlayerId` seat with mid-flight scale and face-down security guarantee. |
| 5 | `card_flip_animation.dart` | `CardFlipAnimation` | 3D perspective Y-axis `Matrix4` card rotation (`setEntry(3, 2, 0.0018)`) swapping card back to card face at the 90° midpoint (`pi / 2`). |
| 6 | `card_pair_animation.dart` | `CardPairAnimation` | Matched pair convergence, golden burst ring, 14 radial sparkle particles (`_PairSparklePainter`), and `"عاش يا معلم! نزلت جوز!"` toast banner. |
| 7 | `player_reaction_animation.dart` | `AnimatedEgyptianCharacterAvatar` | Expressive circular character frame supporting 8 motion states (`idle`, `yourTurn`, `drawing`, `pairMatched`, `suspense`, `victory`, `defeat`, `disconnected`) + animated circular turn timer ring. |
| 8 | `turn_highlight_animation.dart` | `CinematicTurnIndicator` | Pulsing golden spotlight banner (`"دورك يا معلم! اسحب ورقة من..."` / `"استنى دورك"`) with arrow motion toward the legal draw target. |
| 9 | `king_reveal_animation.dart` | `CinematicKingRevealBanner` | 4-stage dramatic reveal of `K♥` (`شايب القلوب`): Stage 1 (Suspense dim), Stage 2 (Spotlight on loser), Stage 3 (3D flip of `K♥` + crimson/gold shockwave), Stage 4 (`"الشايب لبس فيك يا نجم! 👴"` + Skip button). |
| 10 | `victory_animation.dart` | `CinematicVictoryBanner` | 36-particle golden confetti explosion (`_GoldConfettiPainter`), pulsing trophy badge, and `"مبروك يا أسطورة! 👑"` / `"معلم القهوة كسب الجيم!"` banner. |
| 11 | `defeat_animation.dart` | `CinematicDefeatNotice` | Playful comedy shake animation (`sin(t * pi * 6)`) with `"يا خسارة يا معلم! الشايب اختارك 😂"` and challenge preparation subtitle. |
| 12 | `challenge_reveal_animation.dart` | `ChallengeRevealAnimation` | 3D perspective flip + golden glow entrance for the round loser's punishment card (`بطاقة الحكم`), keyed by `instanceId` and `redrawCount`. |
| 13 | `table_ambient_animation.dart` | `TableAmbientAnimation` | Continuous low-GPU background atmosphere: warm lantern flicker & rising tea steam (`_TeaSteamPainter`) for **`قهوة البلد`**, and shimmering Nile water reflections & gold dust motes for **`ليالي النيل`**. |
| 14 | `theme_transition_animation.dart` | `ThemeTransitionAnimation` | Smooth 450ms crossfade & subtle scale transition when switching live between **`قهوة البلد`** and **`ليالي النيل`**. |

---

## 3. Event Deduplication & Reconnection Lifecycle

```
Firestore Snapshot (rooms/{roomId} + rooms/{roomId}/state/current)
        │
        ▼
GameAnimationCoordinator.deriveNewEvents(room, publicRound, localPlayerUid)
        │
        ├─► Reconnect Check: Is first snapshot for round AND turnNumber > 0?
        │     └── Yes: Mark `deal_r{roundNumber}` as already processed (no replay)
        │
        ├─► Turn 0 Playing?
        │     └── Emit `roundShuffleAndDeal` once -> triggers CardShufflingAnimation + CardDealingAnimation
        │
        ├─► Version Advanced (`publicRound.version > _lastSyncedVersion`)?
        │     ├── Emit `cardDrawn` (`draw_v{version}`) -> triggers CardDrawAnimation + `card_draw.wav`
        │     └── If `lastMovePairsRemoved > 0`:
        │           Emit `pairMatched` (`pair_v{version}`) -> triggers CardPairAnimation + `pair_matched.wav`
        │
        ├─► Active Turn Changed (`turn_v{version}_{currentPlayerId}`)?
        │     └── Emit `turnChanged` -> triggers CinematicTurnIndicator + `your_turn.wav` (if local player)
        │
        └─► Round Finished (`status == 'finished'` && `loserId != null`)?
              ├── Emit `kingRevealCinematic` -> triggers 4-stage CinematicKingRevealBanner + `king_reveal.wav`
              ├── Emit `roundDefeat` or `matchVictory`
              └── If `room.activeChallenge != null`:
                    Emit `challengeReveal` -> triggers 3D ChallengeRevealAnimation + `challenge_reveal.wav`
```

---

## 4. Performance & Accessibility Quality Tiers (`GameEffectsQuality`)

Players can configure visual effects intensity in **Settings (`الإعدادات -> جودة المؤثرات والأنيميشن`)**, which persists in `SharedPreferences` (`effectsQualityKey`) and automatically honors `MediaQuery.disableAnimationsOf(context)`:

- **`full` (`مؤثرات سينمائية كاملة ✨`)**: 1.0x duration multiplier, full ambient particles, confetti, and 4-stage King reveal.
- **`balanced` (`مؤثرات متوازنة ⚡`)**: 0.85x duration multiplier, smooth 60fps card trajectories and character reactions.
- **`reduced` (`مؤثرات خفيفة للأجهزة الضعيفة 📱`)**: 0.55x duration multiplier, skips background ambient particle painters and heavy confetti bursts.
- **`minimal` (`إيقاف الأنيميشن غير الضروري 🚫`)**: Instant state transitions (`durationMultiplier == 0.0`), ideal for accessibility or battery saving.
