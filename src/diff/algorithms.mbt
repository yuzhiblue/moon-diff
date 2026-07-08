// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// Selects which diff strategy to use. All strategies return the same
/// `Array[Change[String]]` representation, so they are interchangeable.
pub enum DiffAlgorithm {
  /// Classic LCS backtrack (see `diff`).
  LCS
  /// Myers' `O(ND)` minimal edit script (see `myers_diff`).
  Myers
  /// Patience diff (unique-line skeleton + recursion).
  Patience
  /// Histogram diff (git-style most-frequent-anchor heuristic).
  Histogram
  /// Linear-space minimal edit script (Hirschberg divide & conquer).
  Linear
}

/// Dispatches to the requested diff algorithm. Every branch returns a valid
/// edit script over the two line sequences.
pub fn diff_algorithm(
  algo: DiffAlgorithm,
  a: Array[String],
  b: Array[String]
) -> Array[Change[String]] {
  match algo {
    LCS => diff(a, b)
    Myers => myers_diff(a, b)
    Patience => patience_diff(a, b)
    Histogram => histogram_diff(a, b)
    Linear => diff_linear(a, b)
  }
}

/// Resolves an algorithm name (e.g. `"lcs"`, `"myers"`) to a `DiffAlgorithm`.
/// Unknown names fall back to the linear-space Hirschberg algorithm.
pub fn diff_algorithm_by_name(name: String) -> DiffAlgorithm {
  match name {
    "lcs" => LCS
    "myers" => Myers
    "patience" => Patience
    "histogram" => Histogram
    _ => Linear
  }
}

/// Returns `arr[s..e)` as a fresh array.
fn slice(arr: Array[String], s: Int, e: Int) -> Array[String] {
  let out: Array[String] = []
  let mut i = s
  while i < e {
    out.push(arr[i])
    i = i + 1
  }
  out
}

/// ---------------------------------------------------------------------------
/// Patience diff
/// ---------------------------------------------------------------------------

/// Longest increasing subsequence (by the second component) of `matches`, used
/// as the patience "skeleton" of common unique lines.
fn lis_matches(matches: Array[(Int, Int)]) -> Array[(Int, Int)] {
  let m = matches.length()
  if m == 0 {
    return []
  }
  let dp: Array[Int] = Array::make(m, 1)
  let prev: Array[Int] = Array::make(m, -1)
  let mut best = 0
  for k = 0; k < m; k = k + 1 {
    for t = 0; t < k; t = t + 1 {
      if matches[t].1 < matches[k].1 && dp[t] + 1 > dp[k] {
        dp[k] = dp[t] + 1
        prev[k] = t
      }
    }
    if dp[k] > dp[best] {
      best = k
    }
  }
  let out: Array[(Int, Int)] = []
  let mut cur = best
  while cur != -1 {
    out.push(matches[cur])
    cur = prev[cur]
  }
  reversed(out)
}

/// Recursive patience diff over sub-ranges `[a0, a1)` × `[b0, b1)`.
fn patience_rec(
  a: Array[String],
  a0: Int,
  a1: Int,
  b: Array[String],
  b0: Int,
  b1: Int
) -> Array[Change[String]] {
  let alen = a1 - a0
  let blen = b1 - b0
  if alen <= 1 || blen <= 1 {
    return diff(slice(a, a0, a1), slice(b, b0, b1))
  }
  let countA: Array[(String, Int)] = []
  let countB: Array[(String, Int)] = []
  for i = a0; i < a1; i = i + 1 {
    imap_inc(countA, a[i])
  }
  for j = b0; j < b1; j = j + 1 {
    imap_inc(countB, b[j])
  }
  // first index of each unique (count == 1) line in b range
  let b_index: Array[(String, Int)] = []
  for j = b0; j < b1; j = j + 1 {
    let x = b[j]
    if imap_get(countB, x) == 1 && imap_get(b_index, x) == 0 {
      b_index.push((x, j + 1))
    }
  }
  let matches: Array[(Int, Int)] = []
  for i = a0; i < a1; i = i + 1 {
    let x = a[i]
    if imap_get(countA, x) == 1 && imap_get(countB, x) == 1 {
      let bj = imap_get(b_index, x)
      if bj != 0 {
        matches.push((i, bj - 1))
      }
    }
  }
  if matches.length() == 0 {
    return diff(slice(a, a0, a1), slice(b, b0, b1))
  }
  let skel = lis_matches(matches)
  let out: Array[Change[String]] = []
  let mut pa = a0
  let mut pb = b0
  for m in skel {
    let (mi, mj) = m
    let gap = patience_rec(a, pa, mi, b, pb, mj)
    for c in gap {
      out.push(c)
    }
    out.push(Equal(a[mi]))
    pa = mi + 1
    pb = mj + 1
  }
  let tail = patience_rec(a, pa, a1, b, pb, b1)
  for c in tail {
    out.push(c)
  }
  out
}

