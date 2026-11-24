import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// All 15 gameplay sound events for El Shayeb Online (الشايب أونلاين).
enum ShayebSoundEvent {
  buttonTap,
  cardShuffle,
  cardDeal,
  cardSelect,
  cardDraw,
  cardFlip,
  pairMatched,
  yourTurn,
  opponentEscaped,
  kingSuspense,
  kingReveal,
  roundLost,
  challengeReveal,
  matchVictory,
  roomJoined,
  matchCompleted,
}

/// Centralized audio & haptics manager using bundled, license-free synthesized WAV assets.
/// Supports volume control (0.0–1.0), dual-channel overlap for stingers, mute toggle,
/// and safe fallback on Flutter Web or headless test environments.
class ShayebSoundService {
  ShayebSoundService({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    double volume = 0.78,
  }) : _volume = volume.clamp(0.0, 1.0);

  bool soundEnabled;
  bool hapticsEnabled;
  double _volume;

  double get volume => _volume;
  set volume(double value) {
    _volume = value.clamp(0.0, 1.0);
  }

  AudioPlayer? _primaryPlayer;
  AudioPlayer? _stingerPlayer;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  static const Map<ShayebSoundEvent, String> soundAssetFiles = {
    ShayebSoundEvent.buttonTap: 'button_click.wav',
    ShayebSoundEvent.cardShuffle: 'card_shuffle.wav',
    ShayebSoundEvent.cardDeal: 'card_deal.wav',
    ShayebSoundEvent.cardSelect: 'card_select.wav',
    ShayebSoundEvent.cardDraw: 'card_draw.wav',
    ShayebSoundEvent.cardFlip: 'card_flip.wav',
    ShayebSoundEvent.pairMatched: 'pair_matched.wav',
    ShayebSoundEvent.yourTurn: 'your_turn.wav',
    ShayebSoundEvent.opponentEscaped: 'opponent_escaped.wav',
    ShayebSoundEvent.kingSuspense: 'king_suspense.wav',
    ShayebSoundEvent.kingReveal: 'king_reveal.wav',
    ShayebSoundEvent.roundLost: 'round_lost.wav',
    ShayebSoundEvent.challengeReveal: 'challenge_reveal.wav',
    ShayebSoundEvent.matchVictory: 'match_victory.wav',
    ShayebSoundEvent.roomJoined: 'room_joined.wav',
    ShayebSoundEvent.matchCompleted: 'match_completed.wav',
  };

  static const Set<ShayebSoundEvent> _stingerEvents = {
    ShayebSoundEvent.pairMatched,
    ShayebSoundEvent.kingSuspense,
    ShayebSoundEvent.kingReveal,
    ShayebSoundEvent.roundLost,
    ShayebSoundEvent.challengeReveal,
    ShayebSoundEvent.matchVictory,
    ShayebSoundEvent.matchCompleted,
  };

  Future<void> trigger(ShayebSoundEvent event) {
    unawaited(_playInternal(event));
    return Future<void>.value();
  }

  Future<void> _playInternal(ShayebSoundEvent event) async {
    if (hapticsEnabled) {
      await _triggerHaptic(event);
    }
    if (!soundEnabled || _volume <= 0.01 || _isWidgetTest) return;

    final file = soundAssetFiles[event];
    if (file == null) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      return;
    }

    final isStinger = _stingerEvents.contains(event);
    final targetPlayer = isStinger
        ? (_stingerPlayer ??= AudioPlayer())
        : (_primaryPlayer ??= AudioPlayer());
    try {
      await targetPlayer.stop().timeout(const Duration(milliseconds: 250));
      await targetPlayer
          .play(AssetSource('sounds/$file'), volume: _volume)
          .timeout(const Duration(milliseconds: 250));
    } catch (_) {
      // Browser autoplay restrictions or headless test runner: fail silently.
    }
  }

  Future<void> _triggerHaptic(ShayebSoundEvent event) async {
    try {
      switch (event) {
        case ShayebSoundEvent.buttonTap:
        case ShayebSoundEvent.cardDeal:
        case ShayebSoundEvent.cardSelect:
        case ShayebSoundEvent.cardFlip:
          await HapticFeedback.selectionClick();
          break;
        case ShayebSoundEvent.cardDraw:
        case ShayebSoundEvent.pairMatched:
        case ShayebSoundEvent.yourTurn:
        case ShayebSoundEvent.roomJoined:
          await HapticFeedback.lightImpact();
          break;
        case ShayebSoundEvent.opponentEscaped:
        case ShayebSoundEvent.challengeReveal:
        case ShayebSoundEvent.kingSuspense:
          await HapticFeedback.mediumImpact();
          break;
        case ShayebSoundEvent.kingReveal:
        case ShayebSoundEvent.roundLost:
        case ShayebSoundEvent.matchVictory:
        case ShayebSoundEvent.matchCompleted:
        case ShayebSoundEvent.cardShuffle:
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _primaryPlayer?.dispose();
      await _stingerPlayer?.dispose();
    } catch (_) {}
  }
}
