// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

/// A minimal JSON value. Objects keep their members as a *sorted* key/value
/// array so that structural comparison is deterministic and order-independent.
pub enum Json {
  Null
  Bool(Bool)
  /// Numeric literal, kept as its source text so comparison is exact.
  Num(String)
  Str(String)
  Arr(Array[Json])
  Obj(Array[(String, Json)])
}

/// Constructs the `Json` `Null` value. Enum constructors are not constructible
/// cross-package, so this helper lets the test package obtain a `Null`.
pub fn json_null() -> Json {
  Null
}

/// A single RFC 6902 JSON Patch operation.
pub enum JsonPatchOp {
  /// `{"op":"add","path":p,"value":v}`
  Add(String, Json)
  /// `{"op":"remove","path":p}`
  Remove(String)
  /// `{"op":"replace","path":p,"value":v}`
  Replace(String, Json)
}

/// Returns `s[start..end)` as a fresh `String`.
fn substring(s: String, start: Int, end: Int) -> String {
  let mut out: String = ""
  let mut i = start
  while i < end && i < s.length() {
    out = out + String::from_array([s[i].to_int().unsafe_to_char()])
    i = i + 1
  }
  out
}

/// Reads the character code at `i` as an `Int` (string indexing yields a
/// `UInt16`; `.to_int()` turns it into a comparable code point).
fn code_at(s: String, i: Int) -> Int {
  s[i].to_int()
}

/// Skips spaces, tabs, newlines and carriage returns starting at `pos`.
fn skip_ws(s: String, pos: Int) -> Int {
  let mut p = pos
  while p < s.length() {
    let c = code_at(s, p)
    if c == ' '.to_int() || c == '\n'.to_int() || c == '\t'.to_int() ||
       c == '\r'.to_int() {
      p = p + 1
    } else {
      break
    }
  }
  p
}

fn json_is_digit(c: Char) -> Bool {
  c >= '0' && c <= '9'
}

fn hex_digit(c: Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    0
  }
}

fn parse_hex4(s: String, p: Int) -> Int {
  let mut v = 0
  for k = 0; k < 4; k = k + 1 {
    v = v * 16 + hex_digit(code_at(s, p + k).unsafe_to_char())
  }
  v
}

fn is_num_char(c: Char) -> Bool {
  json_is_digit(c) ||
  c == '-' ||
  c == '+' ||
  c == '.' ||
  c == 'e' ||
  c == 'E'
}

/// Parses a JSON string literal starting at the opening `"`.
fn parse_string(s: String, pos: Int) -> Result[(Json, Int), String] {
  let mut p = pos + 1
  let mut out = ""
  while p < s.length() {
    let c = code_at(s, p).unsafe_to_char()
    if c == '"' {
      return Ok((Str(out), p + 1))
    } else if c == '\\' {
      p = p + 1
      if p >= s.length() {
        return Err("unterminated escape")
      }
      let e = code_at(s, p).unsafe_to_char()
      if e == '"' {
        out = out + "\""
        p = p + 1
      } else if e == '\\' {
        out = out + "\\"
        p = p + 1
      } else if e == '/' {
        out = out + "/"
        p = p + 1
      } else if e == 'b' {
        out = out + "\b"
        p = p + 1
      } else if e == 'f' {
        out = out + "\f"
        p = p + 1
      } else if e == 'n' {
        out = out + "\n"
        p = p + 1
      } else if e == 'r' {
        out = out + "\r"
        p = p + 1
      } else if e == 't' {
        out = out + "\t"
        p = p + 1
      } else if e == 'u' {
        p = p + 1
        let cp = parse_hex4(s, p)
        out = out + String::from_array([cp.unsafe_to_char()])
        p = p + 4
      } else {
        return Err("invalid escape")
      }
    } else {
      out = out + String::from_array([c])
      p = p + 1
    }
  }
  Err("unterminated string")
}

