import 'dart:math';
import '../../cards/domain/playing_card.dart';

/// Pure Dart implementation of the 49-card Egyptian El Shayeb rules engine.
/// Mirrors `functions/src/engine/` 1-for-1 for unit/widget testing and
/// explicit offline local practice mode against café bots.
class ShayebDartRulesEngine {
  static const List<String> ranks = [
    'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K',
  ];

  /// Creates the 49-card Egyptian El Shayeb deck (48 ordinary cards + King of Hearts).
  static List<PlayingCardModel> makeDeck({CardSuit oldKingSuit = CardSuit.hearts}) {
    final deck = <PlayingCardModel>[];
    for (final rank in ranks) {
      for (final suit in CardSuit.values) {
        if (rank == 'K' && suit != oldKingSuit) continue;
        deck.add(PlayingCardModel(id: '$rank:${suit.key}', rank: rank, suit: suit));
      }
    }
    assert(deck.length == 49, 'Deck must have exactly 49 cards');
    return deck;
  }

  /// Secure Fisher-Yates shuffle.
  static List<T> shuffleDeck<T>(List<T> items, {Random? random}) {
    final rng = _createSecureOrFallbackRandom(random);
    final out = List<T>.from(items);
    for (var i = out.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  static Random _createSecureOrFallbackRandom(Random? override) {
    if (override != null) return override;
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Resolves all rank-matching pairs in a hand, never pairing the King ("الشايب").
  static ({List<PlayingCardModel> hand, List<PlayingCardModel> discarded, int pairCount})
      resolvePairs(List<PlayingCardModel> hand) {
    final groups = <String, List<PlayingCardModel>>{};
    for (final card in hand) {
      groups.putIfAbsent(card.rank, () => []).add(card);
    }
    final remaining = <PlayingCardModel>[];
    final discarded = <PlayingCardModel>[];
    for (final entry in groups.entries) {
      if (entry.key == 'K') {
        remaining.addAll(entry.value);
        continue;
      }
      final pairs = entry.value.length ~/ 2;
      discarded.addAll(entry.value.take(pairs * 2));
      remaining.addAll(entry.value.skip(pairs * 2));
    }
    return (hand: remaining, discarded: discarded, pairCount: discarded.length ~/ 2);
  }

  /// Calculates round points: first finisher gets N-1, second N-2, ..., loser 0.
  static Map<String, int> roundPoints(List<String> finishOrder) {
    final n = finishOrder.length;
    return {
      for (var i = 0; i < n; i++) finishOrder[i]: n - i - 1,
    };
  }

  /// Finds the nearest active neighbor with cards in the configured direction.
  static String? nextActiveNeighbor({
    required List<String> playerOrder,
    required Map<String, List<PlayingCardModel>> hands,
    required String fromPlayerId,
    required String direction,
  }) {
    final start = playerOrder.indexOf(fromPlayerId);
    if (start < 0) return null;
    final step = direction == 'clockwise' ? 1 : -1;
    for (var i = 1; i < playerOrder.length; i++) {
      final idx = (start + step * i + playerOrder.length * (i + 1)) % playerOrder.length;
      final candidate = playerOrder[idx];
      if ((hands[candidate]?.length ?? 0) > 0) return candidate;
    }
    return null;
  }
}
