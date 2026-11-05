# Verdict (draft: Milestone 5 not reached)

Evidence collected so far, for the final write-up.

## What ATC costs in practice

1. **Write-on-every-path requirement.** ATC's generated proof fails if a path leaves a
   pointee unwritten while another path writes it. The C needs `*px = *px;`, or a
   redesign. See `docs/atc-reality-check.md`.
2. **`:alloc` hypothesis.** ATC's theorem for pointer parameters only covers objects of
   kind `:alloc`. Emil's callers pass struct members and stack locals, so it doesn't
   literally cover any real call. Avoiding it needs a pointer-free design and a
   hand-written wrapper, with an unproven wrapper and a measured speed cost without LTO.

## What testing and spec work found so far

To be weighed against proof at Milestone 5.

- Exhaustive testing passed: 86.4 million checks in under 2 seconds. It caught all 15 real
  small-scale seeded bugs. Emil's own tests caught 13. It can't see M15 and M16, which need
  large values.
- **Found by tracing callers for claim 4, not by testing or proof:** the 10^9 bound was wrong, and
  stale window points can reach `adjustPoint`. Writing the hypotheses is what prompted the trace.
- **Stale points are wider than the first trace showed.** Reading found the revert path, but instrumenting
  emil and running its fuzzer found 636 more with no revert, and minimising them led to `killBuffer`. Testing
  corrected my reading here, and proof wouldn't have: the theorems assume valid points.
- **Emil's own fuzzer found a runaway memory failure (D4)** on a 6-key sequence, while I was auditing call sites.
  This has nothing to do with proof.
- **Found by writing the boundary table:** `adjust.h`'s return value doesn't mean "character lost",
  and no caller uses it.
- Found by my own seeding mistake: the `lines_delta == 0` branch for insertions is redundant in value.

## Open questions

- **Returned struct.** ATC's types allow a struct passed and returned by value, but its
  generated proof failed both times: at `adjust_value-lines_delta-IN-SCOPE-26` when a
  member was written before the branches, and at `adjust_value-CORRECT-59` with that
  write removed and a guard requiring `clamped == 0`. The cause wasn't investigated.
  Shape B (locals and a single exit) also failed at an `IN-SCOPE` theorem. Whether these
  share a cause is unknown. Reproductions are in `experiments/atc-failures/`.