fn parse_number(s: String, pos: Int) -> Result[(Json, Int), String] {
  let mut p = pos
  let start = p
  if p < s.length() &&
     (code_at(s, p) == '-'.to_int() || code_at(s, p) == '+'.to_int()) {
    p = p + 1
  }
  while p < s.length() &&
    is_num_char(code_at(s, p).unsafe_to_char()) {
    p = p + 1
  }
  if p == start {
    return Err("invalid number")
  }
  Ok((Num(substring(s, start, p)), p))
}

fn parse_bool(s: String, pos: Int) -> Result[(Json, Int), String] {
  if pos + 4 <= s.length() && substring(s, pos, pos + 4) == "true" {
    return Ok((Bool(true), pos + 4))
  }
  if pos + 5 <= s.length() && substring(s, pos, pos + 5) == "false" {
    return Ok((Bool(false), pos + 5))
  }
  Err("invalid literal")
}

fn parse_null(s: String, pos: Int) -> Result[(Json, Int), String] {
  if pos + 4 <= s.length() && substring(s, pos, pos + 4) == "null" {
    return Ok((Null, pos + 4))
  }
  Err("invalid literal")
}

/// Insertion-sorts an object's members by key (ascending) so that two objects
/// with the same members but different source order compare identically.
fn sort_pairs(pairs: Array[(String, Json)]) -> Array[(String, Json)] {
  let out: Array[(String, Json)] = []
  for p in pairs {
    out.push(p)
  }
  for i = 1; i < out.length(); i = i + 1 {
    let mut j = i
    while j > 0 && out[j - 1].0 > out[j].0 {
      let tmp = out[j - 1]
      out[j - 1] = out[j]
      out[j] = tmp
      j = j - 1
    }
  }
  out
}

fn parse_array(s: String, pos: Int) -> Result[(Json, Int), String] {
  let mut p = pos + 1
  let arr: Array[Json] = []
  p = skip_ws(s, p)
  if p >= s.length() {
    return Err("unterminated array")
  }
  if code_at(s, p) == ']'.to_int() {
    return Ok((Arr(arr), p + 1))
  }
  while true {
    match parse_value(s, p) {
      Ok((v, p2)) => {
        arr.push(v)
        p = p2
      }
      Err(e) => return Err(e)
    }
    p = skip_ws(s, p)
    if p >= s.length() {
      return Err("unterminated array")
    }
    if code_at(s, p) == ','.to_int() {
      p = skip_ws(s, p + 1)
    } else if code_at(s, p) == ']'.to_int() {
      return Ok((Arr(arr), p + 1))
    } else {
      return Err("expected ',' or ']' in array")
    }
  } else {
    return Err("unterminated array")
  }
}

fn parse_object(s: String, pos: Int) -> Result[(Json, Int), String] {
  let mut p = pos + 1
  let pairs: Array[(String, Json)] = []
  p = skip_ws(s, p)
  if p >= s.length() {
    return Err("unterminated object")
  }
  if code_at(s, p) == '}'.to_int() {
    return Ok((Obj(sort_pairs(pairs)), p + 1))
  }
  while true {
    p = skip_ws(s, p)
    if p >= s.length() || code_at(s, p) != '"'.to_int() {
      return Err("expected object key")
    }
    let mut key: String = ""
    match parse_string(s, p) {
      Ok((Str(k), p2)) => {
        key = k
        p = p2
      }
      _ => return Err("expected string key")
    }
    p = skip_ws(s, p)
    if p >= s.length() || code_at(s, p) != ':'.to_int() {
      return Err("expected ':'")
    }
    p = skip_ws(s, p + 1)
    match parse_value(s, p) {
      Ok((v, p2)) => {
        pairs.push((key, v))
        p = p2
      }
      Err(e) => return Err(e)
    }
    p = skip_ws(s, p)
    if p >= s.length() {
      return Err("unterminated object")
    }
    if code_at(s, p) == ','.to_int() {
      p = skip_ws(s, p + 1)
    } else if code_at(s, p) == '}'.to_int() {
      return Ok((Obj(sort_pairs(pairs)), p + 1))
    } else {
      return Err("expected ',' or '}' in object")
    }
  } else {
    return Err("unterminated object")
  }
}

