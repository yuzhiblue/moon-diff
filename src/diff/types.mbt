// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// A single edit operation representing the difference between two sequences.
///
/// * `Equal(x)` — element `x` appears unchanged in both sequences.
/// * `Delete(x)` — element `x` appears only in the *old* sequence.
/// * `Insert(x)` — element `x` appears only in the *new* sequence.
pub enum Change[T] {
  Equal(T)
  Delete(T)
  Insert(T)
} derive(Debug, Eq)
