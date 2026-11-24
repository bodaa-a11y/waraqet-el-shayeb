import type { PlayerId, RoundState } from "./types.ts";

export interface MatchTotals {
  points: number;
  roundLosses: number;
  firstPlaces: number;
}

export interface RankedPlayer extends MatchTotals {
  uid: string;
  rank: number;
  placement: number;
  isSharedPlacement: boolean;
  titleAr: string;
}

/**
 * Canonical round points calculation (Archive A + Archive B):
 * `finishOrder` = every player in finishing order, loser last.
 * First finisher receives N - 1 points, second N - 2, ..., loser 0.
 */
export function roundPoints(finishOrder: readonly PlayerId[]): Record<PlayerId, number> {
  const n = finishOrder.length;
  const scores: Record<PlayerId, number> = {};
  for (let i = 0; i < n; i += 1) {
    scores[finishOrder[i]!] = n - 1 - i;
  }
  return scores;
}

export function emptyTotals(): MatchTotals {
  return { points: 0, roundLosses: 0, firstPlaces: 0 };
}

/** Archive A cumulative match totals updater. */
export function applyRound(
  totals: Readonly<Record<string, MatchTotals>>,
  ranking: readonly string[],
): Record<string, MatchTotals> {
  const pts = roundPoints(ranking);
  const next: Record<string, MatchTotals> = { ...totals };
  for (const uid of ranking) {
    const t = totals[uid] ?? emptyTotals();
    next[uid] = {
      points: t.points + (pts[uid] ?? 0),
      roundLosses: t.roundLosses + (uid === ranking[ranking.length - 1] ? 1 : 0),
      firstPlaces: t.firstPlaces + (uid === ranking[0] ? 1 : 0),
    };
  }
  return next;
}

/** Archive B cumulative score map helper. */
export function applyRoundScores(
  round: RoundState,
  totals: Readonly<Record<PlayerId, number>> = {},
): Record<PlayerId, number> {
  if (round.status !== "finished") {
    throw new Error("Cannot score incomplete round");
  }
  const next = { ...totals };
  for (const [player, score] of Object.entries(roundPoints(round.finishOrder))) {
    next[player] = (next[player] ?? 0) + score;
  }
  return next;
}

/**
 * Canonical deterministic match ranking with tie-breaking (Archive A `rankMatch`):
 * 1. Higher total points
 * 2. Fewer round losses
 * 3. More first-place finishes
 * 4. Shared rank/placement (e.g. 1, 1, 3) if still tied
 */
export function rankMatch(totals: Readonly<Record<string, MatchTotals>>): RankedPlayer[] {
  const key = (t: MatchTotals): [number, number, number] => [
    -t.points,
    t.roundLosses,
    -t.firstPlaces,
  ];
  const cmp = (a: MatchTotals, b: MatchTotals): number => {
    const ka = key(a);
    const kb = key(b);
    for (let i = 0; i < ka.length; i++) {
      if (ka[i] !== kb[i]) return ka[i]! - kb[i]!;
    }
    return 0;
  };

  const rows = Object.entries(totals)
    .map(([uid, t]) => ({ uid, ...t }))
    .sort((a, b) => cmp(a, b) || (a.uid < b.uid ? -1 : 1));

  const rawRanks: number[] = [];
  rows.forEach((r, i) => {
    const rank = i > 0 && cmp(rows[i - 1]!, r) === 0 ? rawRanks[i - 1]! : i + 1;
    rawRanks.push(rank);
  });

  const rankCounts = new Map<number, number>();
  for (const rk of rawRanks) {
    rankCounts.set(rk, (rankCounts.get(rk) ?? 0) + 1);
  }

  return rows.map((r, i) => {
    const rank = rawRanks[i]!;
    const isLast = i === rows.length - 1 && rows.length > 1;
    let titleAr = "لعيب القعدة";
    if (rank === 1) {
      titleAr = "معلم القهوة الكبير 👑";
    } else if (isLast && r.roundLosses > 0) {
      titleAr = "شايب القعدة الرسمي 👴";
    } else if (r.firstPlaces >= 2) {
      titleAr = "ملك الفلتان ⚡";
    }
    return {
      ...r,
      rank,
      placement: rank,
      isSharedPlacement: (rankCounts.get(rank) ?? 0) > 1,
      titleAr,
    };
  });
}

export interface PlayerMatchStanding {
  readonly uid: PlayerId;
  readonly totalPoints: number;
  readonly roundsLost: number;
  readonly firstFinishes: number;
  readonly placement: number;
  readonly rank: number;
  readonly isSharedPlacement: boolean;
  readonly titleAr: string;
}

export function rankMatchPlayers(
  playerIds: readonly PlayerId[],
  scores: Readonly<Record<PlayerId, number>>,
  losses: Readonly<Record<PlayerId, number>>,
  firstFinishes: Readonly<Record<PlayerId, number>>,
): PlayerMatchStanding[] {
  const totals: Record<string, MatchTotals> = {};
  for (const uid of playerIds) {
    totals[uid] = {
      points: scores[uid] ?? 0,
      roundLosses: losses[uid] ?? 0,
      firstPlaces: firstFinishes[uid] ?? 0,
    };
  }
  return rankMatch(totals).map((r) => ({
    uid: r.uid,
    totalPoints: r.points,
    roundsLost: r.roundLosses,
    firstFinishes: r.firstPlaces,
    placement: r.placement,
    rank: r.rank,
    isSharedPlacement: r.isSharedPlacement,
    titleAr: r.titleAr,
  }));
}
