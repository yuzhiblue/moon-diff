// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

priv struct Op {
  tag: Char
  text: String
}

fn max_i(a: Int, b: Int) -> Int {
  if a > b { a } else { b }
}

fn is_digit_char(c: Int) -> Bool {
  let z = '0'.to_int()
  let n = '9'.to_int()
  c >= z && c <= n
}

fn digit_from_char(c: Int) -> Int {
  c - '0'.to_int()
}

/// Renders a `Change` list as a unified diff (GNU `diff -u` style) string.
pub fn[T: Show] to_unified(
  changes: Array[Change[T]],
  old_name: String,
  new_name: String,
  context: Int
) -> String {
  let ops: Array[Op] = []
  for c in changes {
    match c {
      Equal(x) => ops.push(Op::{ tag: ' ', text: x.to_string() })
      Delete(x) => ops.push(Op::{ tag: '-', text: x.to_string() })
      Insert(x) => ops.push(Op::{ tag: '+', text: x.to_string() })
    }
  }
  let n = ops.length()
  if n == 0 {
    return ""
  }
  let old_prefix = Array::make(n + 1, 0)
  let new_prefix = Array::make(n + 1, 0)
  for p = 0; p < n; p = p + 1 {
    old_prefix[p + 1] = old_prefix[p] + (if ops[p].tag != '+' { 1 } else { 0 })
    new_prefix[p + 1] = new_prefix[p] + (if ops[p].tag != '-' { 1 } else { 0 })
  }
  let changed: Array[Int] = []
  for p = 0; p < n; p = p + 1 {
    if ops[p].tag != ' ' {
      changed.push(p)
    }
  }
  let ranges: Array[(Int, Int)] = []
  let mut hunk_start = max_i(changed[0] - context, 0)
  let mut hunk_end = changed[0] + context
  for ci = 1; ci < changed.length(); ci = ci + 1 {
    let c = changed[ci]
    if c - context <= hunk_end {
      hunk_end = c + context
    } else {
      ranges.push((hunk_start, hunk_end))
      hunk_start = max_i(c - context, 0)
      hunk_end = c + context
    }
  }
  ranges.push((hunk_start, hunk_end))
  let mut out = ""
  out = out + "--- " + old_name + "\n"
  out = out + "+++ " + new_name + "\n"
  for r in ranges {
    let s = r.0
    let mut e = r.1
    if e > n {
      e = n
    }
    let old_start = old_prefix[s] + 1
    let old_count = old_prefix[e] - old_prefix[s]
    let new_start = new_prefix[s] + 1
    let new_count = new_prefix[e] - new_prefix[s]
    out = out + "@@ -" + old_start.to_string() + "," + old_count.to_string()
    out = out + " +" + new_start.to_string() + "," + new_count.to_string() + " @@\n"
    for p = s; p < e; p = p + 1 {
      let prefix = match ops[p].tag {
        ' ' => " "
        '-' => "-"
        '+' => "+"
        _ => " "
      }
      out = out + prefix + ops[p].text + "\n"
    }
  }
  out
}

/// Parses the old-file starting line number from a `@@ -a,b +c,d @@` header.
fn parse_old_start(header: String) -> Int {
  let mut i = 0
  let len = header.length()
  while i < len && header[i].to_int() != '-'.to_int() {
    i = i + 1
  }
  i = i + 1
  let mut num = 0
  while i < len && is_digit_char(header[i].to_int()) {
    num = num * 10 + digit_from_char(header[i].to_int())
    i = i + 1
  }
  num
}

fn is_meta(line: String) -> Bool {
  if line.length() >= 2 && line[0] == '@' && line[1] == '@' {
    return true
  }
  if line.length() >= 3 && line[0] == '-' && line[1] == '-' && line[2] == '-' {
    return true
  }
  if line.length() >= 3 && line[0] == '+' && line[1] == '+' && line[2] == '+' {
    return true
  }
  false
}

/// Applies a unified diff (as produced by `to_unified`) to `old_text`
/// and returns the resulting new text.
pub fn apply_unified(old_text: String, patch: String) -> String {
  let old_lines = split_lines(old_text)
  let patch_lines = split_lines(patch)
  let result: Array[String] = []
  let mut old_idx = 0
  let mut i = 0
  while i < patch_lines.length() {
    let line = patch_lines[i]
    if is_meta(line) {
      if line.length() >= 2 && line[0] == '@' {
        let target = parse_old_start(line) - 1
        while old_idx < target {
          result.push(old_lines[old_idx])
          old_idx = old_idx + 1
        }
      }
      i = i + 1
      continue
    }
    if line.length() == 0 {
      i = i + 1
      continue
    }
    let first = line[0]
    if first == ' ' {
      result.push(line[1:].to_owned())
      old_idx = old_idx + 1
    } else if first == '-' {
      old_idx = old_idx + 1
    } else if first == '+' {
      result.push(line[1:].to_owned())
    }
    i = i + 1
  }
  while old_idx < old_lines.length() {
    result.push(old_lines[old_idx])
    old_idx = old_idx + 1
  }
  result.join("\n")
}

