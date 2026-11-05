# Milestone 4: the generated C meets emil

Generated `adjust_scalar.c` and hand-written `adjust_wrapper.c`, against emil `ac98ba0b`'s
`adjustPoint`. Run with `scripts/run-m4.sh`.

**No behavioural differences found on any case tested. The generated version is slower and larger.**
These are test results, not proofs, except where a theorem is named.

## Behaviour

All with ASan and UBSan, and no sanitizer reports.

| Test | Cases compared | Differences |
|---|---|---|
| Exhaustive differential on the Milestone 1 domain, gcc | 86,376,860 | 0 |
| The same, clang | 86,376,860 | 0 |
| Random across the whole `int` range, within the guard | 67,699,423 | 0 |
| Random, ordered and non-negative, within the guard | 84,374,983 | 0 |
| Near `INT_MAX`, 128, 32768 and 2^30, within the guard | 72,372,676 | 0 |
| Small grid with no validity filter, -2 to 7 in all six numbers | 2,000,000 | 0 |
| Reproduced stale and sentinel points against small edits | 140,000 | 0 |

**Stale points:** your decision was to test agreement here. They agree on all cases tested. The theorems still
don't cover them unless the guard holds, and validity doesn't hold.

**The large-value test works:** M15 and M16, the two seeded bugs no small-scope test could see, are both caught,
at a much smaller sample (2 million per phase). So those two were never a reason to need proof.

## Warnings

| | gcc 13.3 | clang 18.1 |
|---|---|---|
| Generated C | 8 `-Wparentheses` | 8 `-Wlogical-op-parentheses` |
| Wrapper | 0 | 0 |

Emil's `DEFAULT_CFLAGS` include `-Wall` but not `-Werror`, so its build still works, with 8 new warnings.

## Size and speed at `-O2`

Separate object files, as emil builds them. Five runs each on an idle machine, 200 million calls per run.
Figures are from the final run. An earlier run was up to about 15% slower, with similar ratios.

| | Emil | Generated + wrapper | Ratio |
|---|---|---|---|
| gcc `.text` bytes | 236 | 657 (376 + 281) | 2.8x |
| clang `.text` bytes | 168 | 561 (327 + 234) | 3.3x |
| gcc ns per call | 6.2 to 6.7 | 10.5 to 11.3 | About 1.7x |
| clang ns per call | 6.4 to 6.6 | 16.1 to 16.5 | About 2.5x |
| gcc with `-flto`, for reference | | 5.2 to 5.5 | About 0.8x |
| clang with `-flto`, for reference | | 7.8 to 8.1 | About 1.2x |

The cost is from three calls that each repeat the branch tests. `-flto` removes it, but you've ruled out changing
emil's build for speed. In absolute terms it's 5 to 10 ns per point. One edit adjusts a handful of points, so I
don't expect it to be noticeable, but I haven't measured a real editing session.

## What swapping it into emil would need

I tried this in a scratch copy only. **Emil is unchanged, and I'm not proposing this swap.**

1. Add `adjust_scalar.c` and `adjust_scalar.h`, generated, and include them in the build: `OBJS` and `HEADERS` in
   the `Makefile`, and `TEST_OBJECTS` in `tests/run_tests.sh`.
2. Replace the body of `adjustPoint` in `adjust.c` with the wrapper. `adjust.h` doesn't change.
3. Accept 8 new compiler warnings, or suppress them for that file.
4. Decide how the files stay in step: either run ACL2 and ATC in emil's build, or commit generated files and accept
   that hand edits would break the link to the proofs.
5. Accept the size and speed above without `-flto`.

**Result in the scratch copy:** it builds, and `tests/run_tests.sh` reports `ALL PASSED`, including `test_adjust`. I
didn't run the fuzzer on it.

The swap wouldn't make `adjustPoint` proven: the wrapper stays hand-written and stale points still fall outside the guard.
