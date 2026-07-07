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
- **Small & fast** — two self-contained `.mbt` files, constant-factor optimised DP tables.

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

## API reference

| Function | Signature | Description |
|----------|-----------|-------------|
| `diff` | `fn[T: Eq] diff(Array[T], Array[T]) -> Array[Change[T]]` | LCS-based difference |
| `myers_diff` | `fn[T: Eq] myers_diff(Array[T], Array[T]) -> Array[Change[T]]` | Myers `O(ND)` minimal diff |
| `to_new` | `fn[T] to_new(Array[Change[T]]) -> Array[T]` | reconstruct the *new* sequence |
| `to_old` | `fn[T] to_old(Array[Change[T]]) -> Array[T]` | reconstruct the *old* sequence |
| `diff_lines` | `fn diff_lines(String, String) -> Array[Change[String]]` | diff two texts by line |
| `to_unified` | `fn[T: Show] to_unified(Array[Change[T]], String, String, Int) -> String` | render a unified diff (`context` = lines of context) |
| `apply_unified` | `fn apply_unified(String, String) -> String` | apply a unified diff to the old text |

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

### Complexity

| Algorithm | Time | Space |
|-----------|------|-------|
| `diff` (LCS) | `O(n·m)` | `O(n·m)` |
| `myers_diff` | `O((n+m)·D)` | `O((n+m)·D)` |
| `to_unified` / `apply_unified` | `O(n)` | `O(n)` |

where `n, m` are the sequence lengths and `D` is the edit distance.

## Build & test

```bash
moon build --target wasm   # build the wasm artifact
moon test                  # run the test suite (8 cases)
```

CI runs both on every push/PR via `.github/workflows/ci.yml`.

## Project layout

```
moon.mod.json
src/diff/
  types.mbt      # Change enum: Equal / Delete / Insert
  core.mbt       # lcs_table, diff, myers_diff, to_new / to_old, diff_lines
  unified.mbt    # to_unified, apply_unified
  diff_test.mbt  # test blocks (run with `moon test`)
```

## Roadmap

- [ ] Character/token-level diff mode (not only line-level).
- [ ] `patch`/`git apply`-compatible heuristics (fuzz, offset).
- [ ] `word_diff` for intra-line highlighting.
- [ ] Benchmark suite vs. reference implementations.

## License

Apache License 2.0 — see [LICENSE](./LICENSE).

## Links

- Repository: <https://github.com/yuzhiblue/moon-diff>
- MoonBit: <https://www.moonbitlang.com/>
