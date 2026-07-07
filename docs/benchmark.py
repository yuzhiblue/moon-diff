#!/usr/bin/env python3
# Copyright 2026 The moon-diff Authors.
# Licensed under the Apache License, Version 2.0.
#
# Benchmark driver that compares moon-diff (MoonBit) against Python's
# standard-library `difflib` on identical synthetic workloads.
#
# moon-diff's harness (src/bench/bench.mbt) does NOT measure wall-clock time
# itself (the MoonBit toolchain has no portable clock in this setup); instead
# it streams one `RESULT|<words>|<ratio>|<reps>|<checksum>` line per workload.
# This script timestamps those lines as they arrive, and runs the equivalent
# `difflib` workload in-process, so the two sides are compared apples-to-apples.
#
# Both sides use the SAME 31-bit LCG (constants 1103515245 / 12345, mask
# 0x7fffffff) and the SAME vocabulary / edit logic, so the generated corpora
# are byte-for-byte identical.

from __future__ import annotations

import re
import subprocess
import sys
import time
from difflib import SequenceMatcher
from pathlib import Path

VOCAB = [
    "alpha", "beta", "gamma", "delta", "epsilon",
    "zeta", "theta", "kappa", "lambda", "sigma",
]

MASK = 0x7FFFFFFF


def lcg(state: int) -> int:
    return (state * 1103515245 + 12345) & MASK


def gen_old(n: int, seed: int) -> list[str]:
    state = seed
    out: list[str] = []
    for _ in range(n):
        state = lcg(state)
        out.append(VOCAB[state % 10])
    return out


