# moon-diff

[![CI](https://github.com/yuzhiblue/moon-diff/actions/workflows/ci.yml/badge.svg)](https://github.com/yuzhiblue/moon-diff/actions)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

A text **diff & patch** library for [MoonBit](https://www.moonbitlang.com/), written for the
*MoonBit 国产基础软件生态开源大赛 (MGPIC 2026)*.

`moon-diff` computes the difference between two sequences and renders/apply standard
**unified diffs** (the `diff -u` format used by Git, patch, etc.). It is generic over the
element type, so it works on lines, tokens, AST nodes, or any `Array[T]`.

## Features

- **Two diff algorithms** — classic LCS-based diff (`diff`) and Myers' `O(ND)` algorithm
  (`myers_diff`) that produces a *minimal* edit script.
- **Unified diff rendering** — `to_unified` emits GNU `diff -u` style output with context
  lines and `@@` headers, compatible with standard `patch` tooling.
- **Patch application** — `apply_unified` reads a unified diff back and reconstructs the
  new text, so diffs are fully reversible.
- **Generic & zero-dependency** — works on any `T` with `Eq` (and `Show` for rendering).
  No external crates required.
- **Small & fast** — self-contained `.mbt` files, constant-factor optimised DP tables.
- **Token & character-level diff** — go finer than lines: `diff_tokens` diffs at word
  granularity (whitespace preserved) and `diff_chars` at single-character granularity,
  useful for inline/highlight diffs.
- **Reverse apply (`patch -R`)** — `apply_unified_reverse` applies a unified diff *backwards*
  (new → old) and `reverse_unified` flips a patch's `+`/`-` signs, so any diff is reversible.
- **Git-style & binary diff** — `git_diff_text` emits Git's `diff --git` / `index <sha>` headers,
  `git_blob_hash` computes the Git blob SHA-1, and `binary_diff` emits the
  `Binary files ... differ` / `GIT binary patch` format used by `git diff --binary`.
- **Verified SHA-1** — `sha1_hex` is a from-scratch, fully tested implementation (empty string,
  the classic *fox* vector, and the 56-byte two-block vector all match).

## Install

```bash
moon add yuzhiblue/moon-diff
```

Then import it in your package:

```mbt
import yuzhiblue/moon-diff/diff
```

## Quick start

```mbt
import yuzhiblue/moon-diff/diff

// Diff two sequences (LCS based)
let a = ["apple", "banana", "cherry"]
let b = ["apple", "blueberry", "cherry"]
let changes = diff(a, b)
// changes = [Equal("apple"), Delete("banana"), Insert("blueberry"), Equal("cherry")]

// Reconstruct either side from the change list
to_new(changes)  // ["apple", "blueberry", "cherry"]
to_old(changes)  // ["apple", "banana", "cherry"]

// Diff two texts line-by-line, then render a unified diff
let old_text = "line1\nline2\nline3\nline4\nline5"
let new_text = "line1\nLINE2\nline3\nline4\nline5x"
let patch = to_unified(diff_lines(old_text, new_text), "old.txt", "new.txt", 3)
println(patch)
// --- old.txt
// +++ new.txt
// @@ -1,5 +1,5 @@
//  line1
// -line2
// +LINE2
//  line3
//  line4
// -line5
// +line5x

// Apply the patch back — fully reversible
let result = apply_unified(old_text, patch)
// result == new_text
```

### Myers' minimal edit script

`myers_diff` finds the shortest edit path and is preferable when you want the *smallest*
possible change set (e.g. for human-readable diffs):

```mbt
let a = ["the", "quick", "brown", "fox", "jumps"]
let b = ["the", "slow", "brown", "fox", "sleeps"]
let changes = myers_diff(a, b)
// both to_new(changes) == b and to_old(changes) == a hold
```

### Token & character-level diff

Beyond whole lines, `moon-diff` can diff at word or character granularity — handy for
inline / syntax-highlighting diffs. Whitespace is preserved by `diff_tokens`:

```mbt
// Word-level diff (whitespace preserved)
let a = "the cat sat on the mat"
let b = "the dog sat on a mat"
let tok = diff_tokens(a, b)
changes_to_string(tok)  // "the dog sat on a mat"  (== b)
to_old(tok).join("")    // "the cat sat on the mat" (== a)

// Character-level diff
let ch = diff_chars("kitten", "sitting")
changes_to_string(ch)   // "sitting"
```

`tokenize` splits text into alternating word / whitespace runs, so the token diff stays
faithful to the original spacing and newlines.

### Reverse apply (`patch -R`)

Every unified diff is reversible. `apply_unified_reverse` applies a patch *backwards*
(new text → old text), and `reverse_unified` returns a patch with its `+`/`-` signs flipped:

```mbt
let old = "line1\nline2\nline3\nline4\nline5"
let new = "line1\nLINE2\nline3\nline4\nline5x"
let patch = to_unified(diff_lines(old, new), "old.txt", "new.txt", 3)

apply_unified(old, patch)        // == new
apply_unified_reverse(new, patch) // == old   (patch -R)

let rev = reverse_unified(patch)
apply_unified(new, rev)           // == old
```

### Git-style & binary diff

`git_diff_text` produces Git-compatible headers (`diff --git`, `index <sha> <sha>`,
`--- a/`, `+++ b/`) that play well with `git apply`. `git_blob_hash` computes the
standard Git blob SHA-1 (`sha1_hex("blob " + size + "\0" + content)`), and `binary_diff`
emits the `Binary files ... differ` / `GIT binary patch` form used by `git diff --binary`:

```mbt
let patch = git_diff_text(old, new, "a/file.txt", "b/file.txt", 3)
git_blob_hash(old).length()  // 40 (hex SHA-1)

let bin = binary_diff("old bytes", "new bytes", "data.bin")
// bin contains: "Binary files a/data.bin and b/data.bin differ"
//               "GIT binary patch"
```

`sha1_hex` itself is a from-scratch, fully-tested SHA-1 (the empty string, the *fox*
sentence, and the 56-byte two-block vector all match the reference values).

### Performance benchmark

`src/bench/bench.mbt` is a self-contained harness that diffs synthetic corpora with all
three strategies and streams timing-friendly `RESULT` lines; `docs/benchmark.py` runs the
same workloads through Python's `difflib` and compares them:

```bash
moon run --release src/bench        # MoonBit side
python docs/benchmark.py            # MoonBit vs Python difflib, writes docs/bench_results.md
```

On low-edit (realistic) workloads MoonBit's Myers `O(ND)` implementation runs **up to ~3×
faster** than CPython's `difflib.SequenceMatcher`; see `docs/bench_results.md` for the full
table. (The optimised JS backend is used here because no system C compiler is installed for
the native target; the production native build would be faster still.)

## API reference

| Function | Signature | Description |
|----------|-----------|-------------|
| `diff` | `fn[T: Eq] diff(Array[T], Array[T]) -> Array[Change[T]]` | LCS-based difference |
| `myers_diff` | `fn[T: Eq] myers_diff(Array[T], Array[T]) -> Array[Change[T]]` | Myers `O(ND)` minimal diff |
| `to_new` | `fn[T] to_new(Array[Change[T]]) -> Array[T]` | reconstruct the *new* sequence |
| `to_old` | `fn[T] to_old(Array[Change[T]]) -> Array[T]` | reconstruct the *old* sequence |
| `diff_lines` | `fn diff_lines(String, String) -> Array[Change[String]]` | diff two texts by line |
| `diff_chars` | `fn diff_chars(String, String) -> Array[Change[String]]` | character-level diff |
| `diff_tokens` | `fn diff_tokens(String, String) -> Array[Change[String]]` | word/token-level diff (whitespace preserved) |
| `tokenize` | `fn tokenize(String) -> Array[String]` | split into alternating word / whitespace runs |
| `changes_to_string` | `fn changes_to_string(Array[Change[String]]) -> String` | reconstruct a `String` from a change list |
| `to_unified` | `fn[T: Show] to_unified(Array[Change[T]], String, String, Int) -> String` | render a unified diff (`context` = lines of context) |
| `apply_unified` | `fn apply_unified(String, String) -> String` | apply a unified diff to the old text |
| `apply_unified_reverse` | `fn apply_unified_reverse(String, String) -> String` | apply a unified diff backwards (`patch -R`) |
| `reverse_unified` | `fn reverse_unified(String) -> String` | flip a patch's `+`/`-` signs |
| `git_diff_text` | `fn git_diff_text(String, String, String, String, Int) -> String` | Git-style `diff --git` / `index` headers |
| `git_blob_hash` | `fn git_blob_hash(String) -> String` | Git blob SHA-1 of a string |
| `binary_diff` | `fn binary_diff(String, String, String) -> String` | `git diff --binary` / `Binary files ... differ` format |
| `sha1_hex` | `fn sha1_hex(String) -> String` | from-scratch SHA-1 (hex) |

`Change[T]` is `Equal(T) | Delete(T) | Insert(T)`.

## How it works

- **`diff`** builds an LCS DP table `dp[i][j]` (length of LCS of `a[0..i)` and `b[0..j)`)
  and backtracks it to recover `Equal` / `Delete` / `Insert` operations in forward order.
- **`myers_diff`** runs the classic Myers algorithm with the `V` array + trace, then
  backtracks the trace to recover a *minimal* edit script (same edit distance as `diff`,
  usually fewer/cleaner operations).
- **`to_unified`** walks the change list, groups changed lines into hunks of `context`
  surrounding lines, and emits `@@ -old,count +new,count @@` headers.
- **`apply_unified`** parses those headers and replays `+`/`-`/space lines onto the old text.
- **`sha1_hex`** (in `git.mbt`) is a from-scratch SHA-1: it pads the input into 512-bit
  blocks, runs the 80-round compression, and returns the hex digest. `git_blob_hash` wraps
  it as `blob <size>\0<content>` (Git's blob object format), while `git_diff_text` /
  `binary_diff` wrap `to_unified` with Git's `diff --git` / `index` headers and the binary
  `GIT binary patch` form.

### Complexity

| Algorithm | Time | Space |
|-----------|------|-------|
| `diff` (LCS) | `O(n·m)` | `O(n·m)` |
| `myers_diff` | `O((n+m)·D)` | `O((n+m)·D)` |
| `to_unified` / `apply_unified` | `O(n)` | `O(n)` |

where `n, m` are the sequence lengths and `D` is the edit distance.

## Build & test

```bash
moon build                  # build all packages (default + bench)
moon test                   # run the test suite (15 cases)
moon run --release src/bench  # run the benchmark harness (MoonBit side)
python docs/benchmark.py    # MoonBit vs Python difflib comparison
```

CI runs `moon test` on every push/PR via `.github/workflows/ci.yml`.

## Project layout

```
moon.mod.json
src/diff/
  types.mbt      # Change enum: Equal / Delete / Insert
  core.mbt       # lcs_table, diff, myers_diff, to_new / to_old, diff_lines, diff_chars, diff_tokens, tokenize
  unified.mbt    # to_unified, apply_unified, apply_unified_reverse, reverse_unified
  git.mbt        # sha1_hex, git_blob_hash, git_diff_text, binary_diff
  diff_test.mbt  # test blocks (run with `moon test`)
src/bench/
  bench.mbt      # benchmark harness (RESULT-line protocol)
  moon.pkg.json
docs/
  benchmark.py   # MoonBit vs Python difflib driver
  bench_results.md
```

## Roadmap

- [x] Character/token-level diff mode (not only line-level).
- [x] Reverse apply (`patch -R`) via `apply_unified_reverse` / `reverse_unified`.
- [x] Git-style & binary diff (`git_diff_text`, `binary_diff`) + verified SHA-1.
- [x] Benchmark suite vs. reference implementations (`difflib`).
- [x] `patch`/`git apply`-compatible heuristics (fuzz, offset) via `apply_unified_fuzzy`.
- [x] `word_diff` / `word_diff_html` for intra-line highlighting.

## License

Apache License 2.0 — see [LICENSE](./LICENSE).

## Links

- Repository: <https://github.com/yuzhiblue/moon-diff>
- MoonBit: <https://www.moonbitlang.com/>
