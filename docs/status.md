# Status

## Current state

- **Milestone 5 done. The pilot is finished, within the owner's budget.** See `docs/verdict.md`.
- Remote: `nicholascarroll/emil-proofs`, working branch `milestone-3`.
- Pins: see `scripts/versions.env`. Generated C uses the pointer-free version.

## Next step

None planned. Don't go beyond Milestone 5. D2 and D4 are for the owner to act on.

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