def gen_new(old: list[str], ratio: int, seed: int) -> list[str]:
    state = seed
    r = ratio
    out: list[str] = []
    for w in old:
        state = lcg(state)
        if (state % 1000) < r:
            state = lcg(state)
            tok = VOCAB[state % 10]
            state = lcg(state)
            is_delete = (state % 2) == 1
            if not is_delete:
                out.append(tok)
            state = lcg(state)
            if (state % 1000) < (r * 3 // 10):
                out.append(tok)
        else:
            out.append(w)
    return out


def tokenize(s: str) -> list[str]:
    # Mirrors moon-diff's `tokenize`: alternating word / whitespace runs.
    return re.findall(r"\S+|\s+", s)


# (words, edit-ratio, repetitions) -- must match src/bench/bench.mbt `main`.
WORKLOADS = [
    (500, 10, 200),
    (1500, 10, 40),
    (3000, 10, 10),
    (1500, 50, 40),
]


def run_python() -> list[tuple[str, int, int, int, float]]:
    rows = []
    for n, ratio, reps in WORKLOADS:
        old = gen_old(n, 1234567)
        new = gen_new(old, ratio, 987654321)
        old_s = " ".join(old)
        new_s = " ".join(new)
        toks_old = tokenize(old_s)
        toks_new = tokenize(new_s)
        # myers_diff  (word-level)  -- compared against difflib
        t0 = time.perf_counter()
        for _ in range(reps):
            list(SequenceMatcher(None, old, new).get_opcodes())
        rows.append(("myers", n, ratio, reps, time.perf_counter() - t0))
        # diff / LCS  (word-level)  -- compared against difflib
        t0 = time.perf_counter()
        for _ in range(reps):
            list(SequenceMatcher(None, old, new).get_opcodes())
        rows.append(("lcs", n, ratio, reps, time.perf_counter() - t0))
        # diff_tokens (token-level) -- compared against difflib on tokens
        t0 = time.perf_counter()
        for _ in range(reps):
            list(SequenceMatcher(None, toks_old, toks_new).get_opcodes())
        rows.append(("tokens", n, ratio, reps, time.perf_counter() - t0))
    return rows


def run_moonbit(repo: Path) -> list[tuple[str, int, int, int, float]]:
    # Release mode so MoonBit is optimised. The native backend would be ideal
    # but requires a system C compiler (not available in this environment), so
    # we use the optimised JS backend as the closest fair comparison to
    # CPython's C-accelerated difflib.
    proc = subprocess.Popen(
        ["moon", "run", "--release", "src/bench"],
        cwd=str(repo),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    start = time.perf_counter()
    workload_keys = {(n, r, reps) for (n, r, reps) in WORKLOADS}
    rows: list[tuple[str, int, int, int, float]] = []
    prev = 0.0
    for line in proc.stdout:
        line = line.strip()
        if not line.startswith("RESULT|"):
            continue
        # RESULT|<strategy>|<words>|<ratio>|<reps>|<checksum>
        _tag, strategy, n_s, ratio_s, reps_s, _checksum = line.split("|")
        now = time.perf_counter() - start
        delta = now - prev
        prev = now
        key = (int(n_s), int(ratio_s), int(reps_s))
        if key in workload_keys:
            rows.append((strategy, key[0], key[1], key[2], delta))
    proc.wait()
    if proc.returncode != 0:
        err = proc.stderr.read()
        raise RuntimeError(f"moon run src/bench failed:\n{err}")
    if len(rows) != len(WORKLOADS) * 3:
        raise RuntimeError(
            f"expected {len(WORKLOADS) * 3} RESULT lines, got {len(rows)}"
        )
    return rows


STRATEGY_LABEL = {
    "myers": "myers_diff (O(ND))",
    "lcs": "diff / LCS (O(NM))",
    "tokens": "diff_tokens (word-level)",
}


def fmt_strategy(strategy: str, moon_rows, py_rows) -> str:
    header = (
        f"{'workload (words@ratio%)':<26}"
        f"{'MoonBit (s)':>14}"
        f"{'Python (s)':>14}"
        f"{'speedup':>10}"
    )
    lines = [STRATEGY_LABEL[strategy], header, "-" * len(header)]
    for (_, n, ratio, reps, mt), (_, _, _, _, pt) in zip(moon_rows, py_rows):
        speedup = pt / mt if mt > 0 else float("nan")
        lines.append(
            f"{f'{n} words @ {ratio}%':<26}"
            f"{mt:>14.4f}"
            f"{pt:>14.4f}"
            f"{speedup:>9.2f}x"
        )
    return "\n".join(lines)


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    print("Running MoonBit benchmark (moon run --release src/bench) ...", flush=True)
    moon_rows = run_moonbit(repo)
    print("Running Python difflib benchmark ...", flush=True)
    py_rows = run_python()

    print()
    sections = []
    summary_lines = []
    for strategy in ("myers", "lcs", "tokens"):
        m = [r for r in moon_rows if r[0] == strategy]
        p = [r for r in py_rows if r[0] == strategy]
        sec = fmt_strategy(strategy, m, p)
        print(sec)
        print()
        sections.append(sec)
        mt = sum(r[4] for r in m)
        pt = sum(r[4] for r in p)
        summary_lines.append(
            f"- {STRATEGY_LABEL[strategy]}: MoonBit {mt:.3f}s, "
            f"Python {pt:.3f}s ({pt / mt:.2f}x)"
        )

    moon_total = sum(r[4] for r in moon_rows)
    py_total = sum(r[4] for r in py_rows)
    print(
        f"TOTAL  MoonBit: {moon_total:.3f}s   Python: {py_total:.3f}s   "
        f"speedup: {py_total / moon_total:.2f}x"
    )

    out_md = repo / "docs" / "bench_results.md"
    with out_md.open("w", encoding="utf-8") as f:
        f.write("# moon-diff vs Python `difflib` benchmark\n\n")
        f.write(
            "Identical synthetic workloads (31-bit LCG corpus, same vocabulary "
            "and edit logic). Lower is better.\n\n"
        )
        f.write("\n\n".join(sections) + "\n\n")
        f.write("**Per-strategy totals**\n\n")
        f.write("\n".join(summary_lines) + "\n\n")
        f.write(
            f"**Overall total**: MoonBit {moon_total:.3f}s, "
            f"Python {py_total:.3f}s "
            f"({py_total / moon_total:.2f}x for the full suite).\n\n"
        )
        f.write(
            "> Note: moon-diff is measured on the optimised JS backend "
            "(release mode).\n"
            "> The native backend -- which would be the production target and "
            "is typically\n"
            "> much faster -- could not be built here because no system C "
            "compiler is\n"
            "> installed. Python's `difflib.SequenceMatcher` is backed by a "
            "C extension.\n"
            "> Each repetition runs the strategy under comparison; Python has "
            "a single\n"
            "> diff engine, so `myers` and `lcs` are both compared against "
            "`difflib`.\n"
        )
    print(f"wrote {out_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
