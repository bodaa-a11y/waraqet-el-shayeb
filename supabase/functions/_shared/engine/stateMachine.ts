import { GameRuleError, type TurnPhase } from "./types.ts";

const ALLOWED_TRANSITIONS: Readonly<Record<TurnPhase, readonly TurnPhase[]>> = {
  WAITING_FOR_PLAYERS: ["READY_TO_START", "ABANDONED"],
  READY_TO_START: ["WAITING_FOR_PLAYERS", "DEALING", "ABANDONED"],
  DEALING: ["RESOLVING_INITIAL_PAIRS", "ABANDONED"],
  RESOLVING_INITIAL_PAIRS: ["WAITING_FOR_DRAW", "ROUND_COMPLETED", "ABANDONED"],
  WAITING_FOR_DRAW: ["PROCESSING_DRAW", "ROUND_COMPLETED", "ABANDONED"],
  PROCESSING_DRAW: ["RESOLVING_PAIRS", "ABANDONED"],
  RESOLVING_PAIRS: ["WAITING_FOR_DRAW", "ROUND_COMPLETED", "ABANDONED"],
  ROUND_COMPLETED: ["CHALLENGE_PENDING", "NEXT_ROUND_READY", "MATCH_COMPLETED", "ABANDONED"],
  CHALLENGE_PENDING: ["CHALLENGE_COMPLETED", "ABANDONED"],
  CHALLENGE_COMPLETED: ["NEXT_ROUND_READY", "MATCH_COMPLETED", "ABANDONED"],
  NEXT_ROUND_READY: ["DEALING", "WAITING_FOR_DRAW", "ABANDONED"],
  MATCH_COMPLETED: ["WAITING_FOR_PLAYERS", "READY_TO_START", "ABANDONED"],
  ABANDONED: [],
};

export function canTransitionPhase(from: TurnPhase, to: TurnPhase): boolean {
  return ALLOWED_TRANSITIONS[from]?.includes(to) ?? false;
}

export function assertValidPhaseTransition(from: TurnPhase, to: TurnPhase): TurnPhase {
  if (!canTransitionPhase(from, to)) {
    throw new GameRuleError(
      "invalid_phase_transition",
      `Illegal state transition from ${from} to ${to}`,
    );
  }
  return to;
}
