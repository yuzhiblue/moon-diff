// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// A single unresolved 3-way conflict, captured with the three contributing
/// versions of the conflicting region so a human (or a smarter resolver) can
/// decide what the merged result should be.
pub struct MergeConflict {
  base: Array[String]
  ours: Array[String]
  theirs: Array[String]
}

/// The outcome of a 3-way merge. `merged` is the full line list; when a region
/// could not be resolved automatically it is emitted as conflict markers
/// (diff3 style: `<<<<<<< ours` / `||||||| base` / `=======` / `>>>>>>> theirs`),
/// so `merged` is always a complete, readable file. `conflicts` lists the
/// structured form of each unresolved region.
pub struct MergeResult {
  merged: Array[String]
  conflicts: Array[MergeConflict]
  has_conflict: Bool
}

/// Element-wise equality for two string arrays (used to decide whether a side
/// actually changed a region relative to `base`).
fn arrays_eq(a: Array[String], b: Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

/// For one side (`base -> side`), computes the *effective replacement block* for
/// every base-line position `0..n` plus a trailing virtual position `n`.
///
/// `blocks[i]` is the list of lines that should appear in the merged output at
/// position `i` (i.e. any lines inserted *before* `base[i]`, followed by
/// `base[i]` itself unless it was deleted). This representation is positionally
/// aligned with `base`, so the two sides can be merged index-by-index. Leading
/// insertions (prepends) are preserved because they attach to position `0`.
fn side_blocks(
  base: Array[String],
  changes: Array[Change[String]]
) -> Array[Array[String]] {
  let n = base.length()
  let blocks: Array[Array[String]] = Array::make(n + 1, [])
  let mut pending: Array[String] = []
  let mut i = 0
  for c in changes {
    match c {
      Equal(x) => {
        // flush pending inserts, then keep the base line
        let b: Array[String] = []
        for p in pending {
          b.push(p)
        }
        b.push(x)
        blocks[i] = b
        pending = []
        i = i + 1
      }
      Delete(_) => {
        // base[i] removed; any pending inserts still belong to position i
        let b: Array[String] = []
        for p in pending {
          b.push(p)
        }
        blocks[i] = b
        pending = []
        i = i + 1
      }
      Insert(x) => {
        pending.push(x)
      }
    }
  }
  // trailing insertions (after the last base line) live at position n
  if pending.length() > 0 {
    let b: Array[String] = []
    for p in pending {
      b.push(p)
    }
    blocks[n] = b
  }
  blocks
}

/// Performs a 3-way merge of line sequences using the classic *diff3* region
/// strategy:
///
/// * If neither side changed a region, keep it.
/// * If only one side changed it, take that side.
/// * If both sides changed it identically, take either.
/// * If both sides changed it differently, emit conflict markers and record the
///   conflict.
///
/// `base` is the common ancestor; `ours` and `theirs` are the two branches.
/// Prepends/appends and replacements are all handled correctly because each
/// side is decomposed into base-line-aligned blocks.
pub fn merge3(
  base: Array[String],
  ours: Array[String],
  theirs: Array[String]
) -> MergeResult {
  let b_blocks = side_blocks(base, diff(base, ours))
  let t_blocks = side_blocks(base, diff(base, theirs))
  let n = base.length()
  let merged: Array[String] = []
  let conflicts: Array[MergeConflict] = []
  for k = 0; k <= n; k = k + 1 {
    let b_block = if k < n { [base[k]] } else { [] }
    let o_block = b_blocks[k]
    let t_block = t_blocks[k]
    if arrays_eq(o_block, b_block) && arrays_eq(t_block, b_block) {
      for x in b_block {
        merged.push(x)
      }
    } else if arrays_eq(o_block, b_block) {
      for x in t_block {
        merged.push(x)
      }
    } else if arrays_eq(t_block, b_block) {
      for x in o_block {
        merged.push(x)
      }
    } else if arrays_eq(o_block, t_block) {
      for x in o_block {
        merged.push(x)
      }
    } else {
      merged.push("<<<<<<< ours")
      for x in o_block {
        merged.push(x)
      }
      merged.push("||||||| base")
      for x in b_block {
        merged.push(x)
      }
      merged.push("=======")
      for x in t_block {
        merged.push(x)
      }
      merged.push(">>>>>>> theirs")
      conflicts.push(
        MergeConflict::{ base: b_block, ours: o_block, theirs: t_block },
      )
    }
  }
  MergeResult::{
    merged,
    conflicts,
    has_conflict: conflicts.length() > 0,
  }
}

/// Convenience wrapper that merges raw texts (split on newlines) and returns the
/// merged text with conflict markers embedded inline.
pub fn merge3_text(base: String, ours: String, theirs: String) -> String {
  let r = merge3(split_lines(base), split_lines(ours), split_lines(theirs))
  r.merged.join("\n")
}

/// Like `merge3_text`, but also reports the number of unresolved conflicts.
pub fn merge3_count(
  base: String,
  ours: String,
  theirs: String
) -> (String, Int) {
  let r = merge3(split_lines(base), split_lines(ours), split_lines(theirs))
  (r.merged.join("\n"), r.conflicts.length())
}

/// Resolves a merge result by always preferring `ours` in conflict regions. This
/// mirrors `git merge -X ours`. The returned text contains no conflict markers.
pub fn merge3_resolve_ours(r: MergeResult) -> Array[String] {
  let out: Array[String] = []
  let m = r.merged
  let mut i = 0
  while i < m.length() {
    if m[i] == "<<<<<<< ours" {
      // skip until ">>>>>>> theirs", emitting ours lines
      i = i + 1
      while i < m.length() && m[i] != "||||||| base" {
        out.push(m[i])
        i = i + 1
      }
      // skip base + separator + theirs
      while i < m.length() && m[i] != ">>>>>>> theirs" {
        i = i + 1
      }
      i = i + 1
    } else {
      out.push(m[i])
      i = i + 1
    }
  }
  out
}

/// Resolves a merge result by always preferring `theirs` in conflict regions.
/// Mirrors `git merge -X theirs`.
pub fn merge3_resolve_theirs(r: MergeResult) -> Array[String] {
  let out: Array[String] = []
  let m = r.merged
  let mut i = 0
  while i < m.length() {
    if m[i] == "<<<<<<< ours" {
      // jump to the "=======" separator, then emit theirs lines
      while i < m.length() && m[i] != "=======" {
        i = i + 1
      }
      i = i + 1
      while i < m.length() && m[i] != ">>>>>>> theirs" {
        out.push(m[i])
        i = i + 1
      }
      i = i + 1
    } else {
      out.push(m[i])
      i = i + 1
    }
  }
  out
}
