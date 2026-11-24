enum CardSuit {
  hearts('hearts', '♥', 'قلوب', true),
  diamonds('diamonds', '♦', 'ديناري', true),
  clubs('clubs', '♣', 'سباتي', false),
  spades('spades', '♠', 'بستوني', false);

  const CardSuit(this.key, this.symbol, this.arabicName, this.isRed);
  final String key;
  final String symbol;
  final String arabicName;
  final bool isRed;

  static CardSuit fromKey(String raw) {
    return CardSuit.values.firstWhere(
      (s) => s.key == raw.toLowerCase(),
      orElse: () => CardSuit.hearts,
    );
  }
}

class PlayingCardModel {
  const PlayingCardModel({
    required this.id,
    required this.rank,
    required this.suit,
  });

  factory PlayingCardModel.fromMap(Map<String, dynamic> map) {
    final rank = (map['rank'] ?? 'A').toString();
    final suit = CardSuit.fromKey((map['suit'] ?? 'hearts').toString());
    final id = (map['id'] ?? '$rank:${suit.key}').toString();
    return PlayingCardModel(id: id, rank: rank, suit: suit);
  }

  final String id;
  final String rank;
  final CardSuit suit;

  bool get isElShayeb => rank == 'K';

  String get arabicRankLabel {
    switch (rank) {
      case 'K':
        return 'الشايب';
      case 'Q':
        return 'بنت';
      case 'J':
        return 'ولد';
      case 'A':
        return 'آص';
      default:
        return rank;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'rank': rank,
        'suit': suit.key,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayingCardModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
