import 'package:flutter/material.dart';

/// Relative positions around the full-size table (local user sits below).
/// On narrow phones the game uses a scrollable opponent strip instead.
class PlayerSeatLayout {
  PlayerSeatLayout._();

  static List<Alignment> positions(int opponentCount) {
    switch (opponentCount) {
      case 0: return const [];
      case 1: return const [Alignment(0, -0.96)];
      case 2: return const [Alignment(-0.60, -0.96), Alignment(0.60, -0.96)];
      case 3: return const [Alignment(-0.93, -0.32), Alignment(0, -0.96), Alignment(0.93, -0.32)];
      case 4: return const [Alignment(-0.94, -0.25), Alignment(-0.46, -0.96), Alignment(0.46, -0.96), Alignment(0.94, -0.25)];
      default: return const [Alignment(-0.94, -0.20), Alignment(-0.68, -0.96), Alignment(0, -0.96), Alignment(0.68, -0.96), Alignment(0.94, -0.20)];
    }
  }
}