/// A single operation inside a parsed unified-diff hunk.
priv struct Op2 {
  kind: Char
  text: String
}

/// A parsed unified-diff hunk (header + body operations).
priv struct Hunk {
  old_start: Int
  old_len: Int
  ops: Array[Op2]
}

/// Parses a unified-diff string into a list of `Hunk`s. Header lines
/// (`---`, `+++`, `diff --git`, `index`) and `@@ ... @@` separators are
/// consumed; the body lines (` `, `-`, `+`) become `Op2` records.
fn parse_hunks(patch: String) -> Array[Hunk] {
  let patch_lines = split_lines(patch)
  let hunks: Array[Hunk] = []
  let mut cur_ops: Array[Op2] = []
  let mut cur_old_len = 0
  let mut cur_start = 0
  let mut in_hunk = false
  for line in patch_lines {
    if line.length() == 0 {
      continue
    }
    if line.length() >= 2 && line[0] == '@' && line[1] == '@' {
      if in_hunk {
        hunks.push(
          Hunk::{ old_start: cur_start, old_len: cur_old_len, ops: cur_ops },
        )
      }
      cur_start = parse_old_start(line) - 1
      cur_ops = []
      cur_old_len = 0
      in_hunk = true
      continue
    }
    if is_meta(line) {
      continue
    }
    let first = line[0]
    let text = line[1:].to_owned()
    let kind =
      if first == ' ' {
        ' '
      } else if first == '-' {
        '-'
      } else if first == '+' {
        '+'
      } else {
        ' '
      }
    cur_ops.push(Op2::{ kind, text })
    if kind == ' ' || kind == '-' {
      cur_old_len = cur_old_len + 1
    }
  }
  if in_hunk {
    hunks.push(Hunk::{ old_start: cur_start, old_len: cur_old_len, ops: cur_ops })
  }
  hunks
}

/// Counts up to `n` leading *context* (` `) lines of a hunk body.
fn leading_context(ops: Array[Op2], n: Int) -> Int {
  let mut c = 0
  for op in ops {
    if op.kind != ' ' {
      break
    }
    if c == n {
      break
    }
    c = c + 1
  }
  c
}

/// Counts up to `n` trailing *context* (` `) lines of a hunk body.
fn trailing_context(ops: Array[Op2], n: Int) -> Int {
  let len = ops.length()
  let mut c = 0
  let mut i = len - 1
  while i >= 0 {
    let op = ops[i]
    if op.kind != ' ' {
      break
    }
    if c == n {
      break
    }
    c = c + 1
    i = i - 1
  }
  c
}

/// Applies a unified diff with `patch`/`git apply`-style tolerance for
/// **offset** (the `@@` line numbers are off) and **fuzz** (some leading /
/// trailing context lines no longer match).
///
/// * `max_offset` — how many lines up/down the hunk may be shifted from the
///   position stated in its header.
/// * `max_fuzz` — how many leading/trailing context lines may be ignored when
///   matching (mirrors `patch`'s `-F`/fuzz factor; the default is 2).
///
/// Returns `Ok(new_text)` on success, or `Err(msg)` if a hunk cannot be placed
/// within the given tolerance. Smaller offset and smaller fuzz are preferred.
pub fn apply_unified_fuzzy(
  old_text: String,
  patch: String,
  max_fuzz: Int,
  max_offset: Int
) -> Result[String, String] {
  let old_lines = split_lines(old_text)
  let hunks = parse_hunks(patch)
  if hunks.length() == 0 {
    return Ok(old_text)
  }
  let result: Array[String] = []
  let mut old_pos = 0
  for h in hunks {
    let expected = h.old_start
    let ops = h.ops
    let len = ops.length()
    let mut placed = false
    let mut chosen_p = 0
    for fz = 0; fz <= max_fuzz; fz = fz + 1 {
      let lead = leading_context(ops, fz)
      let trail = trailing_context(ops, fz)
      let core: Array[String] = []
      for i = lead; i < len - trail; i = i + 1 {
        let op = ops[i]
        if op.kind == ' ' || op.kind == '-' {
          core.push(op.text)
        }
      }
      let mut d = 0
      while d <= max_offset {
        let offs = if d == 0 { [0] } else { [-d, d] }
        for c in offs {
          let p = expected + c
          let q = p + lead
          if p < 0 {
            continue
          }
          if q < old_pos {
            continue
          }
          if q + core.length() > old_lines.length() {
            continue
          }
          if p + h.old_len > old_lines.length() {
            continue
          }
          let mut ok = true
          for k = 0; k < core.length(); k = k + 1 {
            if old_lines[q + k] != core[k] {
              ok = false
              break
            }
          }
          if ok {
            chosen_p = p
            placed = true
            break
          }
        }
        if placed {
          break
        }
        d = d + 1
      }
      if placed {
        break
      }
    }
    if !placed {
      return Err(
        "failed to apply hunk near line " +
          (expected + 1).to_string() +
          " (offset/fuzz exhausted)",
      )
    }
    for k = old_pos; k < chosen_p; k = k + 1 {
      result.push(old_lines[k])
    }
    let mut old_i = 0
    for op in ops {
      if op.kind == '-' {
        old_i = old_i + 1
      } else if op.kind == ' ' {
        result.push(old_lines[chosen_p + old_i])
        old_i = old_i + 1
      } else {
        result.push(op.text)
      }
    }
    old_pos = chosen_p + h.old_len
  }
  for k = old_pos; k < old_lines.length(); k = k + 1 {
    result.push(old_lines[k])
  }
  Ok(result.join("\n"))
}

