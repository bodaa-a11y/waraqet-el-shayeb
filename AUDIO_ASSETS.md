# El Shayeb Online (الشايب أونلاين) — Audio System & Sound Assets (`V3`)

## 1. Architecture (`lib/core/sound/sound_service.dart`)

The `SoundService` provides low-latency, non-blocking procedural audio playback using dual `AudioPlayer` channels (`_primaryPlayer` for rapid card/UI interactions and `_stingerPlayer` for longer dramatic stingers such as King reveal, victory, and challenge reveal) so card taps never cut off celebratory stingers.

### Features
- **16 Bundled License-Free Synthesized PCM WAV Assets (`assets/sounds/`)**: 100% original, zero copyright restrictions, valid 16-bit mono 22,050 Hz RIFF/WAVE PCM headers verified by automated tests.
- **Mute Toggle & Continuous Volume Slider**: Players can toggle sound on/off directly from the Game Table header or adjust the continuous volume slider (`0%` to `100%`) in `SettingsScreen` (`الإعدادات`), persisted via `SharedPreferences` (`soundEnabled`, `soundVolume`).
- **Safe Headless & Web Fallback**: All audio calls are wrapped in `unawaited` try/catch blocks so missing audio hardware or browser autoplay restrictions never block gameplay or animations.

---

## 2. Complete Sound Asset Catalog (`assets/sounds/`)

| # | WAV Filename | Enum (`ShayebSoundEvent`) | Trigger Event | Acoustic Profile |
|---|---|---|---|---|
| 1 | `card_shuffle.wav` | `ShayebSoundEvent.cardShuffle` | Round start (`CardShufflingAnimation`) | Rapid multi-card riffle flutter burst |
| 2 | `card_deal.wav` | `ShayebSoundEvent.cardDeal` | Card dealing (`CardDealingAnimation`) | Crisp light card slide & tap |
| 3 | `card_select.wav` | `ShayebSoundEvent.cardSelect` | Hovering / selecting an opponent's face-down card | Soft wooden tap harmonic |
| 4 | `card_draw.wav` | `ShayebSoundEvent.cardDraw` | Drawing a card (`CardDrawAnimation`) | Smooth card whoosh across felt |
| 5 | `card_flip.wav` | `ShayebSoundEvent.cardFlip` | 3D perspective card flip (`CardFlipAnimation`) | Crisp paper snap & turn |
| 6 | `pair_matched.wav` | `ShayebSoundEvent.pairMatched` | Automatic pair discard (`CardPairAnimation`) | Bright ascending Egyptian chime triad |
| 7 | `your_turn.wav` | `ShayebSoundEvent.yourTurn` | Local player's turn begins (`turnChanged`) | Warm café brass bell ping |
| 8 | `opponent_escaped.wav` | `ShayebSoundEvent.opponentEscaped` | A player finishes all cards (`خرج بسلام`) | Cheerful upbeat stinger |
| 9 | `king_suspense.wav` | `ShayebSoundEvent.kingSuspense` | Final 2 players / Stage 1 of King reveal | Deep low-frequency tension heartbeat pulse |
| 10 | `king_reveal.wav` | `ShayebSoundEvent.kingReveal` | `K♥` (`شايب القلوب`) revealed at round end | Dramatic theatrical brass/oud stinger |
| 11 | `challenge_reveal.wav` | `ShayebSoundEvent.challengeReveal` | 3D flip of punishment card (`بطاقة الحكم`) | Suspenseful percussion roll & chime |
| 12 | `round_lost.wav` | `ShayebSoundEvent.roundLost` | Local player loses the round with `K♥` | Playful descending comedy wah-wah |
| 13 | `match_victory.wav` | `ShayebSoundEvent.matchVictory` | Local player wins 1st place (`معلم القهوة`) | Grand celebratory fanfare chord progression |
| 14 | `match_completed.wav` | `ShayebSoundEvent.matchCompleted` | Multi-round match concludes | Warm closing cadence |
| 15 | `room_joined.wav` | `ShayebSoundEvent.roomJoined` | Player joins lobby or room created | Welcoming two-note chime |
| 16 | `button_click.wav` | `ShayebSoundEvent.buttonClick` | Primary UI button & theme switch taps | Subtle tactile click |
