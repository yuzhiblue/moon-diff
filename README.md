# moon-diff

A text **diff & patch** library for [MoonBit](https://www.moonbitlang.com/), written for the
*MoonBit 国产基础软件生态开源大赛 (MGPIC 2026)*.

It provides:

- **`diff`** — longest-common-subsequence based difference between two sequences.
- **`myers_diff`** — Myers' O(ND) difference algorithm (minimal edit script).
- **`to_unified`** — render a change list as a GNU `diff -u` style unified diff.
- **`apply_unified`** — apply a unified diff back to the original text.
- Helpers `to_new` / `to_old` to reconstruct either side from a change list.

Works on any element type with `Eq` (and `Show` for unified rendering), so it can diff
lines, tokens, AST nodes, or any `Array[T]`.

## Install

```bash
moon add <your-username>/moon-diff
```

> The module name in `moon.mod.json` is currently `moonuser/moon-diff` as a placeholder.
> Rename it to `<your-github-username>/moon-diff` before publishing to MoonCakes.

## Usage

```mbt
// Diff two line sequences
let a = ["apple", "banana", "cherry"]
let b = ["apple", "blueberry", "cherry"]
let changes = diff(a, b)
// changes = [Equal("apple"), Delete("banana"), Insert("blueberry"), Equal("cherry")]

// Reconstruct either side
to_new(changes)  // ["apple", "blueberry", "cherry"]
to_old(changes)  // ["apple", "banana", "cherry"]

// Line-by-line diff of two strings
let patch = to_unified(diff_lines(old_text, new_text), "old.txt", "new.txt", 3)
println(patch)

// Apply a unified diff
let new_text = apply_unified(old_text, patch)
```

### API

| Function | Signature | Description |
|----------|-----------|-------------|
| `diff` | `fn[T: Eq] diff(Array[T], Array[T]) -> Array[Change[T]]` | LCS-based difference |
| `myers_diff` | `fn[T: Eq] myers_diff(Array[T], Array[T]) -> Array[Change[T]]` | Myers O(ND) difference |
| `to_new` | `fn[T] to_new(Array[Change[T]]) -> Array[T]` | reconstruct the new sequence |
| `to_old` | `fn[T] to_old(Array[Change[T]]) -> Array[T]` | reconstruct the old sequence |
| `diff_lines` | `fn diff_lines(String, String) -> Array[Change[String]]` | diff two texts by lines |
| `to_unified` | `fn[T: Show] to_unified(Array[Change[T]], String, String, Int) -> String` | render unified diff |
| `apply_unified` | `fn apply_unified(String, String) -> String` | apply a unified diff |

`Change[T]` is `Equal(T) | Delete(T) | Insert(T)`.

## Build & Test

```bash
moon build --target wasm
moon test
```

## Project layout

```
moon.mod.json
src/diff/
  types.mbt      # Change enum
  core.mbt       # lcs_table, diff, myers_diff, to_new/to_old, diff_lines
  unified.mbt    # to_unified, apply_unified
  diff_test.mbt  # test blocks (run with `moon test`)
```

## License

Apache License 2.0 — see [LICENSE](./LICENSE).