/// Recursive-descent JSON parser. Returns `Err(msg)` on the first syntax error.
pub fn parse_json(s: String) -> Result[Json, String] {
  let p = skip_ws(s, 0)
  if p >= s.length() {
    return Err("empty input")
  }
  match parse_value(s, p) {
    Ok((j, _)) => Ok(j)
    Err(e) => Err(e)
  }
}

fn parse_value(s: String, pos: Int) -> Result[(Json, Int), String] {
  let p = skip_ws(s, pos)
  if p >= s.length() {
    return Err("unexpected end of input")
  }
  let c = code_at(s, p).unsafe_to_char()
  if c == '{' {
    parse_object(s, p)
  } else if c == '[' {
    parse_array(s, p)
  } else if c == '"' {
    parse_string(s, p)
  } else if c == 't' || c == 'f' {
    parse_bool(s, p)
  } else if c == 'n' {
    parse_null(s, p)
  } else if c == '-' || c == '+' || json_is_digit(c) {
    parse_number(s, p)
  } else {
    Err("unexpected token")
  }
}

/// Deep structural equality of two JSON values.
pub fn json_equal(a: Json, b: Json) -> Bool {
  match a {
    Null => {
      match b {
        Null => true
        _ => false
      }
    }
    Bool(x) => {
      match b {
        Bool(y) => x == y
        _ => false
      }
    }
    Num(x) => {
      match b {
        Num(y) => x == y
        _ => false
      }
    }
    Str(x) => {
      match b {
        Str(y) => x == y
        _ => false
      }
    }
    Arr(xs) => {
      match b {
        Arr(ys) => {
          if xs.length() != ys.length() {
            false
          } else {
            let mut eq = true
            for i = 0; i < xs.length(); i = i + 1 {
              if !json_equal(xs[i], ys[i]) {
                eq = false
              }
            }
            eq
          }
        }
        _ => false
      }
    }
    Obj(xs) => {
      match b {
        Obj(ys) => {
          if xs.length() != ys.length() {
            false
          } else {
            let mut eq = true
            for i = 0; i < xs.length(); i = i + 1 {
              let (k1, v1) = xs[i]
              let (k2, v2) = ys[i]
              if k1 != k2 || !json_equal(v1, v2) {
                eq = false
              }
            }
            eq
          }
        }
        _ => false
      }
    }
  }
}

fn escape_json(s: String) -> String {
  let mut out: String = ""
  for i = 0; i < s.length(); i = i + 1 {
    let c = code_at(s, i).unsafe_to_char()
    if c == '"' {
      out = out + "\\\""
    } else if c == '\\' {
      out = out + "\\\\"
    } else if c == '\n' {
      out = out + "\\n"
    } else if c == '\t' {
      out = out + "\\t"
    } else if c == '\r' {
      out = out + "\\r"
    } else {
      out = out + String::from_array([c])
    }
  }
  out
}

/// Serialises a `Json` value back to compact JSON text.
pub fn json_to_string(j: Json) -> String {
  match j {
    Null => "null"
    Bool(b) => if b { "true" } else { "false" }
    Num(s) => s
    Str(s) => "\"" + escape_json(s) + "\""
    Arr(xs) => {
      let parts: Array[String] = []
      for x in xs {
        parts.push(json_to_string(x))
      }
      "[" + parts.join(",") + "]"
    }
    Obj(xs) => {
      let parts: Array[String] = []
      for p in xs {
        parts.push(
          "\"" + escape_json(p.0) + "\":" + json_to_string(p.1),
        )
      }
      "{" + parts.join(",") + "}"
    }
  }
}

fn op_to_json(op: JsonPatchOp) -> String {
  match op {
    Add(path, val) =>
      "{\"op\":\"add\",\"path\":\"" + path + "\",\"value\":" +
      json_to_string(val) + "}"
    Remove(path) => "{\"op\":\"remove\",\"path\":\"" + path + "\"}"
    Replace(path, val) =>
      "{\"op\":\"replace\",\"path\":\"" + path + "\",\"value\":" +
      json_to_string(val) + "}"
  }
}

