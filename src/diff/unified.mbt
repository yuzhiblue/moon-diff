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
