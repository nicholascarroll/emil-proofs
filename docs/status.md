# Status

## Current state

- Milestone: 0 (toolchain and ATC reality check), in progress.
- Remote: `nicholascarroll/emil-proofs`, working branch `milestone-0`.
- Pins: see `scripts/versions.env`.

## Next step

1. Finish the clean rebuild and report it.
2. Build the pointer-free prototype and report on it (owner's three questions are in
   `docs/claims.md` decisions and the task description below).
   - Does the generated theorem have any `:alloc` or pointer hypotheses?
   - What exactly remains unproven, including the wrapper?
   - What is the effect on code shape and proof effort?
3. Milestone 1 starts only after that.

## Effort log (for docs/verdict.md)

| Stage | Item | Time |
|---|---|---|
| M0 | `scripts/setup.sh` (fetch ACL2, build on SBCL) | 2m29s |
| M0 | First certification incl. community books (2 cores) | 25m22s |
| M0 | One ATC book after that | ~40s |
