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
/// cross-package (and not from `*_test.mbt` either), so these helpers let the
/// test package build `Json` values directly.
pub fn json_null() -> Json {
  Null
}

/// Builds a JSON string value.
pub fn json_str(s: String) -> Json {
  Str(s)
}

/// Builds a JSON number value (kept as its source text, like `parse_json`).
pub fn json_num(s: String) -> Json {
  Num(s)
}

/// Builds a JSON boolean value.
pub fn json_bool(b: Bool) -> Json {
  Bool(b)
}

/// Builds a JSON array value.
pub fn json_arr(a: Array[Json]) -> Json {
  Arr(a)
}

/// Builds a JSON object value.
pub fn json_obj(o: Array[(String, Json)]) -> Json {
  Obj(o)
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
  } nobreak {
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
  } nobreak {
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
  // Remove old tail elements from the *end* downwards, so that after each
  // removal the remaining (smaller) indices stay valid when the patch is applied
  // sequentially under RFC 6902 semantics (each op's path is relative to the
  // document as modified by the previous ops).
  let mut ri = n - 1
  while ri >= i {
    out.push(Remove(prefix + "/" + ri.to_string()))
    ri = ri - 1
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

// ===================== RFC 6902 JSON Patch *apply* =====================

/// Parses an RFC 6901 JSON Pointer into its reference tokens. An empty pointer
/// (`""` or `"/"`) yields an empty list, meaning "the whole document". A token
/// like `/a/b/c` becomes `["a", "b", "c"]`.
fn parse_json_pointer(path: String) -> Array[String] {
  if path.length() == 0 {
    return []
  }
  if path == "/" {
    return []
  }
  // split on '/', keeping the raw (still-escaped) segments
  let segs: Array[String] = []
  let mut buf = ""
  let mut i = 0
  let n = path.length()
  while i < n {
    let c = path[i].to_int().unsafe_to_char()
    if c == '/' {
      segs.push(buf)
      buf = ""
      i = i + 1
    } else {
      buf = buf + String::from_array([c])
      i = i + 1
    }
  }
  segs.push(buf)
  // drop the leading empty segment (the part before the first '/')
  let out: Array[String] = []
  for k = 1; k < segs.length(); k = k + 1 {
    out.push(unescape_token(segs[k]))
  }
  out
}

/// Unescapes the two JSON Pointer escape sequences: `~1` -> `/`, `~0` -> `~`
/// (applied in that order, per RFC 6901).
fn unescape_token(t: String) -> String {
  let mut out = ""
  let n = t.length()
  let mut i = 0
  while i < n {
    let c = t[i].to_int().unsafe_to_char()
    if c == '~' && i + 1 < n {
      let nx = t[i + 1].to_int().unsafe_to_char()
      if nx == '1' {
        out = out + "/"
        i = i + 2
      } else if nx == '0' {
        out = out + "~"
        i = i + 2
      } else {
        out = out + "~"
        i = i + 1
      }
    } else {
      out = out + String::from_array([c])
      i = i + 1
    }
  }
  out
}

/// Looks up a member of a JSON object by key.
fn obj_get(m: Array[(String, Json)], key: String) -> Option[Json] {
  for p in m {
    if p.0 == key {
      return Some(p.1)
    }
  }
  None
}

/// Returns the string value of an object member (or `""` if absent / not a string).
fn obj_get_str(m: Array[(String, Json)], key: String) -> String {
  match obj_get(m, key) {
    Some(Str(s)) => s
    _ => ""
  }
}

/// Replaces the value for `key` if present, otherwise inserts it in sorted
/// position so the object keeps its canonical (sorted) member order.
fn obj_set(m: Array[(String, Json)], key: String, val: Json) -> Array[(String, Json)] {
  let out: Array[(String, Json)] = []
  let mut inserted = false
  for p in m {
    if p.0 == key {
      out.push((key, val))
      inserted = true
    } else {
      out.push(p)
    }
  }
  if !inserted {
    out.push((key, val))
    for i = 1; i < out.length(); i = i + 1 {
      let mut j = i
      while j > 0 && out[j - 1].0 > out[j].0 {
        let tmp = out[j - 1]
        out[j - 1] = out[j]
        out[j] = tmp
        j = j - 1
      }
    }
  }
  out
}

/// Returns a copy of `m` with the `idx`-th member removed.
fn obj_remove(m: Array[(String, Json)], idx: Int) -> Array[(String, Json)] {
  let out: Array[(String, Json)] = []
  for i = 0; i < m.length(); i = i + 1 {
    if i != idx {
      out.push(m[i])
    }
  }
  out
}

/// Returns a copy of `m` with the `idx`-th member's value replaced.
fn obj_replace(m: Array[(String, Json)], idx: Int, v: Json) -> Array[(String, Json)] {
  let out: Array[(String, Json)] = []
  for i = 0; i < m.length(); i = i + 1 {
    if i == idx {
      out.push((m[i].0, v))
    } else {
      out.push(m[i])
    }
  }
  out
}

/// Inserts `v` into `a` at `idx` (0..=len); `idx == len` appends.
fn arr_insert(a: Array[Json], idx: Int, v: Json) -> Array[Json] {
  let out: Array[Json] = []
  for i = 0; i < a.length(); i = i + 1 {
    if i == idx {
      out.push(v)
    }
    out.push(a[i])
  }
  out
}

/// Returns a copy of `a` with the `idx`-th element replaced by `v`.
fn arr_replace(a: Array[Json], idx: Int, v: Json) -> Array[Json] {
  let out: Array[Json] = []
  for i = 0; i < a.length(); i = i + 1 {
    if i == idx {
      out.push(v)
    } else {
      out.push(a[i])
    }
  }
  out
}

/// Returns a copy of `a` with the `idx`-th element removed.
fn arr_remove(a: Array[Json], idx: Int) -> Array[Json] {
  let out: Array[Json] = []
  for i = 0; i < a.length(); i = i + 1 {
    if i != idx {
      out.push(a[i])
    }
  }
  out
}

/// Parses a decimal array index token; returns `-1` if not a non-negative int.
fn parse_index(tok: String) -> Int {
  if tok.length() == 0 {
    return -1
  }
  let mut v = 0
  for i = 0; i < tok.length(); i = i + 1 {
    let c = tok[i].to_int().unsafe_to_char()
    if c >= '0' && c <= '9' {
      v = v * 10 + (c.to_int() - '0'.to_int())
    } else {
      return -1
    }
  }
  v
}

/// Returns the `path` component carried by a patch op.
fn op_path(op: JsonPatchOp) -> String {
  match op {
    Add(p, _) => p
    Remove(p) => p
    Replace(p, _) => p
  }
}

/// Applies `op` to `doc` at the reference tokens in `path`, descending from
/// `depth`. When `depth == path.length()` the op applies to `doc` itself (the
/// whole-document / root case, used for an empty JSON Pointer).
fn apply_at(
  doc: Json,
  path: Array[String],
  depth: Int,
  op: JsonPatchOp
) -> Result[Json, String] {
  if depth >= path.length() {
    match op {
      Add(_, v) => Ok(v)
      Replace(_, v) => Ok(v)
      Remove(_) => Err("cannot remove the root document")
    }
  } else {
    match doc {
      Obj(m) => apply_obj(m, path, depth, op)
      Arr(a) => apply_arr(a, path, depth, op)
      _ => Err("cannot descend into a scalar value at path " + op_path(op))
    }
  }
}

fn apply_obj(
  m: Array[(String, Json)],
  path: Array[String],
  depth: Int,
  op: JsonPatchOp
) -> Result[Json, String] {
  let key = path[depth]
  let last = depth == path.length() - 1
  let mut found = -1
  for i = 0; i < m.length(); i = i + 1 {
    if m[i].0 == key {
      found = i
    }
  }
  if last {
    match op {
      Add(_, v) => Ok(Json::Obj(obj_set(m, key, v)))
      Replace(_, v) =>
        if found < 0 {
          Err("replace: key not found: " + key)
        } else {
          Ok(Json::Obj(obj_set(m, key, v)))
        }
      Remove(_) =>
        if found < 0 {
          Err("remove: key not found: " + key)
        } else {
          Ok(Json::Obj(obj_remove(m, found)))
        }
    }
  } else {
    if found < 0 {
      Err("path not found: " + key)
    } else {
      match apply_at(m[found].1, path, depth + 1, op) {
        Ok(nv) => Ok(Json::Obj(obj_replace(m, found, nv)))
        Err(e) => Err(e)
      }
    }
  }
}

fn apply_arr(
  a: Array[Json],
  path: Array[String],
  depth: Int,
  op: JsonPatchOp
) -> Result[Json, String] {
  let tok = path[depth]
  let last = depth == path.length() - 1
  if tok == "-" {
    if !last {
      return Err("'-' is only valid as the final path token")
    }
    match op {
      Add(_, v) => Ok(Json::Arr(arr_insert(a, a.length(), v)))
      _ => Err("'-' is only valid for 'add'")
    }
  } else {
    let idx = parse_index(tok)
    if idx < 0 {
      return Err("invalid array index: " + tok)
    }
    if last {
      match op {
        Add(_, v) =>
          if idx > a.length() {
            Err("add: array index out of range: " + tok)
          } else {
            Ok(Json::Arr(arr_insert(a, idx, v)))
          }
        Replace(_, v) =>
          if idx >= a.length() {
            Err("replace: array index out of range: " + tok)
          } else {
            Ok(Json::Arr(arr_replace(a, idx, v)))
          }
        Remove(_) =>
          if idx >= a.length() {
            Err("remove: array index out of range: " + tok)
          } else {
            Ok(Json::Arr(arr_remove(a, idx)))
          }
      }
    } else {
      if idx >= a.length() {
        return Err("array index out of range: " + tok)
      }
      match apply_at(a[idx], path, depth + 1, op) {
        Ok(nv) => Ok(Json::Arr(arr_replace(a, idx, nv)))
        Err(e) => Err(e)
      }
    }
  }
}

/// Applies an RFC 6902 JSON Patch (the ops produced by `json_diff`) to `doc`
/// and returns the resulting document, or an error string if any operation
/// cannot be applied (missing path, out-of-range index, etc.). Closes the
/// round-trip so a JSON Patch is fully reversible.
///
/// ```moonbit
/// let ops = json_diff(parse_json("{\"a\":1}"), parse_json("{\"a\":2}"), "")
/// apply_json_patch(parse_json("{\"a\":1}"), ops) // => Ok({"a":2})
/// ```
pub fn apply_json_patch(doc: Json, ops: Array[JsonPatchOp]) -> Result[Json, String] {
  let mut cur = doc
  for op in ops {
    let tokens = parse_json_pointer(op_path(op))
    match apply_at(cur, tokens, 0, op) {
      Ok(next) => cur = next
      Err(e) => return Err(e)
    }
  }
  Ok(cur)
}

/// Convenience: parse `doc_text` and a JSON Patch `patch_text`, apply the patch,
/// and return the serialised result (or an error string).
pub fn apply_json_patch_text(
  doc_text: String,
  patch_text: String
) -> Result[String, String] {
  match parse_json(doc_text) {
    Ok(doc) =>
      match parse_json(patch_text) {
        Ok(patch) =>
          match json_patch_from_json(patch) {
            Ok(ops) =>
              match apply_json_patch(doc, ops) {
                Ok(res) => Ok(json_to_string(res))
                Err(e) => Err(e)
              }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    Err(e) => Err(e)
  }
}

/// Parses a JSON Patch document (an array of `{"op":..., "path":..., "value":...}`)
/// into `JsonPatchOp` values. Only `add` / `remove` / `replace` are supported.
fn json_patch_from_json(j: Json) -> Result[Array[JsonPatchOp], String] {
  match j {
    Arr(items) => {
      let out: Array[JsonPatchOp] = []
      for it in items {
        match parse_one_op(it) {
          Ok(o) => out.push(o)
          Err(e) => return Err(e)
        }
      }
      Ok(out)
    }
    _ => Err("a JSON Patch must be an array")
  }
}

fn parse_one_op(o: Json) -> Result[JsonPatchOp, String] {
  match o {
    Obj(m) => {
      let opstr = obj_get_str(m, "op")
      let path = obj_get_str(m, "path")
      match opstr {
        "add" =>
          match obj_get(m, "value") {
            Some(v) => Ok(Add(path, v))
            None => Ok(Add(path, Null))
          }
        "remove" => Ok(Remove(path))
        "replace" =>
          match obj_get(m, "value") {
            Some(v) => Ok(Replace(path, v))
            None => Ok(Replace(path, Null))
          }
        _ => Err("unsupported JSON Patch op: " + opstr)
      }
    }
    _ => Err("each JSON Patch op must be an object")
  }
}
