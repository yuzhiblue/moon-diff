#!/usr/bin/env python3
# Counts "effective" MoonBit lines of code for the OSC2026 submission.
# Effective LOC = physical lines minus blank lines and `//` comment lines
# (including copyright headers). Matches the official "effective MoonBit code"
# definition used by the contest rubric.
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def effective_loc(path):
    total = 0
    code = 0
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            total += 1
            stripped = line.strip()
            if stripped == "":
                continue
            if stripped.startswith("//"):
                continue
            code += 1
    return total, code


def main():
    files = sorted(glob.glob(os.path.join(ROOT, "src", "**", "*.mbt"),
                             recursive=True))
    if not files:
        print("no .mbt files found under src/")
        sys.exit(1)
    grand_total = 0
    grand_code = 0
    print(f"{'file':55} {'phys':>6} {'eff':>6}")
    print("-" * 70)
    for fp in files:
        rel = os.path.relpath(fp, ROOT)
        t, c = effective_loc(fp)
        grand_total += t
        grand_code += c
        print(f"{rel:55} {t:6} {c:6}")
    print("-" * 70)
    print(f"{'TOTAL':55} {grand_total:6} {grand_code:6}")
    # split core lib vs cli vs test vs bench
    core = bench = test = cli = 0
    for fp in files:
        rel = os.path.relpath(fp, ROOT)
        _, c = effective_loc(fp)
        if "diff_test" in rel:
            test += c
        elif "/bench/" in rel:
            bench += c
        elif "/cli/" in rel:
            cli += c
        else:
            core += c
    print()
    print(f"core lib (src/diff):        {core}")
    print(f"tests (diff_test.mbt):      {test}")
    print(f"benchmark (src/bench):      {bench}")
    print(f"cli (src/cli):              {cli}")
    print(f"---")
    print(f"effective total:            {grand_code}")


if __name__ == "__main__":
    main()
