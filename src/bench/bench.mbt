// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.
//
// Benchmark harness for moon-diff. Run with:
//
//     moon run src/bench
//
// It generates a synthetic corpus (words drawn from a fixed 10-word
// vocabulary, then edited with a target edit ratio) and exercises three diff
// strategies: Myers O(ND), LCS backtrack, and token-level diff. For each
// workload it runs the diff `reps` times and prints a `RESULT` line of the
// form:
//
//     RESULT|<words>|<ratio%>|<reps>|<checksum>
//
// Wall-clock timing is done by the caller (see docs/benchmark.py), which
// timestamps each RESULT line as it streams from this program's stdout. This
// keeps the MoonBit side free of any clock dependency and lets the same
// workload be compared apples-to-apples against Python's `difflib`.
//
// `ratio` is an integer percentage (0..100); all generation uses a 31-bit LCG
// (same constants as the Python reference) so both sides produce identical
// corpora.

let vocab: Array[String] = [
  "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "theta", "kappa",
  "lambda", "sigma",
]

// 31-bit LCG (same constants as the Python reference).
fn lcg(state: Int64) -> Int64 {
  (state * 1103515245L + 12345L) & 0x7fffffffL
}

fn gen_old(n: Int, seed: Int64) -> Array[String] {
  let mut state = seed
  let out: Array[String] = []
  for i = 0; i < n; i = i + 1 {
    state = lcg(state)
    out.push(vocab[(state % 10L).to_int()])
  }
  out
}

// `ratio` is an integer percentage (0..100).
fn gen_new(old: Array[String], ratio: Int, seed: Int64) -> Array[String] {
  let mut state = seed
  let r = ratio.to_int64()
  let out: Array[String] = []
  for i = 0; i < old.length(); i = i + 1 {
    state = lcg(state)
    if (state % 1000L) < r {
      state = lcg(state)
      let tok = vocab[(state % 10L).to_int()]
      state = lcg(state)
      let is_delete = (state % 2L) == 1L
      if !is_delete {
        out.push(tok)
      }
      state = lcg(state)
      if (state % 1000L) < (r * 3L / 10L) {
        out.push(tok)
      }
    } else {
      out.push(old[i])
    }
  }
  out
}

// One RESULT line per strategy so the caller can time each algorithm
// independently (Myers O(ND) is MoonBit's fast path; the plain LCS `diff` and
// the token-level `diff_tokens` are included for completeness and allocate an
// O(N*M) table).
//
// `old`/`new` are arrays of vocabulary words (so the line-level strategies
// `myers_diff`/`diff` operate word-by-word), while `old_str`/`new_str` are the
// same corpora joined with spaces so the token-level `diff_tokens` sees real
// word tokens.
fn run_strategy(
  strategy: String,
  n: Int,
  ratio: Int,
  reps: Int,
  old: Array[String],
  new: Array[String],
  old_str: String,
  new_str: String
) -> Unit {
  let mut sink = 0
  for r = 0; r < reps; r = r + 1 {
    if strategy == "myers" {
      sink = sink + @diff.myers_diff(old, new).length()
    } else if strategy == "lcs" {
      sink = sink + @diff.diff(old, new).length()
    } else {
      sink = sink + @diff.diff_tokens(old_str, new_str).length()
    }
  }
  println(
    "RESULT|" + strategy + "|" + n.to_string() + "|" + ratio.to_string() +
    "|" + reps.to_string() + "|" + sink.to_string(),
  )
}

fn run_one(n: Int, ratio: Int, reps: Int) -> Unit {
  let old = gen_old(n, 1234567L)
  let new = gen_new(old, ratio, 987654321L)
  let old_str = old.join(" ")
  let new_str = new.join(" ")
  run_strategy("myers", n, ratio, reps, old, new, old_str, new_str)
  run_strategy("lcs", n, ratio, reps, old, new, old_str, new_str)
  run_strategy("tokens", n, ratio, reps, old, new, old_str, new_str)
}

fn main {
  // Warm up the runtime so the first timed strategy is not penalised by
  // one-off startup costs.
  run_one(20, 10, 1)
  // Sizes are kept modest because the LCS-backed strategies (`diff`,
  // `diff_tokens`) allocate an O(N*M) table; `myers_diff` is O(ND) and could
  // go much larger.
  run_one(500, 10, 200)
  run_one(1500, 10, 40)
  run_one(3000, 10, 10)
  run_one(1500, 50, 40)
  println("DONE")
}
