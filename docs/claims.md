# Claims ledger

No claims proposed yet (Milestone 2).

| Claim | Formal theorem | Evidence | Assumptions | Owner review |
|---|---|---|---|---|

## Decisions

| Date | Decision | Applies to | Status |
|---|---|---|---|
| 2026-11-06 | ATC books may use only trust tags the owner approved: `:quicklisp`, `:quicklisp.osicat`, `:oslib`, `:file-io!`. The owner approved a fifth, `:open-output-channel!`, but it never appears, so it was removed from the allowlist. This is an assumption behind every theorem ATC generates: tagged code runs in the prover's image and is trusted not to interfere. See `docs/atc-reality-check.md`. | Books that run ATC only. Spec and claim books stay tag-free. | Approved by owner |
| 2026-11-06 | Extra writes (shape A's `*px = *px;` on unchanged paths): accepted provisionally. Milestone 4 must check that `-O2` output and speed show no cost. | Pointer version of the generated C | Provisionally accepted by owner |
| 2026-11-06 | `:alloc` gap: not accepted yet. Prototype a pointer-free version with a thin hand-written wrapper before Milestone 1. | Generated C reached from emil's callers | Prototype in progress |
| 2026-11-06 | If the pointer-free option fails, fall back to the pointer version and record exactly: "The generated theorem does not cover calls with struct-member or stack-local pointers. For those calls, evidence is testing only." That case must not be described as proven. | Fallback only | Owner's required wording |
| 2026-11-06 | Theorem and generator are separate. ATC's generated theorems are re-proved in replay books whose whole include tree has no trust tags, skipped proofs or axioms (`scripts/atc-replay.sh`). Claims rest on the replay books. Books that run ATC are generators, and no claim may rest on them. See `docs/trust-and-pin.md`. | Every claim about generated C | Enforced by `certify.sh`. Proposed rule wording awaits owner review |
| 2026-11-06 | Trusted, not proved: converting and printing `*program*` to the C file. This step runs in the trust-tagged session, using a printer adopted in September 2026. | Every claim about generated C | Assumed |
| 2026-11-06 | Proposed: use pointer-free version F. If adopted, record: "The generated theorems cover the three value functions, not the hand-written wrapper. For the wrapper's pointer reads and writes, evidence is testing only." Don't describe `adjustPoint` itself as proven. | Generated C reached from emil's callers | Awaiting owner review |
| 2026-11-06 | ACL2 pin kept at `7ac80c83`, the newest commit available. Recheck for new soundness commits at the start of Milestone 3 and before the verdict. | Whole project | Recommended, awaiting owner review |
