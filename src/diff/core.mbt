// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// Splits a string on newline into an `Array[String]`.
fn split_lines(s: String) -> Array[String] {
  let out: Array[String] = []
  for line in s.split("\n") {
    out.push(line.to_owned())
  }
  out
}

/// Builds the longest-common-subsequence DP table for `a` and `b`.
/// `dp[i][j]` is the length of the LCS of `a[0..i)` and `b[0..j)`.
fn[T: Eq] lcs_table(a: Array[T], b: Array[T]) -> Array[Array[Int]] {
  let n = a.length()
  let m = b.length()
  let dp: Array[Array[Int]] = []
  for i = 0; i <= n; i = i + 1 {
    dp.push(Array::make(m + 1, 0))
  }
  for i = 1; i <= n; i = i + 1 {
    for j = 1; j <= m; j = j + 1 {
      if a[i - 1] == b[j - 1] {
        dp[i][j] = dp[i - 1][j - 1] + 1
      } else {
        dp[i][j] =
          if dp[i - 1][j] >= dp[i][j - 1] {
            dp[i - 1][j]
          } else {
            dp[i][j - 1]
          }
      }
    }
  }
  dp
}

/// Reverses an array (used to recover forward order after backtracking).
fn[T] reversed(xs: Array[T]) -> Array[T] {
  let n = xs.length()
  let out: Array[T] = []
  for i = n - 1; i >= 0; i = i - 1 {
    out.push(xs[i])
  }
  out
}

/// Computes the difference between two sequences using the LCS backtrack.
/// Returns a list of `Change` in forward (top-to-bottom) order.
pub fn[T: Eq] diff(a: Array[T], b: Array[T]) -> Array[Change[T]] {
  let dp = lcs_table(a, b)
  let mut i = a.length()
  let mut j = b.length()
  let rev: Array[Change[T]] = []
  while i > 0 && j > 0 {
    if a[i - 1] == b[j - 1] {
      rev.push(Equal(a[i - 1]))
      i = i - 1
      j = j - 1
    } else if dp[i - 1][j] >= dp[i][j - 1] {
      rev.push(Delete(a[i - 1]))
      i = i - 1
    } else {
      rev.push(Insert(b[j - 1]))
      j = j - 1
    }
  }
  while i > 0 {
    rev.push(Delete(a[i - 1]))
    i = i - 1
  }
  while j > 0 {
    rev.push(Insert(b[j - 1]))
    j = j - 1
  }
  reversed(rev)
}

/// Computes the difference using Myers' O(ND) diff algorithm.
/// Produces a minimal edit script (same edit distance as `diff`).
pub fn[T: Eq] myers_diff(a: Array[T], b: Array[T]) -> Array[Change[T]] {
  let n = a.length()
  let m = b.length()
  let max = n + m
  let off = max
  let v: Array[Int] = Array::make(2 * max + 1, 0)
  let trace: Array[Array[Int]] = []
  let mut found = false
  let mut end_d = 0
  let mut d = 0
  while d <= max && !found {
    for k = -d; k <= d; k = k + 2 {
      let mut x = 0
      if k == -d || (k != d && v[off + k - 1] < v[off + k + 1]) {
        x = v[off + k + 1]
      } else {
        x = v[off + k - 1] + 1
      }
      let mut y = x - k
      while x < n && y < m && a[x] == b[y] {
        x = x + 1
        y = y + 1
      }
      v[off + k] = x
      if x >= n && y >= m {
        found = true
      }
    }
    let snap = Array::make(2 * max + 1, 0)
    for t = 0; t < v.length(); t = t + 1 {
      snap[t] = v[t]
    }
    trace.push(snap)
    if found {
      end_d = d
    }
    d = d + 1
  }
  let changes: Array[Change[T]] = []
  let mut x = n
  let mut y = m
  for d2 = end_d; d2 >= 0; d2 = d2 - 1 {
    let vv = trace[d2]
    let k = x - y
    if k == -d2 || (k != d2 && vv[off + k - 1] < vv[off + k + 1]) {
      // came from a down move (insertion of b[prev_y])
      let prev_x = vv[off + k + 1]
      let prev_y = prev_x - (k + 1)
      while x > prev_x && y > prev_y {
        changes.push(Equal(a[x - 1]))
        x = x - 1
        y = y - 1
      }
      x = prev_x
      y = prev_y
      if d2 > 0 {
        changes.push(Insert(b[prev_y]))
      }
    } else {
      // came from a right move (deletion of a[prev_x])
      let prev_x = vv[off + k - 1]
      let prev_y = prev_x - (k - 1)
      while x > prev_x && y > prev_y {
        changes.push(Equal(a[x - 1]))
        x = x - 1
        y = y - 1
      }
      x = prev_x
      y = prev_y
      if d2 > 0 {
        changes.push(Delete(a[prev_x]))
      }
    }
  }
  reversed(changes)
}