fn diff_objects(
  xs: Array[(String, Json)],
  ys: Array[(String, Json)],
  prefix: String
) -> Array[JsonPatchOp] {
  let out: Array[JsonPatchOp] = []
  let mut i = 0
  let mut j = 0
  while i < xs.length() && j < ys.length() {
    let (k1, v1) = xs[i]
    let (k2, v2) = ys[j]
    if k1 == k2 {
      let sub = json_diff(v1, v2, prefix + "/" + k1)
      for op in sub {
        out.push(op)
      }
      i = i + 1
      j = j + 1
    } else if k1 < k2 {
      out.push(Remove(prefix + "/" + k1))
      i = i + 1
    } else {
      out.push(Add(prefix + "/" + k2, v2))
      j = j + 1
    }
  }
  while i < xs.length() {
    out.push(Remove(prefix + "/" + xs[i].0))
    i = i + 1
  }
  while j < ys.length() {
    out.push(Add(prefix + "/" + ys[j].0, ys[j].1))
    j = j + 1
  }
  out
}

fn diff_arrays(
  xs: Array[Json],
  ys: Array[Json],
  prefix: String
) -> Array[JsonPatchOp] {
  let out: Array[JsonPatchOp] = []
  let n = xs.length()
  let m = ys.length()
  let mut i = 0
  while i < n && i < m {
    let sub = json_diff(xs[i], ys[i], prefix + "/" + i.to_string())
    for op in sub {
      out.push(op)
    }
    i = i + 1
  }
  while i < n {
    out.push(Remove(prefix + "/" + i.to_string()))
    i = i + 1
  }
  while i < m {
    out.push(Add(prefix + "/" + i.to_string(), ys[i]))
    i = i + 1
  }
  out
}

/// Computes a structural (RFC 6902) diff between two JSON values and returns the
/// list of patch operations needed to turn `a` into `b`. Object members are
/// compared by key (order-independent); array elements are compared
/// positionally.
pub fn json_diff(a: Json, b: Json, prefix: String) -> Array[JsonPatchOp] {
  match a {
    Obj(xs) => {
      match b {
        Obj(ys) => diff_objects(xs, ys, prefix)
        _ => [Replace(prefix, b)]
      }
    }
    Arr(xs) => {
      match b {
        Arr(ys) => diff_arrays(xs, ys, prefix)
        _ => [Replace(prefix, b)]
      }
    }
    Num(x) => {
      match b {
        Num(y) => if x == y { [] } else { [Replace(prefix, b)] }
        _ => [Replace(prefix, b)]
      }
    }
    Str(x) => {
      match b {
        Str(y) => if x == y { [] } else { [Replace(prefix, b)] }
        _ => [Replace(prefix, b)]
      }
    }
    Bool(x) => {
      match b {
        Bool(y) => if x == y { [] } else { [Replace(prefix, b)] }
        _ => [Replace(prefix, b)]
      }
    }
    Null => {
      match b {
        Null => []
        _ => [Replace(prefix, b)]
      }
    }
  }
}

/// Renders a list of patch operations as a JSON Patch document (a JSON array).
pub fn json_patch_to_string(ops: Array[JsonPatchOp]) -> String {
  let parts: Array[String] = []
  for op in ops {
    parts.push(op_to_json(op))
  }
  "[" + parts.join(",") + "]"
}

/// Parses two JSON texts and returns the JSON Patch document that transforms the
/// first into the second, or an error string if either side is not valid JSON.
pub fn json_diff_text(a: String, b: String) -> Result[String, String] {
  match parse_json(a) {
    Ok(ja) => {
      match parse_json(b) {
        Ok(jb) => Ok(json_patch_to_string(json_diff(ja, jb, "")))
        Err(e) => Err(e)
      }
    }
    Err(e) => Err(e)
  }
}
