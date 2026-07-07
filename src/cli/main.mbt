// Copyright 2026 The moon-diff Authors.
// Licensed under the Apache License, Version 2.0.
//
// `moon-diff` command-line front-end. It is also the project's *runnable
// example*: every subcommand demonstrates a piece of the library on text passed
// as arguments. Because the Core SDK bundles no filesystem package, multi-line
// inputs use the escape sequences `\n` (newline) and `\t` (tab), e.g.
//
//   moon run cli -- diff "line1\nline2" "line1\nLINE2"
//
// All output goes to stdout; the process exits 0 on success.

/// Converts the escape sequences `\n` (newline) and `\t` (tab) in `s` into the
/// corresponding control characters, so multi-line inputs can be supplied as a
/// single command-line argument. A backslash before any other character is
/// preserved literally.
fn unescape(s: String) -> String {
  let out: String = ""
  let mut i = 0
  let n = s.length()
  while i < n {
    let c = s[i]
    if c == '\\' && i + 1 < n {
      let nxt = s[i + 1]
      if nxt == 'n' {
        out = out + "\n"
        i = i + 2
      } else if nxt == 't' {
        out = out + "\t"
        i = i + 2
      } else {
        out = out + "\{c}"
        i = i + 1
      }
    } else {
      out = out + "\{c}"
      i = i + 1
    }
  }
  out
}

/// Parses a non-negative integer, returning `default` on any malformed input.
fn parse_int(s: String, default: Int) -> Int {
  let mut v = 0
  let mut any = false
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      v = v * 10 + (c.to_int() - '0'.to_int())
      any = true
    } else {
      return default
    }
  }
  if any {
    v
  } else {
    default
  }
}

/// Maps an algorithm name to its `DiffAlgorithm` value (unknown names fall back
/// to the linear-space Hirschberg algorithm).
fn algo_of(s: String) -> DiffAlgorithm {
  match s {
    "lcs" => LCS
    "myers" => Myers
    "patience" => Patience
    "histogram" => Histogram
    _ => Linear
  }
}

/// Splits `args[start..]` into positional arguments plus the parsed flags
/// `--algo <name>`, `--context <n>`, `--git`, `--ours`, `--theirs`.
fn parse_flags(
  args: Array[String],
  start: Int
) -> (Array[String], String, Int, Bool, String) {
  let pos: Array[String] = []
  let mut algo = "linear"
  let mut context = 3
  let mut git = false
  let mut resolve = ""
  let mut i = start
  while i < args.length() {
    let a = args[i]
    if a == "--algo" && i + 1 < args.length() {
      algo = args[i + 1]
      i = i + 2
    } else if a == "--context" && i + 1 < args.length() {
      context = parse_int(args[i + 1], 3)
      i = i + 2
    } else if a == "--git" {
      git = true
      i = i + 1
    } else if a == "--ours" {
      resolve = "ours"
      i = i + 1
    } else if a == "--theirs" {
      resolve = "theirs"
      i = i + 1
    } else {
      pos.push(a)
      i = i + 1
    }
  }
  (pos, algo, context, git, resolve)
}

fn print_usage() -> Unit {
  println("moon-diff - a text diff & patch toolkit")
  println("")
  println("usage: moon run cli -- <command> [args] [flags]")
  println("")
  println("commands:")
  println("  diff OLD NEW [--algo lcs|myers|patience|histogram|linear]")
  println("              [--context N] [--git]   unified (or git) diff of two texts")
  println("  patch OLD PATCH                         apply a unified diff to OLD")
  println("  merge BASE OURS THEIRS [--ours|--theirs]  3-way merge (diff3 style)")
  println("  json A B                                RFC 6902 JSON Patch of A -> B")
  println("  algo OLD NEW                            edit distance of all 5 algorithms")
  println("  selftest                                internal consistency checks")
  println("")
  println("multi-line arguments use \\n (newline) and \\t (tab) escapes.")
}

fn cmd_diff(args: Array[String]) -> Unit {
  let (pos, algo, context, git, _) = parse_flags(args, 2)
  if pos.length() < 2 {
    println("diff: expected two texts (OLD NEW)")
    return
  }
  let old = unescape(pos[0])
  let new = unescape(pos[1])
  if git {
    println(git_diff_text(old, new, "a", "b", context))
  } else {
    let changes = diff_algorithm(algo_of(algo), split_lines(old), split_lines(new))
    println(to_unified(changes, "a.txt", "b.txt", context))
  }
}

