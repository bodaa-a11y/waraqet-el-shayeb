# El Shayeb Online (الشايب أونلاين) — Visual Effects & Dual Theme Report (`V3`)

## 1. Official Dual Visual Themes

The application preserves and enhances both selectable Egyptian visual themes with real-time hot-swapping (`ThemeTransitionAnimation`) and persistent user preference storage:

### Theme A — `قهوة البلد` (Ahwa Classic)
- **Visual Identity:** Traditional historic Cairo neighborhood café (`قهوة بلدي`), handcrafted warm wood carving table, brass lantern glow, and mint tea glass atmosphere.
- **Color Palette:**
  - Wood Surface: `#6E3E1F`
  - Warm Dark Brown: `#392013`
  - Golden Brass Accent: `#D7A84D`
  - Cream Typography & Borders: `#F9E7C2`
- **Background Asset:** `assets/images/themes/ahwa_classic_bg.jpg`
- **Ambient Motion (`TableAmbientAnimation`):** Soft breathing lantern radial glow + rising translucent tea steam wisps (`_TeaSteamPainter`) on the side of the table.

### Theme B — `ليالي النيل` (Nile Royal)
- **Visual Identity:** Luxurious Nile corniche lounge at sunset with emerald felt table surface, warm golden reflections on the water, and royal gold borders.
- **Color Palette:**
  - Deep Nile Green: `#092B25`
  - Emerald Felt Center: `#123B32`
  - Royal Gold Accent: `#E0B85A`
  - Mahogany Outer Rim: `#5B341A`
- **Background Asset:** `assets/images/themes/nile_royal_bg.jpg`
- **Ambient Motion (`TableAmbientAnimation`):** Gentle sunset shimmer waves across the Nile horizon + floating golden dust motes (`_AmbientParticlePainter`).

---

## 2. Custom Elderly Egyptian "الشايب" (`K♥`) Card Artwork

In `lib/features/cards/presentation/playing_card_widget.dart`, the solitary King of Hearts (`K:hearts` — **شايب القلوب**) is rendered with two dedicated custom vector painters (`_ElShayebCharacterFramePainter` and `_ElShayebPortraitPainter`):

- **Golden Halo Medallion:** Radial gold gradient (`#FFE6A3` -> `#D7A84D`) framed by a royal crimson ring (`#B3251E`).
- **Royal Egyptian Tarboush (Fez) & Crown Band:** Crimson tarboush (`#A81D18`) topped with a golden crown band (`#E5B94E`) and a central crimson heart jewel.
- **Expressive Character Features:** Warm skin tone oval, expressive white eyebrows, mischievous dark eyes, and a grand white Egyptian handlebar mustache (`شنب المعلم الشايب`).
- **Typography & Corner Badges:** High-contrast `K♥` corner badges and a crimson-and-gold `"الشايب"` title ribbon.

---

## 3. Expressive Egyptian Character Avatars (8 Motion States)

`AnimatedEgyptianCharacterAvatar` (`lib/features/game/animations/player_reaction_animation.dart`) combines the 6 illustrated portrait JPEGs (`assets/images/avatars/avatar_1.jpg`..`avatar_6.jpg`) and 8 Egyptian café personas with live procedural motion driven by `AvatarMotionState`:

1. **`idle`**: Gentle breathing scale (`1.0 -> 1.028`) + subtle vertical bobbing.
2. **`yourTurn`**: Bright golden spotlight ring + animated circular countdown timer arc (`_TurnTimerRingPainter`) that shifts from emerald green to amber to crimson as the turn deadline approaches.
3. **`drawing`**: Eager forward tilt and scale up (`1.07x`) while pulling a card from the neighbor.
4. **`pairMatched`**: Joyful celebratory bounce + golden badge `"نزل جوز! ✨"`.
5. **`suspense`**: Rapid nervous vibration (`sin(t * pi * 8)`) + crimson warning glow when the player is the active draw target or down to 1 card.
6. **`victory`**: Golden crown badge (`👑`) + radiant gold aura when the player escapes the round cleanly (`خرج بسلام`).
7. **`defeat`**: Comedy horizontal head-shake + dramatic spotlight when left holding `K♥` (`لبس الشايب 👴`).
8. **`disconnected`**: Desaturated grayscale filter + `"غير متصل"` badge until automatic reconnection.

---

## 4. Dramatic 4-Stage King of Hearts Reveal (`CinematicKingRevealBanner`)

When a round finishes and a single player is left holding `K♥`, `CinematicKingRevealBanner` (`lib/features/game/animations/king_reveal_animation.dart`) orchestrates a 4-stage reveal:

- **Stage 1 (0%–20% — Suspense Build):** Darkens the backdrop with a crimson radial vignette (`king_suspense.wav`).
- **Stage 2 (20%–45% — Loser Spotlight):** Locks a golden-red spotlight onto the losing player's name.
- **Stage 3 (45%–75% — 3D Perspective Card Flip & Shockwave):** Rotates `PlayingCardWidget(card: K♥)` in 3D perspective from face-down to face-up while expanding a dual gold/crimson shockwave ring (`_KingShockwavePainter`).
- **Stage 4 (75%–100% — Egyptian Comedy Verdict):** Displays `"الشايب لبس فيك يا نجم! 👴"` (or `"الشايب طلع مع <الاسم>! 😂"`), followed by the 3D flip of the punishment card (`ChallengeRevealAnimation`). Includes an instant **`تخطي` (Skip)** button at all times.
