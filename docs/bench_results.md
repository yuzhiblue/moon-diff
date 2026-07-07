# moon-diff vs Python `difflib` benchmark

Identical synthetic workloads (31-bit LCG corpus, same vocabulary and edit logic). Lower is better.

myers_diff (O(ND))
workload (words@ratio%)      MoonBit (s)    Python (s)   speedup
----------------------------------------------------------------
500 words @ 10%                   0.0269        0.0801     2.97x
1500 words @ 10%                  0.0241        0.0470     1.95x
3000 words @ 10%                  0.0266        0.0234     0.88x
1500 words @ 50%                  0.1574        0.0470     0.30x

diff / LCS (O(NM))
workload (words@ratio%)      MoonBit (s)    Python (s)   speedup
----------------------------------------------------------------
500 words @ 10%                   1.1740        0.0798     0.07x
1500 words @ 10%                  2.1895        0.0469     0.02x
3000 words @ 10%                  2.3583        0.0233     0.01x
1500 words @ 50%                  2.2464        0.0471     0.02x

diff_tokens (word-level)
workload (words@ratio%)      MoonBit (s)    Python (s)   speedup
----------------------------------------------------------------
500 words @ 10%                   3.9637        0.1533     0.04x
1500 words @ 10%                  7.8715        0.0917     0.01x
3000 words @ 10%                  7.7746        0.0462     0.01x
1500 words @ 50%                  7.7416        0.0913     0.01x

**Per-strategy totals**

- myers_diff (O(ND)): MoonBit 0.235s, Python 0.198s (0.84x)
- diff / LCS (O(NM)): MoonBit 7.968s, Python 0.197s (0.02x)
- diff_tokens (word-level): MoonBit 27.351s, Python 0.382s (0.01x)

**Overall total**: MoonBit 35.555s, Python 0.777s (0.02x for the full suite).

> Note: moon-diff is measured on the optimised JS backend (release mode).
> The native backend -- which would be the production target and is typically
> much faster -- could not be built here because no system C compiler is
> installed. Python's `difflib.SequenceMatcher` is backed by a C extension.
> Each repetition runs the strategy under comparison; Python has a single
> diff engine, so `myers` and `lcs` are both compared against `difflib`.
