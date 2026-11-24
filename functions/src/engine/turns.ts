import { GameRuleError, type Direction } from "./types.ts";

/**
 * Next active player after `from` in `direction`, skipping inactive ones.
 * `from` may itself be inactive (e.g., just finished). Never returns `from`.
 * Seat order is fixed in `order`; clockwise = increasing seat index (+1),
 * counterclockwise = decreasing seat index (-1), so RTL UI layout never
 * reverses game direction semantics.
 */
export function nextActive(
  order: readonly string[],
  from: string,
  direction: Direction,
  isActive: (uid: string) => boolean,
): string | null {
  const n = order.length;
  const idx = order.indexOf(from);
  if (idx < 0) {
    throw new GameRuleError("unknown_player", `Unknown player ${from}`);
  }
  const step = direction === "clockwise" ? 1 : -1;
  for (let i = 1; i < n; i++) {
    const candidate = order[(((idx + step * i) % n) + n) % n]!;
    if (isActive(candidate)) return candidate;
  }
  return null;
}
