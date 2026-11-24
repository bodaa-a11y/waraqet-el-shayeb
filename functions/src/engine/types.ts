export const SUITS = ["hearts", "diamonds", "clubs", "spades"] as const;
export const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"] as const;
export type Suit = (typeof SUITS)[number];
export type Rank = (typeof RANKS)[number];
export type Direction = "clockwise" | "counterclockwise";
export type PlayerId = string;

export type TurnPhase =
  | "WAITING_FOR_PLAYERS"
  | "READY_TO_START"
  | "DEALING"
  | "RESOLVING_INITIAL_PAIRS"
  | "WAITING_FOR_DRAW"
  | "PROCESSING_DRAW"
  | "RESOLVING_PAIRS"
  | "ROUND_COMPLETED"
  | "CHALLENGE_PENDING"
  | "CHALLENGE_COMPLETED"
  | "NEXT_ROUND_READY"
  | "MATCH_COMPLETED"
  | "ABANDONED";

export type ChallengeMode = "every_round" | "end_of_match" | "disabled";

export interface Card {
  readonly id: string;
  readonly suit: Suit;
  readonly rank: Rank;
}

export interface MoveSummary {
  readonly actorId: PlayerId;
  readonly targetId: PlayerId;
  readonly pairsRemoved: number;
  readonly finishedPlayerIds: readonly PlayerId[];
  readonly turnNumber: number;
}

export interface RoundState {
  readonly id: string;
  readonly playerOrder: readonly PlayerId[];
  readonly direction: Direction;
  readonly hands: Readonly<Record<PlayerId, readonly Card[]>>;
  readonly discarded: readonly Card[];
  readonly finishOrder: readonly PlayerId[];
  readonly currentPlayerId: PlayerId | null;
  readonly turnNumber: number;
  readonly version: number;
  readonly status: "playing" | "finished";
  readonly phase?: TurnPhase;
  readonly turnDeadlineMs?: number | null;
  readonly turnTimerSeconds?: number;
  readonly loserId: PlayerId | null;
  readonly lastMove: MoveSummary | null;
}

export interface DrawAction {
  readonly actorId: PlayerId;
  readonly cardIndex: number;
  readonly expectedVersion: number;
}

export interface PublicRoundState {
  readonly id: string;
  readonly playerOrder: readonly PlayerId[];
  readonly direction: Direction;
  readonly handCounts: Readonly<Record<PlayerId, number>>;
  readonly finishOrder: readonly PlayerId[];
  readonly currentPlayerId: PlayerId | null;
  readonly drawTargetId: PlayerId | null;
  readonly turnNumber: number;
  readonly version: number;
  readonly status: "playing" | "finished";
  readonly phase: TurnPhase;
  readonly turnDeadlineMs: number | null;
  readonly loserId: PlayerId | null;
  readonly discardCount: number;
  readonly lastMove: MoveSummary | null;
}

export class GameRuleError extends Error {
  public readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
    this.name = "GameRuleError";
  }
}