fn cmd_patch(args: Array[String]) -> Unit {
  let (pos, _, _, _, _) = parse_flags(args, 2)
  if pos.length() < 2 {
    println("patch: expected (OLD PATCH)")
    return
  }
  let old = unescape(pos[0])
  let patch = unescape(pos[1])
  println(apply_unified(old, patch))
}

fn cmd_merge(args: Array[String]) -> Unit {
  let (pos, _, _, _, resolve) = parse_flags(args, 2)
  if pos.length() < 3 {
    println("merge: expected (BASE OURS THEIRS)")
    return
  }
  let base = split_lines(unescape(pos[0]))
  let ours = split_lines(unescape(pos[1]))
  let theirs = split_lines(unescape(pos[2]))
  let r = merge3(base, ours, theirs)
  if resolve == "ours" {
    let resolved = merge3_resolve_ours(r)
    println(resolved.join("\n"))
  } else if resolve == "theirs" {
    let resolved = merge3_resolve_theirs(r)
    println(resolved.join("\n"))
  } else {
    println(r.merged.join("\n"))
    if r.has_conflict {
      println("")
      println(
        "warning: " + r.conflicts.length().to_string() +
        " conflict(s); use --ours/--theirs to resolve",
      )
    }
  }
}

fn cmd_json(args: Array[String]) -> Unit {
  let (pos, _, _, _, _) = parse_flags(args, 2)
  if pos.length() < 2 {
    println("json: expected two JSON texts (A B)")
    return
  }
  let a = unescape(pos[0])
  let b = unescape(pos[1])
  match json_diff_text(a, b) {
    Ok(s) => println(s)
    Err(e) => println("json error: " + e)
  }
}

fn cmd_algo(args: Array[String]) -> Unit {
  let (pos, _, _, _, _) = parse_flags(args, 2)
  if pos.length() < 2 {
    println("algo: expected two texts (OLD NEW)")
    return
  }
  let a = split_lines(unescape(pos[0]))
  let b = split_lines(unescape(pos[1]))
  let algos: Array[(String, DiffAlgorithm)] = [
    ("lcs", LCS),
    ("myers", Myers),
    ("patience", Patience),
    ("histogram", Histogram),
    ("linear", Linear),
  ]
  for (name, algo) in algos {
    let ch = diff_algorithm(algo, a, b)
    let mut d = 0
    for c in ch {
      match c {
        Equal(_) => ()
        _ => d = d + 1
      }
    }
    println(name + ": distance=" + d.to_string())
  }
}

fn cmd_selftest() -> Unit {
  // 1. reconstruction: to_new / to_old round-trip for every algorithm
  let a = ["x", "y", "z"]
  let b = ["x", "Y", "z", "w"]
  let algos: Array[(String, DiffAlgorithm)] = [
    ("lcs", LCS),
    ("myers", Myers),
    ("patience", Patience),
    ("histogram", Histogram),
    ("linear", Linear),
  ]
  for (name, algo) in algos {
    let ch = diff_algorithm(algo, a, b)
    if to_new(ch) != b {
      println("selftest FAIL: " + name + " to_new")
      return
    }
    if to_old(ch) != a {
      println("selftest FAIL: " + name + " to_old")
      return
    }
  }
  // 2. clean 3-way merge (non-overlapping edits)
  let m = merge3(
    split_lines("1\n2\n3"),
    split_lines("1\n2\n3\n4"),
    split_lines("0\n1\n2\n3"),
  )
  if m.has_conflict {
    println("selftest FAIL: unexpected conflict")
    return
  }
  if m.merged.join("\n") != "0\n1\n2\n3\n4" {
    println("selftest FAIL: merge result wrong")
    return
  }
  // 3. json diff produces a non-empty patch for differing docs
  match json_diff_text("{\"a\":1}", "{\"a\":2}") {
    Ok(s) => {
      if s.length() < 2 {
        println("selftest FAIL: empty json patch")
        return
      }
    }
    Err(_) => {
      println("selftest FAIL: json parse error")
      return
    }
  }
  println("selftest: all checks passed")
}

fn main {
  let args = @env.args()
  if args.length() < 2 {
    print_usage()
    return
  }
  let cmd = args[1]
  match cmd {
    "diff" => cmd_diff(args)
    "patch" => cmd_patch(args)
    "merge" => cmd_merge(args)
    "json" => cmd_json(args)
    "algo" => cmd_algo(args)
    "selftest" => cmd_selftest()
    _ => print_usage()
  }
}
