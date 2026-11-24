import type { Card } from "./types.ts";

export interface PairingResult {
  hand: Card[];
  pairs: [Card, Card][];
  discarded: Card[];
  pairCount: number;
}

/**
 * Canonical pair removal algorithm (Archive A + Archive B unified):
 * - Removes every possible same-rank pair across suits (four-of-a-kind => two pairs).
 * - Deterministic: within a rank, cards are paired in hand order; for an odd count,
 *   the last card of that rank remains in hand.
 * - The unmatched King ("K") is never paired or discarded.
 * - Returns both `pairs: [Card, Card][]` (Archive A) and flattened `discarded: Card[]` + `pairCount` (Archive B).
 */
export function removePairs(hand: readonly Card[]): PairingResult {
  const byRank = new Map<string, Card[]>();
  for (const c of hand) {
    if (c.rank === "K") continue;
    const g = byRank.get(c.rank);
    if (g) {
      g.push(c);
    } else {
      byRank.set(c.rank, [c]);
    }
  }
  const removed = new Set<string>();
  const pairs: [Card, Card][] = [];
  const discarded: Card[] = [];

  for (const group of byRank.values()) {
    for (let i = 0; i + 1 < group.length; i += 2) {
      const a = group[i]!;
      const b = group[i + 1]!;
      pairs.push([a, b]);
      discarded.push(a, b);
      removed.add(a.id);
      removed.add(b.id);
    }
  }

  return {
    hand: hand.filter((c) => !removed.has(c.id)),
    pairs,
    discarded,
    pairCount: pairs.length,
  };
}

export const resolvePairs = removePairs;
