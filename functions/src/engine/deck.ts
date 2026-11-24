import { type Card, type Rank, type Suit, SUITS, RANKS } from "./types.ts";

export const DECK_SIZE = 49;
export const DEFAULT_OLD_KING_SUIT: Suit = "hearts";

export function cardId(rank: Rank, suit: Suit): string {
  return `${rank}:${suit}`;
}

/**
 * Canonical 49-card Egyptian El Shayeb deck:
 * 52-card standard deck without Jokers, minus three Kings, leaving only one King
 * (`oldKingSuit`, default `"hearts"` = شايب القلوب).
 */
export function createDeck(kingSuit: Suit = DEFAULT_OLD_KING_SUIT): Card[] {
  if (!SUITS.includes(kingSuit)) {
    throw new Error(`Invalid King suit: ${String(kingSuit)}`);
  }
  const deck: Card[] = [];
  for (const rank of RANKS) {
    for (const suit of SUITS) {
      if (rank === "K" && suit !== kingSuit) continue;
      deck.push({ id: cardId(rank, suit), rank, suit });
    }
  }
  if (deck.length !== DECK_SIZE) {
    throw new Error("Deck generation invariant violated");
  }
  return deck;
}

export const makeDeck = createDeck;
export const isKing = (c: Card): boolean => c.rank === "K";
