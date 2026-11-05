# Milestone 1: testing baseline

Subject: emil `ac98ba0b`, `adjust.c` compiled unmodified. Run with `scripts/run-m1.sh`.
Harness: `tests/m1/harness.c`.

## Result

On every case in the domain below, emil's `adjustPoint` gave the position and return
value the model expects, and the new point was valid in the edited text. **86,376,860
checks, 0 failures.** That statement covers this domain only.

## Domain

| Bound | Value |
|---|---|
| Text | Every shape of 1 to 4 lines of 0 to 4 characters (780 texts) |
| Point | Every valid position in the text |
| Insertion | Every valid position, with every inserted text of 1 to 4 lines of 0 to 4 characters |
| Deletion | Every valid pair of positions, start before or equal to end |
| `is_delete` | 0 for insertion. 1, 2, -1 and `INT_MIN` for deletion |

Time: 1.9s at `-O2`. Also clean under ASan and UBSan with gcc (7.0s) and clang (3.7s).
A larger run at **5 lines of 5 characters** did 26,156,483,150 checks with 0 failures in
7m31s.

## How the oracle works

The oracle doesn't reuse `adjustPoint`'s arithmetic. Every character, newline and the end
of text gets a unique id. The model performs the edit on lists of lines, then finds where
each id ended up:

- **The point's character survived:** the expected position is wherever that id now is.
- **Point exactly at an insertion:** `adjust.h` says it stays, so the expected position is
  the insertion start.
- **The point's character was deleted:** `adjust.h` says it clamps, so the expected
  position is the deletion start.
- **Return value:** 1 when the point is after the deletion's start and at or before its
  end, otherwise 0.

Every case was reached, so the pass isn't vacuous:

| Case | Checks | | Case | Checks |
|---|---:|---|---|---:|
| Insert: before | 38,274,600 | | Delete: before | 913,340 |
| Insert: exactly at | 6,847,410 | | Delete: at start | 196,280 |
| Insert: at, empty text | 8,790 | | Delete: at start, empty deletion | 35,160 |
| Insert: after, same line, no newline | 58,600 | | Delete: inside | 717,060 |
| Insert: after, same line, multi-line text | 9,083,000 | | Delete: at end | 196,280 |
| Insert: later line | 29,133,000 | | Delete: after, on end line | 281,240 |
| | | | Delete: later line | 632,100 |

Delete counts include the re-runs with the other `is_delete` values.

## Seeded bugs

18 changes to a copy of the function. 15 are real bugs at this scale, and the harness
caught all 15. Emil's `tests/test_adjust.c` caught 13 of them.

SEEDED_TABLE

- **M08 isn't a bug. It was my mistake.** `endx + (*px - startx)` and `*px + (endx - startx)`
  are the same arithmetic, so nothing can catch it. See "Unexpected" below.
- **M15 and M16 show the limit of small-scope testing.** They're wrong only at 128+ lines or
  past column 32767, so no test at this scale can see them. Milestone 4's random large values
  are meant to catch this kind of bug, but they haven't run yet.
- **M18 and M19 are where exhaustive testing beat emil's tests.** Emil's tests have no point
  on the start line of a multi-line deletion, or just past the end of one.

## Against `tests/test_adjust.c` and `adjust.h`

`test_adjust.c` compiled unchanged in a scratch copy: **30 tests, 0 failures**. 17 call
`adjustPoint` directly, and the other 13 exercise the surrounding edit, mark and window code.

| `adjust.h` says | Tested result |
|---|---|
| A point exactly at an insertion stays there, before the new text | Holds |
| A point after it moves with the text after it | Holds |
| Returns 1 if the point was inside a deleted region, now clamped to the start | Holds, but "inside" isn't defined (see 2 below) |
| Returns 0 otherwise | Holds |

## Unexpected

1. **The return value doesn't mean "the character was lost".** A point at the deletion's
   start loses its character and returns 0. A point at its end keeps its character and
   returns 1. `adjust.h` doesn't say either, though `test_adjust.c` pins both.
2. **No caller uses the return value.** All of emil's calls discard it, so a bug like M14
   would have no effect today.
3. **The `lines_delta == 0` branch for insertions is redundant in value.** Both branches
   compute the same column (M08). They differ only in their intermediate value, which matters
   only for overflow. This is an observation, and I'm not suggesting a change to emil.
4. **`adjustPoint` can receive a point that isn't valid in the current text.** This fell
   outside this domain, which only has valid points. It came from tracing callers, so it's in
   `docs/m2-claims.md`.
