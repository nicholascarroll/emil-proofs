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

## Open questions

- **Returned struct.** ATC's types allow a struct passed and returned by value, but its
  generated proof failed both times: at `adjust_value-lines_delta-IN-SCOPE-26` when a
  member was written before the branches, and at `adjust_value-CORRECT-59` with that
  write removed and a guard requiring `clamped == 0`. The cause wasn't investigated.
  Shape B (locals and a single exit) also failed at an `IN-SCOPE` theorem. Whether these
  share a cause is unknown. Reproductions are in `experiments/atc-failures/`.
