# Status

## Current state

- Pilot finished: `docs/verdict.md`, branch `milestone-3`.
- **Undo study finished, branch `undo-model`.** One page: `docs/undo-report.md`. Stages: `docs/undo-stage1.md`, `docs/undo-stage2.md`, `docs/undo-statements.md`.
- Emil refactor: `patches/undo-refactor/`, 11 commits on `ac98ba0b`. The owner applies them; Claude has no push rights to emil.

## Next step

None planned. Owner decides on the newline-in-row case.

## Reports

`docs/verdict.md`, `docs/m4-comparison.md`, `docs/m3-proofs.md`, `docs/m2-claims.md`, `docs/m2-call-sites.md`,
`docs/emil-defects.md`, `docs/m1-testing.md`, `docs/atc-reality-check.md`, `docs/trust-and-pin.md`.

## Effort log (for docs/verdict.md)

| Stage | Item | Time |
|---|---|---|
| M0 | `scripts/setup.sh` (fetch ACL2, build on SBCL) | 2m29s |
| M0 | First certification incl. community books (2 cores) | 25m22s |
| M0 | One ATC book after that | ~40s |
| M0 | Clean rebuild: setup, then certify with community books (2 cores) | 129s + 29m11s |
| M0 | Certify and replay all repo books, community books already built | 11m03s |
| M0 | One replay certification | 24 to 31s |
| M0 | C$ round trip, including 219 more community books | About 29m certification, 3 runs |
| M1 | Exhaustive harness, 4x4 | 1.9s per run |
| M1 | Exhaustive harness, 5x5 | 7m31s |
| M2 | Corner-case overflow check, per function | About 3m25s |
| M2 | Statement check on the small domain | Under 1s |
| M2 | Full `certify.sh` with all 17 statements, community books already built | 10m45s |
| M2 | Emil's suite and 3,000 fuzz seeds, instrumented | 49s and 200s |
| M3 | 17 statements proved | 37m, about 38 cert runs |
| M3 | C functions to spec | 7m |
| M3 | Seeded bugs | 5m53s |
| M4 | Full comparison | 49s |
| Undo | Differential, all classes | About 2m |
| Undo | R, A, B, C proved | About 30m, about 45 certification runs, no stall |
| Undo | Full `certify.sh` including `acl2/undo` | 10m52s |
| Undo | Refcheck | 13m |
