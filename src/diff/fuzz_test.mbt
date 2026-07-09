// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.

// ---------------------------------------------------------------------------
// Property / fuzz tests.
//
// A tiny, dependency-free xorshift32 PRNG generates reproducible random inputs
// (seeded with a fixed constant) so a failure can always be reproduced. The
// tests assert the *invariants* that must hold for every diff / patch produced
// by the library:
//
//   * every one of the 5 algorithms reconstructs both inputs (to_new / to_old);
//   * the three minimal algorithms agree on the edit distance;
//   * a generated JSON Patch, when applied, recovers the target document;
//   * a generated multi-file tree patch, when applied, recovers the new tree;
//   * the Unicode tokeniser reconstructs both inputs;
//   * `ratio` always stays within [0, 1] (and is 1 for identical strings).
// ---------------------------------------------------------------------------

/// Mutable PRNG state, held in a 1-element array so mutation persists across
/// calls (MoonBit passes structs by value).
fn rng_new(seed: Int) -> Array[Int] {
  [if seed == 0 { 0x9e3779b9 } else { seed }]
}

fn rng_next(s: Array[Int]) -> Int {
  let mut x = s[0]
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  s[0] = x
  x
}

fn rng_int(s: Array[Int], n: Int) -> Int {
  if n <= 0 {
    return 0
  }
  let v = rng_next(s)
  let pos = if v < 0 { -v } else { v }
  pos % n
}

fn rng_bool(s: Array[Int]) -> Bool {
  rng_int(s, 2) == 0
}

/// Picks a uniformly random element of a non-empty `Array[String]`.
fn rng_pick(s: Array[Int], a: Array[String]) -> String {
  a[rng_int(s, a.length())]
}

/// Mixed alphabet: Latin words, spaces, digits, and CJK characters — exercises
/// both the ASCII and the Unicode code paths of the tokeniser.
let fuzz_alpha: Array[String] = [
  "a", "b", "c", " ", "x", "y", "z", " ", "the", " ", "我", "爱", "北",
  "京", "的", "。", "！", "，", "1", "2",
]

fn rng_text(s: Array[Int], maxlen: Int) -> String {
  let n = rng_int(s, maxlen + 1)
  let mut out = ""
  for i = 0; i < n; i = i + 1 {
    out = out + rng_pick(s, fuzz_alpha)
  }
  out
}

/// Random sequence of words drawn from a small vocabulary, so diffs are
/// non-trivial and every algorithm is exercised.
fn rng_seq(s: Array[Int], n: Int, vocab: Array[String]) -> Array[String] {
  let out: Array[String] = []
  for i = 0; i < n; i = i + 1 {
    out.push(rng_pick(s, vocab))
  }
  out
}

/// Random JSON value (bounded depth so it stays small and fast to diff/apply).
fn rng_json(s: Array[Int], depth: Int) -> Json {
  if depth > 3 {
    return json_str(rng_text(s, 6))
  }
  let r = rng_int(s, 10)
  if r == 0 {
    json_null()
  } else if r == 1 {
    json_bool(rng_bool(s))
  } else if r == 2 {
    json_num(rng_int(s, 1000).to_string())
  } else if r == 3 {
    json_str(rng_text(s, 6))
  } else if r < 7 {
    let len = rng_int(s, 4)
    let arr: Array[Json] = []
    for i = 0; i < len; i = i + 1 {
      arr.push(rng_json(s, depth + 1))
    }
    json_arr(arr)
  } else {
    let len = rng_int(s, 4)
    let obj: Array[(String, Json)] = []
    for i = 0; i < len; i = i + 1 {
      obj.push(("k" + i.to_string(), rng_json(s, depth + 1)))
    }
    json_obj(obj)
  }
}

/// Counts non-`Equal` operations in an edit script (the edit distance).
fn count_dist(ch: Array[Change[String]]) -> Int {
  let mut d = 0
  for c in ch {
    match c {
      Equal(_) => ()
      _ => d = d + 1
    }
  }
  d
}

test "fuzz all algorithms reconstruct" {
  let rng = rng_new(12345)
  let vocab = ["alpha", "beta", "gamma", "x", "y", "z", ""]
  let algos = [
    diff_algorithm_by_name("lcs"),
    diff_algorithm_by_name("myers"),
    diff_algorithm_by_name("patience"),
    diff_algorithm_by_name("histogram"),
    diff_algorithm_by_name("linear"),
  ]
  for _t = 0; _t < 300; _t = _t + 1 {
    let a = rng_seq(rng, rng_int(rng, 12), vocab)
    let b = rng_seq(rng, rng_int(rng, 12), vocab)
    for algo in algos {
      let ch = diff_algorithm(algo, a, b)
      assert_true(to_new(ch) == b)
      assert_true(to_old(ch) == a)
    }
  }
}

