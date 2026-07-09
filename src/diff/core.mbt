// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// Splits a string on newline into an `Array[String]`.
pub fn split_lines(s: String) -> Array[String] {
  let out: Array[String] = []
  for line in s.split("\n") {
    out.push(line.to_owned())
  }
  out
}

/// A tiny linear integer map backed by an array of `(key, value)` pairs. It is
/// used instead of `HashMap` so the package has **no external dependency** and
/// compiles standalone. Lookups are O(n) but the maps here are tiny.
fn[T: Eq] imap_get(m: Array[(T, Int)], k: T) -> Int {
  for p in m {
    if p.0 == k {
      return p.1
    }
  }
  0
}

fn[T: Eq] imap_inc(m: Array[(T, Int)], k: T) -> Unit {
  for i = 0; i < m.length(); i = i + 1 {
    if m[i].0 == k {
      m[i] = (k, m[i].1 + 1)
      return
    }
  }
  m.push((k, 1))
}

fn[T: Eq] imap_set(m: Array[(T, Int)], k: T, v: Int) -> Unit {
  for i = 0; i < m.length(); i = i + 1 {
    if m[i].0 == k {
      m[i] = (k, v)
      return
    }
  }
  m.push((k, v))
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
    out.push(String::from_array([s[i].to_int().unsafe_to_char()]))
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
      buf = String::from_array([c])
      was_space = is_space
      started = true
    } else if is_space == was_space {
      buf = buf + String::from_array([c])
    } else {
      toks.push(buf)
      buf = String::from_array([c])
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

// ===================== Unicode-aware tokeniser & similarity =====================

/// Returns the Unicode code points of `s` as `Int`s. In MoonBit a `String` is
/// indexed by code point, so `s[i].to_int()` already yields the scalar value of
/// the i-th character (this is the same convention used by `chars_of`,
/// `parse_string` and `substring`). Collecting them lets the Unicode-aware
/// tokeniser and `ratio` treat Chinese / Japanese / Korean text as real
/// characters instead of opaque bytes.
fn codepoints(s: String) -> Array[Int] {
  let out: Array[Int] = []
  let n = s.length()
  for i = 0; i < n; i = i + 1 {
    out.push(s[i].to_int())
  }
  out
}

/// True for Unicode whitespace (ASCII whitespace plus a few common Unicode
/// spaces, e.g. the ideographic space U+3000).
fn cp_is_space(cp: Int) -> Bool {
  cp == 0x20 || cp == 0x09 || cp == 0x0a || cp == 0x0d ||
  cp == 0x00a0 || cp == 0x1680 || cp == 0x3000 || cp == 0x2028 ||
  cp == 0x2029 || cp == 0x205f || cp == 0x3000
}

/// True for CJK / Kana / Hangul / Bopomofo code points — these are diffed
/// *per character* (there are no spaces inside a Han word).
fn cp_is_cjk(cp: Int) -> Bool {
  (cp >= 0x4e00 && cp <= 0x9fff) || // CJK Unified Ideographs
  (cp >= 0x3400 && cp <= 0x4dbf) || // CJK Extension A
  (cp >= 0x20000 && cp <= 0x2fa1f) || // CJK Extensions B+
  (cp >= 0x3040 && cp <= 0x30ff) || // Hiragana + Katakana
  (cp >= 0xac00 && cp <= 0xd7a3) || // Hangul Syllables
  (cp >= 0x1100 && cp <= 0x115f) || // Hangul Jamo
  (cp >= 0x3130 && cp <= 0x318f) || // Hangul compatibility Jamo
  (cp >= 0x3100 && cp <= 0x312f) // Bopomofo
}

/// True for punctuation (ASCII punctuation plus CJK / fullwidth punctuation).
/// Each punctuation mark becomes its own token so `Hello, world!` diffs the
/// comma and the exclamation separately.
fn cp_is_punct(cp: Int) -> Bool {
  (cp >= 0x21 && cp <= 0x2f) || (cp >= 0x3a && cp <= 0x40) ||
  (cp >= 0x5b && cp <= 0x60) || (cp >= 0x7b && cp <= 0x7e) ||
  (cp >= 0x3000 && cp <= 0x303f) || (cp >= 0xff00 && cp <= 0xffef)
}

/// A Unicode-aware tokeniser. Unlike `tokenize` (which treats everything that
/// is not ASCII whitespace as one big token, breaking Chinese entirely), this
/// splits text into:
///
/// * whitespace runs (preserved, like `tokenize`),
/// * per-CJK-character tokens (so `我爱北京` → `["我","爱","北","京"]`),
/// * per-punctuation tokens,
/// * runs of "word" characters (Latin letters / digits / etc.).
///
/// ```moonbit
/// tokenize_unicode("我爱北京")   // => ["我", "爱", "北", "京"]
/// tokenize_unicode("Hello, 世界!") // => ["Hello", ",", " ", "世", "界", "!"]
/// ```
pub fn tokenize_unicode(s: String) -> Array[String] {
  let cps = codepoints(s)
  let n = cps.length()
  let toks: Array[String] = []
  if n == 0 {
    return toks
  }
  let mut buf = ""
  let mut mode = 0 // 0 = empty, 1 = space, 2 = word, 3 = single (cjk/punct)
  let mut i = 0
  while i < n {
    let cp = cps[i]
    if cp_is_space(cp) {
      if mode != 1 {
        if mode != 0 {
          toks.push(buf)
        }
        buf = ""
        mode = 1
      }
      buf = buf + String::from_array([cp.unsafe_to_char()])
      i = i + 1
    } else if cp_is_cjk(cp) || cp_is_punct(cp) {
      if mode != 0 {
        toks.push(buf)
        buf = ""
      }
      toks.push(String::from_array([cp.unsafe_to_char()]))
      mode = 0
      i = i + 1
    } else {
      if mode != 2 {
        if mode != 0 {
          toks.push(buf)
          buf = ""
        }
        mode = 2
      }
      buf = buf + String::from_array([cp.unsafe_to_char()])
      i = i + 1
    }
  }
  if mode != 0 {
    toks.push(buf)
  }
  toks
}

/// Diffs two strings at **Unicode-token** granularity: whitespace-preserving,
/// per-CJK-character, per-punctuation. This is the Chinese/Japanese/Korean
/// friendly counterpart of `diff_tokens`.
///
/// ```moonbit
/// diff_tokens_unicode("我爱北京", "我爱南京")  // only 北→南 differs
/// ```
pub fn diff_tokens_unicode(old: String, new: String) -> Array[Change[String]] {
  diff(tokenize_unicode(old), tokenize_unicode(new))
}

/// Like `word_diff`, but built on the Unicode-aware tokeniser so intra-line
/// highlighting works for Chinese / Japanese / Korean text.
///
/// ```moonbit
/// word_diff_unicode("我爱北京", "我爱南京") // => "我爱[-北-]{+南+}京"
/// ```
pub fn word_diff_unicode(old: String, new: String) -> String {
  let ch = diff_tokens_unicode(old, new)
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

/// Like `word_diff_html`, but built on the Unicode-aware tokeniser.
///
/// ```moonbit
/// word_diff_html_unicode("我爱北京", "我爱南京")
/// // => ("我爱<del>北</del>京", "我爱<ins>南</ins>京")
/// ```
pub fn word_diff_html_unicode(old: String, new: String) -> (String, String) {
  let ch = diff_tokens_unicode(old, new)
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

/// Similarity ratio of two strings in `[0, 1]`, defined as `2·M / (|a| + |b|)`
/// where `M` is the length of the longest common subsequence of their Unicode
/// code points. `1.0` means identical, `0.0` means disjoint. This mirrors
/// Python's `difflib.SequenceMatcher.ratio` and is handy for ranking /
/// near-duplicate detection (works on Chinese text too).
///
/// ```moonbit
/// ratio("hello", "hullo")  // ~0.8
/// ratio("我爱北京", "我爱南京") // ~0.75
/// ```
pub fn ratio(a: String, b: String) -> Double {
  let ca = codepoints(a)
  let cb = codepoints(b)
  let la = ca.length()
  let lb = cb.length()
  if la == 0 && lb == 0 {
    return 1.0
  }
  let m = lcs_table(ca, cb)[la][lb]
  (2.0 * m.to_double()) / ((la + lb).to_double())
}
