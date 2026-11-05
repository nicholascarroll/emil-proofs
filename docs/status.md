# Status

## Current state

- Milestone: 0 (toolchain and ATC reality check), in progress.
- Remote: `nicholascarroll/emil-proofs`, working branch `milestone-0`.
- Pins: see `scripts/versions.env`.

## Next step

1. Finish certifying `acl2/trivial` and `acl2/atc-proto` with `scripts/certify.sh`.
2. Compile and smoke-test the generated C.
3. Write `docs/atc-reality-check.md`, run setup from clean, report, and stop for
   owner review.

## Open questions for the owner

1. ATC itself requires trust tags, which collides with the no-trust-tags rule.
   See `docs/atc-reality-check.md` once written.

## Effort log (for docs/verdict.md)

| Stage | Item | Time |
|---|---|---|
| M0 | `scripts/setup.sh` (fetch ACL2, build on SBCL) | 2m29s |
