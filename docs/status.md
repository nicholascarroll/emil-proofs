# Status

## Current state

- Milestone: 0 (toolchain and ATC reality check), in progress.
- Remote: `nicholascarroll/emil-proofs`, working branch `milestone-0`.
- Pins: see `scripts/versions.env`.

## Next step

Waiting for owner review of Milestone 0 (`docs/atc-reality-check.md`). Don't start
Milestone 1 until that review is done.

## Open questions for the owner

1. Accept shape A, with write-backs on unchanged paths?
2. Accept the `:alloc` gap as a recorded assumption, tested at Milestone 4?

## Effort log (for docs/verdict.md)

| Stage | Item | Time |
|---|---|---|
| M0 | `scripts/setup.sh` (fetch ACL2, build on SBCL) | 2m29s |
| M0 | First certification incl. community books (2 cores) | 25m22s |
| M0 | One ATC book after that | ~40s |