/// Patience diff (Bram Cohen's algorithm). Finds lines that are *unique* in both
/// inputs, takes their longest increasing subsequence as an alignment skeleton,
/// and recurses into the gaps. Patience diff tends to produce more "human"
/// alignments than plain LCS for sequences with repeated lines.
pub fn patience_diff(
  a: Array[String],
  b: Array[String]
) -> Array[Change[String]] {
  patience_rec(a, 0, a.length(), b, 0, b.length())
}

/// ---------------------------------------------------------------------------
/// Histogram diff (git-style)
/// ---------------------------------------------------------------------------

/// First index of `x` in `arr[s..e)`, or `s` if absent.
fn first_index(arr: Array[String], s: Int, e: Int, x: String) -> Int {
  let mut i = s
  while i < e {
    if arr[i] == x {
      return i
    }
    i = i + 1
  }
  s
}

/// Recursive histogram diff: pick the line that appears most often in `b`'s
/// range (and also in `a`'s range) as an anchor, emit it as `Equal`, and recurse
/// into the left/right gaps. Falls back to LCS when no common line exists.
fn histogram_rec(
  a: Array[String],
  a0: Int,
  a1: Int,
  b: Array[String],
  b0: Int,
  b1: Int
) -> Array[Change[String]] {
  let alen = a1 - a0
  let blen = b1 - b0
  if alen == 0 {
    let out: Array[Change[String]] = []
    for j = b0; j < b1; j = j + 1 {
      out.push(Insert(b[j]))
    }
    return out
  }
  if blen == 0 {
    let out: Array[Change[String]] = []
    for i = a0; i < a1; i = i + 1 {
      out.push(Delete(a[i]))
    }
    return out
  }
  if alen == 1 && blen == 1 {
    if a[a0] == b[b0] {
      return [Equal(a[a0])]
    }
    return [Delete(a[a0]), Insert(b[b0])]
  }
  let countB: Array[(String, Int)] = []
  for j = b0; j < b1; j = j + 1 {
    imap_inc(countB, b[j])
  }
  let mut best_i = -1
  let mut best_j = -1
  let mut best_cnt = 0
  for i = a0; i < a1; i = i + 1 {
    let c = imap_get(countB, a[i])
    if c > best_cnt {
      best_cnt = c
      best_i = i
      best_j = first_index(b, b0, b1, a[i])
    }
  }
  if best_cnt == 0 {
    return diff(slice(a, a0, a1), slice(b, b0, b1))
  }
  let out: Array[Change[String]] = []
  let left = histogram_rec(a, a0, best_i, b, b0, best_j)
  for c in left {
    out.push(c)
  }
  out.push(Equal(a[best_i]))
  let right = histogram_rec(a, best_i + 1, a1, b, best_j + 1, b1)
  for c in right {
    out.push(c)
  }
  out
}

/// Histogram diff, approximating Git's `diff --histogram`. Repeated lines are
/// anchored by frequency, which often yields cleaner diffs than LCS for source
/// code with many blank/brace lines.
pub fn histogram_diff(
  a: Array[String],
  b: Array[String]
) -> Array[Change[String]] {
  histogram_rec(a, 0, a.length(), b, 0, b.length())
}

/// ---------------------------------------------------------------------------
/// Linear-space minimal edit script (Hirschberg)
/// ---------------------------------------------------------------------------

