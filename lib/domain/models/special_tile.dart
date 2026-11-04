enum SpecialTile {
  none,

  /// When cleared as part of a line, explodes and clears its 3×3 neighbourhood.
  /// Surges chain into other batteries caught in the blast.
  battery,

  /// When cleared, doubles the points of that move (stacks, capped at ×8).
  multiplier,
}