test "fuzz minimal distance matches across lcs/myers/linear" {
  let rng = rng_new(777)
  let vocab = ["a", "b", "c", "d", "e"]
  for _t = 0; _t < 300; _t = _t + 1 {
    let a = rng_seq(rng, rng_int(rng, 10), vocab)
    let b = rng_seq(rng, rng_int(rng, 10), vocab)
    let dl = count_dist(diff(a, b))
    let dm = count_dist(myers_diff(a, b))
    let dli = count_dist(diff_linear(a, b))
    assert_eq(dl, dm)
    assert_eq(dl, dli)
  }
}

test "fuzz json patch round trip" {
  let rng = rng_new(2024)
  for _t = 0; _t < 200; _t = _t + 1 {
    let a = rng_json(rng, 0)
    let b = rng_json(rng, 0)
    let ops = json_diff(a, b, "")
    match apply_json_patch(a, ops) {
      Ok(res) => assert_true(json_equal(res, b))
      Err(e) => {
        println("json apply failed: " + e)
        assert_true(false)
      }
    }
  }
}

test "fuzz json patch text round trip" {
  let rng = rng_new(99)
  for _t = 0; _t < 150; _t = _t + 1 {
    let a = rng_json(rng, 0)
    let b = rng_json(rng, 0)
    let pa = json_to_string(a)
    let patch = match json_diff_text(pa, json_to_string(b)) {
      Ok(s) => s
      Err(_) => ""
    }
    match apply_json_patch_text(pa, patch) {
      Ok(res) =>
        match parse_json(res) {
          Ok(rj) => assert_true(json_equal(rj, b))
          Err(_) => assert_true(false)
        }
      Err(e) => {
        println("text apply failed: " + e)
        assert_true(false)
      }
    }
  }
}

test "fuzz tree patch round trip" {
  let rng = rng_new(555)
  let files = ["a.txt", "b.txt", "c.txt", "dir/d.txt", "e.md"]
  for _t = 0; _t < 200; _t = _t + 1 {
    let old_fs: Array[(String, String)] = []
    let new_fs: Array[(String, String)] = []
    for f in files {
      if rng_bool(rng) {
        old_fs.push((f, rng_text(rng, 30)))
      }
      if rng_bool(rng) {
        new_fs.push((f, rng_text(rng, 30)))
      }
    }
    let patch = render_tree_patch(old_fs, new_fs, 50)
    match apply_tree_patch(old_fs, patch) {
      Ok(result) => {
        let mut ok = true
        for p in new_fs {
          let mut found = false
          for q in result {
            if q.0 == p.0 && q.1 == p.1 {
              found = true
            }
          }
          if !found {
            ok = false
          }
        }
        if !ok {
          println("=== TREE ROUNDTRIP MISMATCH ===")
          println(patch)
          println("--- expected new_fs ---")
          for p in new_fs {
            println(p.0 + " => [" + p.1 + "]")
          }
          println("--- got result ---")
          for q in result {
            println(q.0 + " => [" + q.1 + "]")
          }
        }
        assert_true(ok)
      }
      Err(e) => {
        println("tree apply failed: " + e)
        assert_true(false)
      }
    }
  }
}

test "fuzz unicode tokenizer reconstruct" {
  let rng = rng_new(31415)
  for _t = 0; _t < 300; _t = _t + 1 {
    let a = rng_text(rng, 20)
    let b = rng_text(rng, 20)
    let ch = diff_tokens_unicode(a, b)
    assert_true(to_new(ch).join("") == b)
    assert_true(to_old(ch).join("") == a)
  }
}

test "chinese tokenizer splits per character" {
  let toks = tokenize_unicode("我爱北京")
  assert_eq(toks.length(), 4)
  assert_eq(toks[0], "我")
  assert_eq(toks[3], "京")
}

test "chinese diff detects single char change" {
  let ch = diff_tokens_unicode("我爱北京", "我爱南京")
  assert_eq(changes_to_string(ch), "我爱南京")
  assert_eq(to_old(ch).join(""), "我爱北京")
}

test "ratio identical is 1" {
  assert_true(ratio("hello", "hello") == 1.0)
  assert_true(ratio("我爱北京", "我爱北京") == 1.0)
}

test "ratio disjoint is 0" {
  assert_true(ratio("abc", "xyz") == 0.0)
}

test "ratio bounds and cjk monotonic" {
  let r1 = ratio("我爱北京", "我爱北京")
  let r2 = ratio("我爱北京", "我爱南京")
  assert_true(r1 >= r2)
  assert_true(r2 >= 0.0)
  assert_true(r1 <= 1.0)
}

test "fuzz ratio in [0,1]" {
  let rng = rng_new(8675309)
  for _t = 0; _t < 300; _t = _t + 1 {
    let a = rng_text(rng, 16)
    let b = rng_text(rng, 16)
    let r = ratio(a, b)
    assert_true(r >= 0.0)
    assert_true(r <= 1.0)
  }
}
