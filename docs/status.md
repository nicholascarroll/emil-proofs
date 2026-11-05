# Status

## Current state

- Milestone: 0 (toolchain and ATC reality check), in progress.
- Remote: `nicholascarroll/emil-proofs`, working branch `milestone-0`.
- Pins: see `scripts/versions.env`.

## Next step

Waiting for owner review. Don't start Milestone 1 until these are answered.

## Open questions for the owner

1. Pointer-free version F, or the pointer version with the fallback wording?
2. Adopt the rule wording in `docs/trust-and-pin.md`?
3. Keep the ACL2 pin, rechecking at Milestone 3 and before the verdict?

Reports: `docs/atc-reality-check.md`, `docs/trust-and-pin.md`.

## Effort log (for docs/verdict.md)

| Stage | Item | Time |
|---|---|---|
| M0 | `scripts/setup.sh` (fetch ACL2, build on SBCL) | 2m29s |
| M0 | First certification incl. community books (2 cores) | 25m22s |
| M0 | One ATC book after that | ~40s |
| M0 | Clean rebuild: setup, then certify with community books (2 cores) | 129s + 29m11s |
| M0 | Certify and replay all repo books, community books already built | 11m03s |
| M0 | One replay certification | 24 to 31s |
