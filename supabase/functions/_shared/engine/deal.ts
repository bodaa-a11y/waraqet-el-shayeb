import type { Card } from "./types.ts";

/** One card at a time, round-robin. Unequal hand sizes are expected (49 / N). */
export function dealCards(deck: readonly Card[], playerCount: number): Card[][] {
  const hands: Card[][] = Array.from({ length: playerCount }, () => []);
  deck.forEach((card, i) => hands[i % playerCount]!.push(card));
  return hands;
}