/// Parses the *new-file* starting line number from a `@@ -a,b +c,d @@` header.
fn parse_new_start(header: String) -> Int {
  let mut i = 0
  let len = header.length()
  while i < len && header[i].to_int() != '+'.to_int() {
    i = i + 1
  }
  i = i + 1
  let mut num = 0
  while i < len && is_digit_char(header[i].to_int()) {
    num = num * 10 + digit_from_char(header[i].to_int())
    i = i + 1
  }
  num
}

/// Swaps the `-a,b` / `+c,d` ranges inside a `@@ ... @@` header.
fn reverse_header(h: String) -> String {
  let len = h.length()
  let mut i = 0
  while i < len && h[i] != '-' {
    i = i + 1
  }
  i = i + 1
  let mut a = 0
  while i < len && is_digit_char(h[i].to_int()) {
    a = a * 10 + digit_from_char(h[i].to_int())
    i = i + 1
  }
  i = i + 1 // skip ','
  let mut b = 0
  while i < len && is_digit_char(h[i].to_int()) {
    b = b * 10 + digit_from_char(h[i].to_int())
    i = i + 1
  }
  while i < len && h[i] != '+' {
    i = i + 1
  }
  i = i + 1
  let mut c = 0
  while i < len && is_digit_char(h[i].to_int()) {
    c = c * 10 + digit_from_char(h[i].to_int())
    i = i + 1
  }
  i = i + 1 // skip ','
  let mut d = 0
  while i < len && is_digit_char(h[i].to_int()) {
    d = d * 10 + digit_from_char(h[i].to_int())
    i = i + 1
  }
  "@@ -" + c.to_string() + "," + d.to_string() + " +" + a.to_string() + "," +
  b.to_string() + " @@"
}

/// Applies a unified diff in the *reverse* direction: given the **new** text
/// and the patch (old -> new), it reconstructs the **old** text. This mirrors
/// the behaviour of `patch -R`.
pub fn apply_unified_reverse(new_text: String, patch: String) -> String {
  let new_lines = split_lines(new_text)
  let patch_lines = split_lines(patch)
  let result: Array[String] = []
  let mut new_idx = 0
  let mut i = 0
  while i < patch_lines.length() {
    let line = patch_lines[i]
    if is_meta(line) {
      if line.length() >= 2 && line[0] == '@' {
        let target = parse_new_start(line) - 1
        while new_idx < target {
          result.push(new_lines[new_idx])
          new_idx = new_idx + 1
        }
      }
      i = i + 1
      continue
    }
    if line.length() == 0 {
      i = i + 1
      continue
    }
    let first = line[0]
    if first == ' ' {
      result.push(line[1:].to_owned())
      new_idx = new_idx + 1
    } else if first == '+' {
      // forward insertion: absent from the old text, just consume it
      new_idx = new_idx + 1
    } else if first == '-' {
      // forward deletion: restore it in the old text
      result.push(line[1:].to_owned())
    }
    i = i + 1
  }
  while new_idx < new_lines.length() {
    result.push(new_lines[new_idx])
    new_idx = new_idx + 1
  }
  result.join("\n")
}

/// Returns the reversed patch (new -> old) by swapping `-`/`+` markers and the
/// `---`/`+++` and `@@` header ranges. The result can be applied with the
/// regular `apply_unified`. Equivalent to `patch -R` on the patch file.
pub fn reverse_unified(patch: String) -> String {
  let lines = split_lines(patch)
  let out: Array[String] = []
  for line in lines {
    if line.length() >= 4 && line[0] == '-' && line[1] == '-' && line[2] == '-' &&
       line[3] == ' ' {
      out.push("+++" + line[3:].to_owned())
    } else if line.length() >= 4 && line[0] == '+' && line[1] == '+' &&
       line[2] == '+' && line[3] == ' ' {
      out.push("---" + line[3:].to_owned())
    } else if line.length() >= 2 && line[0] == '@' && line[1] == '@' {
      out.push(reverse_header(line))
    } else if line.length() >= 1 && (line[0] == '-' || line[0] == '+') {
      if line[0] == '-' {
        out.push("+" + line[1:].to_owned())
      } else {
        out.push("-" + line[1:].to_owned())
      }
    } else {
      out.push(line)
    }
  }
  out.join("\n")
}
