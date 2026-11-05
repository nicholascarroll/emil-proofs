# Claims ledger

No claims proposed yet (Milestone 2).

| Claim | Formal theorem | Evidence | Assumptions | Owner review |
|---|---|---|---|---|

## Decisions

| Date | Decision | Applies to | Status |
|---|---|---|---|
| 2026-11-06 | ATC books may use only trust tags the owner approved: `:quicklisp`, `:quicklisp.osicat`, `:oslib`, `:file-io!`. The owner approved a fifth, `:open-output-channel!`, but it never appears, so it was removed from the allowlist. This is an assumption behind every theorem ATC generates: tagged code runs in the prover's image and is trusted not to interfere. See `docs/atc-reality-check.md`. | Books that run ATC only. Spec and claim books stay tag-free. | Approved by owner |
| 2026-11-06 | Extra writes (shape A's `*px = *px;` on unchanged paths): provisionally accepted, then superseded by the pointer-free version, which has none. | Pointer version only | Superseded |
| 2026-11-06 | `:alloc` gap: not accepted. The pointer-free version avoids it in the generated theorems. | Generated C reached from emil's callers | Resolved by owner's choice of version F |
| 2026-11-06 | Not triggered, because the option worked. If the pointer-free option fails, fall back to the pointer version and record exactly: "The generated theorem does not cover calls with struct-member or stack-local pointers. For those calls, evidence is testing only." That case must not be described as proven. | Fallback only | Owner's required wording |
| 2026-11-06 | Theorem and generator are separate. ATC's generated theorems are re-proved in replay books whose whole include tree has no trust tags, skipped proofs or axioms (`scripts/atc-replay.sh`). Claims rest on the replay books. Books that run ATC are generators, and no claim may rest on them. See `docs/trust-and-pin.md`. | Every claim about generated C | Enforced by `certify.sh`. Rule wording approved by owner |
| 2026-11-06 | Trusted, not proved: converting and printing `*program*` to the C file. This step runs in the trust-tagged session, using a printer adopted in September 2026. | Every claim about generated C | Assumed |
| 2026-11-06 | Pointer-free version F is used from Milestone 1 onward. "The generated theorems cover the three value functions, not the hand-written wrapper. For the wrapper's pointer reads and writes, evidence is testing only." Don't describe `adjustPoint` itself as proven. Emil's build is not changed for speed. | Generated C reached from emil's callers | Approved by owner |
| 2026-11-06 | ACL2 pin kept at `7ac80c83`, the newest commit available. Recheck for new soundness commits at the start of Milestone 3 and before the verdict. If any exist, tell the owner what they touch before moving the pin. | Whole project | Approved by owner |