/// Reconstructs the *new* sequence from a `Change` list.
pub fn[T] to_new(changes: Array[Change[T]]) -> Array[T] {
  let out: Array[T] = []
  for c in changes {
    match c {
      Equal(x) => out.push(x)
      Insert(x) => out.push(x)
      Delete(_) => ()
    }
  }
  out
}

/// Reconstructs the *old* sequence from a `Change` list.
pub fn[T] to_old(changes: Array[Change[T]]) -> Array[T] {
  let out: Array[T] = []
  for c in changes {
    match c {
      Equal(x) => out.push(x)
      Delete(x) => out.push(x)
      Insert(_) => ()
    }
  }
  out
}

/// Convenience: diff two strings line-by-line.
pub fn diff_lines(old: String, new: String) -> Array[Change[String]] {
  diff(split_lines(old), split_lines(new))
}

/// Splits `s` into an array of single-character strings (preserves order).
fn chars_of(s: String) -> Array[String] {
  let out: Array[String] = []
  for i = 0; i < s.length(); i = i + 1 {
    out.push("\{s[i].to_int().unsafe_to_char()}")
  }
  out
}

/// Diffs two strings at **character** granularity.
pub fn diff_chars(old: String, new: String) -> Array[Change[String]] {
  diff(chars_of(old), chars_of(new))
}

/// Reconstructs the *new* string from a `Change[String]` list (e.g. one
/// produced by `diff_chars` / `diff_tokens`).
pub fn changes_to_string(changes: Array[Change[String]]) -> String {
  to_new(changes).join("")
}

/// Tokenises text into alternating word / non-word runs so that diffing the
/// tokens preserves surrounding whitespace. e.g. `"a b"` -> `["a", " ", "b"]`.
pub fn tokenize(s: String) -> Array[String] {
  let toks: Array[String] = []
  let mut buf = ""
  let mut was_space = false
  let mut started = false
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int().unsafe_to_char()
    let is_space = c == ' ' || c == '\t' || c == '\n' || c == '\r'
    if !started {
      buf = "\{c}"
      was_space = is_space
      started = true
    } else if is_space == was_space {
      buf = buf + "\{c}"
    } else {
      toks.push(buf)
      buf = "\{c}"
      was_space = is_space
    }
  }
  if started {
    toks.push(buf)
  }
  toks
}

/// Diffs two strings at **word / token** granularity (finer than lines,
/// coarser than characters). Whitespace is preserved.
pub fn diff_tokens(old: String, new: String) -> Array[Change[String]] {
  diff(tokenize(old), tokenize(new))
}

/// Computes a **word/token-level** diff of two *single lines* and returns it as
/// a single combined string for intra-line highlighting. Removed runs are
/// wrapped in `[- … -]` and added runs in `{+ … +}`, mirroring the way a
/// unified diff marks changed words inside a modified line.
///
/// ```moonbit
/// word_diff("the cat sat", "the dog sat") // => "the [-cat-]{+dog+} sat"
/// ```
pub fn word_diff(old: String, new: String) -> String {
  let ch = diff_tokens(old, new)
  let mut out = ""
  for c in ch {
    match c {
      Equal(t) => out = out + t
      Delete(t) => out = out + "[-" + t + "-]"
      Insert(t) => out = out + "{+" + t + "+}"
    }
  }
  out
}

/// Renders intra-line highlighting as HTML: the old line has removed words
/// wrapped in `<del>…</del>` and the new line has added words wrapped in
/// `<ins>…</ins>`, mirroring GitHub's inline diff rendering.
///
/// ```moonbit
/// word_diff_html("the cat sat", "the dog sat")
/// // => ("the <del>cat</del> sat", "the <ins>dog</ins> sat")
/// ```
pub fn word_diff_html(old: String, new: String) -> (String, String) {
  let ch = diff_tokens(old, new)
  let mut old_out = ""
  let mut new_out = ""
  for c in ch {
    match c {
      Equal(t) => {
        old_out = old_out + t
        new_out = new_out + t
      }
      Delete(t) => old_out = old_out + "<del>" + t + "</del>"
      Insert(t) => new_out = new_out + "<ins>" + t + "</ins>"
    }
  }
  (old_out, new_out)
}
