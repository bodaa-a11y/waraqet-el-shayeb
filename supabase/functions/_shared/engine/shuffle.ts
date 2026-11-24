import { randomInt } from "node:crypto";

/** Returns an integer in [0, maxExclusive). */
export type RandomInt = (maxExclusive: number) => number;

/**
 * Cryptographically secure uniform random integer generator.
 * Uses Node's `crypto.randomInt` or WebCrypto rejection sampling; never Math.random().
 */
export const secureRandomInt: RandomInt = (maxExclusive: number): number => {
  if (!Number.isSafeInteger(maxExclusive) || maxExclusive < 1 || maxExclusive > 0x100000000) {
    throw new RangeError("maxExclusive must be an integer from 1 to 2^32");
  }
  try {
    if (typeof randomInt === "function") return randomInt(maxExclusive);
  } catch {
    // fallback to WebCrypto below
  }
  const u32 = new Uint32Array(1);
  const maxUint32 = 0x100000000;
  const limit = maxUint32 - (maxUint32 % maxExclusive);
  while (true) {
    globalThis.crypto.getRandomValues(u32);
    if (u32[0] < limit) return u32[0] % maxExclusive;
  }
};

/**
 * Unbiased Fisher–Yates shuffle. Returns a new array without mutating input.
 * Accepts an optional `rand` parameter ONLY for deterministic seeded unit tests;
 * production always uses `secureRandomInt`.
 */
export function shuffle<T>(items: readonly T[], rand: RandomInt = secureRandomInt): T[] {
  const a = items.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = rand(i + 1);
    [a[i], a[j]] = [a[j]!, a[i]!];
  }
  return a;
}

export const shuffleSecurely = shuffle;

const ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 32 unambiguous chars

export function generateRoomCode(length = 6, rand: RandomInt = secureRandomInt): string {
  const chars: string[] = [];
  for (let i = 0; i < length; i += 1) {
    chars.push(ROOM_CODE_ALPHABET[rand(ROOM_CODE_ALPHABET.length)]!);
  }
  return chars.join("");
}
