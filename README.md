# moon-diff

[![CI](https://github.com/yuzhiblue/moon-diff/actions/workflows/ci.yml/badge.svg)](https://github.com/yuzhiblue/moon-diff/actions)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![mooncakes](https://img.shields.io/badge/mooncakes-yuzhiblue%2Fmoon--diff-blue)](https://mooncakes.io/package/yuzhiblue/moon-diff)

A text **diff & patch** library for [MoonBit](https://www.moonbitlang.com/), written for the
*MoonBit 国产基础软件生态开源大赛 (MGPIC 2026)*.

`moon-diff` computes the difference between two sequences and renders / applies standard
**unified diffs** (the `diff -u` format used by Git, patch, etc.). It is generic over the
element type, so it works on lines, tokens, AST nodes, or any `Array[T]`. On top of the core
diff engine it also offers **5 diff algorithms**, a **3-way merge**, a **semantic JSON diff**,
and a **multi-file tree diff** — all with zero external dependencies.

## Features

- **Five diff algorithms** — classic LCS (`diff`), Myers' `O(ND)` minimal edit script
  (`myers_diff`), Patience diff (`patience_diff`), Histogram diff (`histogram_diff`), and a
  linear-space Hirschberg algorithm (`diff_linear`) that uses only `O(|a|+|b|)` memory.
- **Unified diff rendering** — `to_unified` emits GNU `diff -u` style output with context
  lines and `@@` headers, compatible with standard `patch` tooling.
- **Patch application** — `apply_unified` reads a unified diff back and reconstructs the
  new text, so diffs are fully reversible. `apply_unified_fuzzy` tolerates offset / fuzz like
  `patch`/`git apply`.
- **Reverse apply (`patch -R`)** — `apply_unified_reverse` applies a unified diff *backwards*
  (new → old) and `reverse_unified` flips a patch's `+`/`-` signs.
- **Git-style & binary diff** — `git_diff_text` emits Git's `diff --git` / `index <sha>` headers,
  `git_blob_hash` computes the Git blob SHA-1, and `binary_diff` emits the
  `Binary files ... differ` format.
- **Verified SHA-1** — `sha1_hex` is a from-scratch, fully tested implementation.
- **Token & character-level diff** — `diff_tokens` (word granularity, whitespace preserved) and
  `diff_chars` (single-character), plus `word_diff` / `word_diff_html` for inline highlighting.
- **Unicode-aware tokeniser** — `tokenize_unicode` / `diff_tokens_unicode` split text into
  per-CJK-character and per-word tokens (ASCII whitespace preserved), so Chinese / Japanese /
  Korean diffs are compared character-by-character instead of as one opaque blob.
  `word_diff_unicode` / `word_diff_html_unicode` give inline highlighting for such text.
- **Similarity `ratio`** — `ratio(a, b)` returns a `Double` in `[0, 1]` (LCS-based, like
  Python's `difflib.ratio`) for ranking / near-duplicate detection — works on CJK text too.
- **3-way merge** — `merge3` implements the classic *diff3* region strategy with conflict
  markers and `git merge -X ours/theirs` style resolvers.
- **Semantic JSON diff** — `json_diff_text` parses two JSON documents and emits an
  [RFC 6902](https://datatracker.ietf.org/doc/html/rfc6902) JSON Patch (object order-independent).
- **JSON Patch *apply*** — `apply_json_patch` / `apply_json_patch_text` apply an RFC 6902 patch
  (add / remove / replace; objects & arrays; the `-` end-of-array token and JSON-Pointer `~` escape
  handling) back to a document, closing the round-trip so a patch is fully reversible.
- **Multi-file tree diff** — `diff_trees` / `render_tree_patch` / `apply_tree_patch` produce and
  consume Git-style multi-file patches with rename detection.
- **Generic & zero-dependency** — works on any `T` with `Eq` (and `Show` for rendering).
  - **Command-line tool** — `src/cli` is a runnable front-end
    (`diff` / `patch` / `merge` / `json` / `jsonapply` / `ratio` / `algo` / `selftest`)
    that doubles as the project's runnable example.

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

// Apply the patch back — fully reversible
let result = apply_unified(old_text, patch)
// result == new_text
```

### Choosing a diff algorithm

```mbt
import yuzhiblue/moon-diff/diff

let a = ["the", "quick", "brown", "fox", "jumps"]
let b = ["the", "slow", "brown", "fox", "sleeps"]
// all five produce an edit script whose to_new / to_old reconstruct b / a
let ch = diff_algorithm(Patience, a, b)
to_new(ch)  // == b
```

### 3-way merge

```mbt
import yuzhiblue/moon-diff/diff

let (merged, n) = merge3_count("1\n2\n3", "1\n2\nX\n3", "1\n2\nY\n3")
// merged contains diff3 conflict markers; n == 1 (one unresolved region)
```

### Semantic JSON diff (RFC 6902)

```mbt
import yuzhiblue/moon-diff/diff

let patch = json_diff_text("{\"a\":1,\"b\":2}", "{\"a\":1,\"b\":3}")
// patch == [{"op":"replace","path":"/b","value":3}]
```

### Multi-file tree diff

```mbt
import yuzhiblue/moon-diff/diff

let old_fs = [("a.txt", "1\n2\n3"), ("b.txt", "x\ny")]
let new_fs = [("a.txt", "1\n2\n3\n4"), ("c.txt", "hello")]
let patch = render_tree_patch(old_fs, new_fs, 50)
let result = apply_tree_patch(old_fs, patch)  // Ok(new tree)
```

## Command-line tool

The `src/cli` package is a runnable example. Because the Core SDK ships no filesystem package,
multi-line inputs use the escape sequences `\n` (newline) and `\t` (tab):

```bash
moon run cli -- diff "line1\nline2" "line1\nLINE2"
moon run cli -- patch "line1\nline2" "$(cat patch.txt)"     # patch text as one arg
moon run cli -- merge "base" "ours" "theirs" --ours
moon run cli -- json '{"a":1}' '{"a":2}'
moon run cli -- jsonapply '{"a":1}' '[{"op":"replace","path":"/a","value":2}]'   # apply a JSON Patch
moon run cli -- ratio "我爱北京" "我爱南京"                  # similarity in [0,1]
moon run cli -- algo "old text" "new text"                  # edit distance of all 5 algorithms
moon run cli -- selftest                                   # internal consistency checks
```

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
| `tokenize_unicode` | `fn tokenize_unicode(String) -> Array[String]` | Unicode-aware split (per-CJK-char, per-word, per-punct, whitespace runs) |
| `diff_tokens_unicode` | `fn diff_tokens_unicode(String, String) -> Array[Change[String]]` | Unicode-token diff (Chinese/Japanese/Korean friendly) |
| `word_diff_unicode` | `fn word_diff_unicode(String, String) -> String` | intra-line highlight with `[-x-]{+y+}` (Unicode-aware) |
| `word_diff_html_unicode` | `fn word_diff_html_unicode(String, String) -> (String, String)` | `<del>`/`<ins>` HTML highlighting (Unicode-aware) |
| `ratio` | `fn ratio(String, String) -> Double` | similarity in `[0,1]` (LCS of code points, like `difflib.ratio`) |
| `changes_to_string` | `fn changes_to_string(Array[Change[String]]) -> String` | reconstruct a `String` from a change list |
| `to_unified` | `fn[T: Show] to_unified(Array[Change[T]], String, String, Int) -> String` | render a unified diff (`context` = lines of context) |
| `apply_unified` | `fn apply_unified(String, String) -> String` | apply a unified diff to the old text |
| `apply_unified_fuzzy` | `fn apply_unified_fuzzy(String, String, Int, Int) -> Result[String, String]` | apply with offset/fuzz tolerance |
| `apply_unified_reverse` | `fn apply_unified_reverse(String, String) -> String` | apply a unified diff backwards (`patch -R`) |
| `reverse_unified` | `fn reverse_unified(String) -> String` | flip a patch's `+`/`-` signs |
| `git_diff_text` | `fn git_diff_text(String, String, String, String, Int) -> String` | Git-style `diff --git` / `index` headers |
| `git_blob_hash` | `fn git_blob_hash(String) -> String` | Git blob SHA-1 of a string |
| `binary_diff` | `fn binary_diff(String, String, String) -> String` | `Binary files ... differ` format |
| `sha1_hex` | `fn sha1_hex(String) -> String` | from-scratch SHA-1 (hex) |
| `word_diff` | `fn word_diff(String, String) -> String` | intra-line highlight (`[-x-]{+y+}`) |
| `word_diff_html` | `fn word_diff_html(String, String) -> (String, String)` | `<del>`/`<ins>` HTML highlighting |
| `diff_algorithm` | `fn diff_algorithm(DiffAlgorithm, Array[T], Array[T]) -> Array[Change[T]]` | dispatch to any algorithm |
| `patience_diff` | `fn patience_diff(Array[T], Array[T]) -> Array[Change[T]]` | Patience diff |
| `histogram_diff` | `fn histogram_diff(Array[T], Array[T]) -> Array[Change[T]]` | Histogram diff |
| `diff_linear` | `fn diff_linear(Array[T], Array[T]) -> Array[Change[T]]` | linear-space Hirschberg diff |
| `merge3` | `fn merge3(Array[String], Array[String], Array[String]) -> MergeResult` | 3-way merge (diff3) |
| `merge3_text` | `fn merge3_text(String, String, String) -> String` | 3-way merge returning text |
| `merge3_count` | `fn merge3_count(String, String, String) -> (String, Int)` | merge + conflict count |
| `merge3_resolve_ours` | `fn merge3_resolve_ours(MergeResult) -> Array[String]` | resolve conflicts with `ours` |
| `merge3_resolve_theirs` | `fn merge3_resolve_theirs(MergeResult) -> Array[String]` | resolve conflicts with `theirs` |
| `parse_json` | `fn parse_json(String) -> Result[Json, String]` | parse a JSON document |
| `json_equal` | `fn json_equal(Json, Json) -> Bool` | deep structural equality |
| `json_to_string` | `fn json_to_string(Json) -> String` | serialise JSON to text |
| `json_diff` | `fn json_diff(Json, Json, String) -> Array[JsonPatchOp]` | RFC 6902 diff |
| `json_patch_to_string` | `fn json_patch_to_string(Array[JsonPatchOp]) -> String` | render a JSON Patch document |
| `json_diff_text` | `fn json_diff_text(String, String) -> Result[String, String]` | JSON Patch of A → B |
| `apply_json_patch` | `fn apply_json_patch(Json, Array[JsonPatchOp]) -> Result[Json, String]` | apply an RFC 6902 patch to a `Json` value |
| `apply_json_patch_text` | `fn apply_json_patch_text(String, String) -> Result[String, String]` | apply an RFC 6902 patch (doc + patch as text) |
| `diff_trees` | `fn diff_trees(Array[(String,String)], Array[(String,String)], Int) -> TreeDiff` | diff two file trees |
| `render_tree_patch` | `fn render_tree_patch(Array[(String,String)], Array[(String,String)], Int) -> String` | Git multi-file patch |
| `apply_tree_patch` | `fn apply_tree_patch(Array[(String,String)], String) -> Result[Array[(String,String)], String]` | apply a multi-file patch |
| `tree_diff_summary` | `fn tree_diff_summary(TreeDiff) -> String` | `N files changed, ...` summary |
| `unified_to_html` | `fn unified_to_html(String, String, Int) -> String` | render a unified diff as an HTML `<table>` |
| `diff_html_page` | `fn diff_html_page(String, String, Int, String) -> String` | full HTML page (inline CSS) for a diff |

`Change[T]` is `Equal(T) | Delete(T) | Insert(T)`.

## How it works

- **`diff`** builds an LCS DP table `dp[i][j]` and backtracks it to recover `Equal` / `Delete` /
  `Insert` operations in forward order.
- **`myers_diff`** runs the classic Myers algorithm with the `V` array + trace, then backtracks
  the trace to recover a *minimal* edit script.
- **`patience_diff`** / **`histogram_diff`** pick unique/frequent anchor lines and recurse into
  the gaps for more "human" alignments.
- **`diff_linear`** (Hirschberg) splits the problem in the middle and recurses, using only
  `O(|a|+|b|)` memory regardless of input size.
- **`merge3`** decomposes each branch into base-line-aligned replacement blocks, then merges per
  region: identical → keep, one-sided change → take it, both-different → conflict markers.
- **`json_diff`** walks two JSON values and emits RFC 6902 `add`/`remove`/`replace` ops; object
  members are compared by key (order-independent), arrays positionally.
- **`to_unified`** / **`apply_unified`** walk the change list and emit / replay `@@ ... @@`
  hunks; **`sha1_hex`** (in `git.mbt`) is a from-scratch SHA-1 used for Git blob hashes.

### Complexity

| Algorithm | Time | Space |
|-----------|------|-------|
| `diff` (LCS) | `O(n·m)` | `O(n·m)` |
| `myers_diff` | `O((n+m)·D)` | `O((n+m)·D)` |
| `patience_diff` / `histogram_diff` | `O(n·m)` (amortised) | `O(n·m)` |
| `diff_linear` (Hirschberg) | `O(n·m)` | `O(n+m)` |
| `to_unified` / `apply_unified` | `O(n)` | `O(n)` |

where `n, m` are the sequence lengths and `D` is the edit distance.

## Build & test

```bash
moon build                  # build all packages (default + bench + cli)
moon test                   # run the test suite (40+ cases)
moon run cli -- selftest    # run the CLI's internal consistency checks
moon run --release src/bench  # run the benchmark harness (MoonBit side)
```

CI runs `moon build` and `moon test` on every push/PR via `.github/workflows/ci.yml`.

## Project layout

```
moon.mod.json
src/diff/
  types.mbt      # Change enum: Equal / Delete / Insert
  core.mbt       # lcs_table, diff, myers_diff, to_new / to_old, diff_lines, diff_chars, diff_tokens, tokenize, word_diff, word_diff_html, tokenize_unicode, diff_tokens_unicode, word_diff_unicode, word_diff_html_unicode, ratio, codepoints
  unified.mbt    # to_unified, apply_unified, apply_unified_fuzzy, apply_unified_reverse, reverse_unified
  git.mbt        # sha1_hex, git_blob_hash, git_diff_text, binary_diff
  merge.mbt      # merge3, merge3_text, merge3_count, resolve_ours / resolve_theirs
  algorithms.mbt # DiffAlgorithm, diff_algorithm, patience_diff, histogram_diff, diff_linear
  semantic.mbt   # JSON parser, json_equal, json_to_string, json_diff (RFC 6902), json_patch_to_string, json_diff_text, apply_json_patch / apply_json_patch_text
  dir.mbt        # diff_trees, render_tree_patch, apply_tree_patch, tree_diff_summary
  diff_test.mbt  # test blocks (run with `moon test`)
src/cli/
  main.mbt       # command-line front-end (diff / patch / merge / json / jsonapply / ratio / algo / selftest)
  moon.pkg.json
src/bench/
  bench.mbt      # benchmark harness (RESULT-line protocol)
  moon.pkg.json
docs/
  benchmark.py   # MoonBit vs Python difflib driver
  bench_results.md
  loc.py         # effective-line-of-code counter (excludes comments / blanks)
```

## Roadmap

- [x] Character/token-level diff mode (not only line-level).
- [x] Reverse apply (`patch -R`) via `apply_unified_reverse` / `reverse_unified`.
- [x] Git-style & binary diff (`git_diff_text`, `binary_diff`) + verified SHA-1.
- [x] `patch`/`git apply`-compatible heuristics (fuzz, offset) via `apply_unified_fuzzy`.
- [x] `word_diff` / `word_diff_html` for intra-line highlighting.
- [x] Five diff algorithms (LCS, Myers, Patience, Histogram, linear-space Hirschberg).
- [x] 3-way merge with conflict markers and `ours`/`theirs` resolvers.
- [x] Semantic JSON diff (RFC 6902 JSON Patch).
- [x] JSON Patch **apply** (`apply_json_patch` / `apply_json_patch_text`, add/remove/replace, arrays & objects) — closes the RFC 6902 round-trip.
- [x] Unicode-aware tokeniser (`tokenize_unicode` / `diff_tokens_unicode` / `word_diff_unicode`) — Chinese / Japanese / Korean diffs.
- [x] Similarity `ratio(a, b)` (LCS-based, like `difflib.ratio`).
- [x] Property / fuzz tests (`fuzz_test.mbt`: all 5 algorithms reconstruct; minimal-distance agreement; JSON & tree patch round-trips; Unicode tokeniser; `ratio` bounds).
- [x] Multi-file tree diff with rename detection (Git-style patch apply).
- [x] Command-line front-end / runnable example (`src/cli`).
- [ ] `moonbitlang/x/fs`-backed file I/O for the CLI (currently argument/stdin based).

## License

Apache License 2.0 — see [LICENSE](./LICENSE).

## Links

- Repository: <https://github.com/yuzhiblue/moon-diff>
- MoonBit: <https://www.moonbitlang.com/>
- mooncakes: <https://mooncakes.io/package/yuzhiblue/moon-diff>