/// Last column of the Levenshtein DP: `result[i]` is the edit distance between
/// `a[0..i]` and `b`. Computed in `O(|a|·|b|)` time and `O(|a|)` space.
fn edit_last_row(a: Array[String], b: Array[String]) -> Array[Int] {
  let n = a.length()
  let m = b.length()
  let mut prev: Array[Int] = Array::make(n + 1, 0)
  for i = 0; i <= n; i = i + 1 {
    prev[i] = i
  }
  let mut cur: Array[Int] = Array::make(n + 1, 0)
  for j = 0; j < m; j = j + 1 {
    cur[0] = j + 1
    for i = 0; i < n; i = i + 1 {
      if a[i] == b[j] {
        cur[i + 1] = prev[i]
      } else {
        let del = prev[i + 1] + 1
        let ins = cur[i] + 1
        let sub = prev[i] + 1
        let mut mn = del
        if ins < mn {
          mn = ins
        }
        if sub < mn {
          mn = sub
        }
        cur[i + 1] = mn
      }
    }
    let tmp = prev
    prev = cur
    cur = tmp
  }
  prev
}

/// `result[i]` is the edit distance between `a[i..]` and `b`. Computed in
/// `O(|a|·|b|)` time and `O(|a|)` space via a backward DP.
fn edit_last_row_rev(a: Array[String], b: Array[String]) -> Array[Int] {
  let n = a.length()
  let m = b.length()
  // `next[i]` holds the distance between `a[i..]` and `b[(k + 1)..]`.
  let mut next: Array[Int] = Array::make(n + 1, 0)
  for i = 0; i <= n; i = i + 1 {
    next[i] = n - i
  }
  let mut cur: Array[Int] = Array::make(n + 1, 0)
  for k = m - 1; k >= 0; k = k - 1 {
    cur[n] = m - k
    for i = n - 1; i >= 0; i = i - 1 {
      let del = cur[i + 1] + 1
      let ins = next[i] + 1
      let sub = next[i + 1] + (if a[i] == b[k] { 0 } else { 1 })
      let mut mn = del
      if ins < mn {
        mn = ins
      }
      if sub < mn {
        mn = sub
      }
      cur[i] = mn
    }
    let tmp = next
    next = cur
    cur = tmp
  }
  next
}

/// Recursive Hirschberg edit-script computation: split `b` in the middle, find
/// the optimal split row `i*` in `a`, and recurse. Space usage is `O(|a|+|b|)`
/// regardless of input size — hence "linear space".
fn linear_rec(
  a: Array[String],
  a0: Int,
  a1: Int,
  b: Array[String],
  b0: Int,
  b1: Int
) -> Array[Change[String]] {
  let n = a1 - a0
  let m = b1 - b0
  if n == 0 {
    let out: Array[Change[String]] = []
    for j = b0; j < b1; j = j + 1 {
      out.push(Insert(b[j]))
    }
    return out
  }
  if m == 0 {
    let out: Array[Change[String]] = []
    for i = a0; i < a1; i = i + 1 {
      out.push(Delete(a[i]))
    }
    return out
  }
  if n == 1 && m == 1 {
    if a[a0] == b[b0] {
      return [Equal(a[a0])]
    }
    return [Delete(a[a0]), Insert(b[b0])]
  }
  let mb = m / 2
  let fwd = edit_last_row(slice(a, a0, a1), slice(b, b0, b0 + mb))
  let bwd = edit_last_row_rev(slice(a, a0, a1), slice(b, b0 + mb, b1))
  let mut best_i = 0
  let mut best_cost = fwd[0] + bwd[0]
  for i = 1; i <= n; i = i + 1 {
    let c = fwd[i] + bwd[i]
    if c < best_cost {
      best_cost = c
      best_i = i
    }
  }
  let out: Array[Change[String]] = []
  let left = linear_rec(a, a0, a0 + best_i, b, b0, b0 + mb)
  for c in left {
    out.push(c)
  }
  let right = linear_rec(a, a0 + best_i, a1, b, b0 + mb, b1)
  for c in right {
    out.push(c)
  }
  out
}

/// Linear-space minimal edit script (Hirschberg's algorithm). Produces the same
/// kind of `Equal`/`Delete`/`Insert` script as `diff`, but uses only `O(|a|+|b|)`
/// memory instead of `O(|a|·|b|)`, so it scales to very large inputs.
pub fn diff_linear(
  a: Array[String],
  b: Array[String]
) -> Array[Change[String]] {
  linear_rec(a, 0, a.length(), b, 0, b.length())
}
