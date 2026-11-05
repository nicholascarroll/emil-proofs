# Claims ledger

"Tested" below means the statement was run on a small domain and, where noted, emil's C on the
Milestone 1 domain. **Nothing is proved yet.** Full statements are in `docs/m2-claims.md`.

| Claim | Formal theorem | Evidence | Assumptions | Owner review |
|---|---|---|---|---|
| Edit hypothesis at emil's call sites | Not a theorem: `docs/m2-call-sites.md` | Read at all 51 sites, no violation in about 2 million checked calls | Most sites rely on the cursor invariant or undo history | Awaiting |
| 1. Character preservation | `insert-keeps-character-before`, `insert-keeps-character-after`, `delete-keeps-character-before`, `delete-keeps-character-after` | Tested | Valid text, point and ordered edit. Model differences in `docs/m2-claims.md` | Approved |
| 2. Exact boundaries | `insert-at-point-stays-before`, `delete-at-start-stays`, `delete-inside-clamps`, `delete-at-end-clamps-but-keeps-character`, `delete-return-is-exact`, `empty-insert-changes-nothing`, `empty-delete-changes-nothing` | Tested | As above | Approved |
| 3. Validity | `insert-keeps-point-valid`, `delete-keeps-point-valid` | Tested | As above. False hypothesis for stale window points | Approved |
| 4a. No overflow in the generated functions | Guard verification with `adjust-no-overflow-p` | Exactness tested on 1,062,882 corner cases | ATC's 32-bit two's complement model. Hypothesis is the guard | Approved |
| 4b. Valid edits within emil's limits can't overflow | `insert-within-limits-cannot-overflow`, `delete-within-limits-cannot-overflow` | Tested, including at a tight small `IMAX` | Row limits before and after, enforced by `abort()` in emil, by reading | Approved |
| 4c. The predicate can be met, and a simple bound implies it | `no-overflow-predicate-is-satisfiable`, `half-range-cannot-overflow` | Tested, and a loosened hypothesis was caught | None for satisfiability. All six numbers from 0 to `IMAX/2` for the bound | Approved |
| S1. Generated functions equal the spec | To be written in Milestone 3 | None yet | Guard | Approved |
| Baseline: emil's C matches the text model | Not a theorem: `tests/m1/harness.c` | Tested on 86,376,860 cases, and 26,156,483,150 at 5x5 | That domain only | Awaiting |

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
| 2026-11-06 | "Inside a deleted region" means after the start and at or before the end: start out, end in. The header's wording is logged as emil documentation defect D1. | Claim 2 | Approved by owner |
| 2026-11-06 | Proposed: "same character" means `char-at` plus `text-from` or `text-through`, because `char-at` alone can't distinguish newlines. | Claim 1 | Awaiting owner review |
| 2026-11-06 | The 10^9 prototype bound is dropped. The guard is the exact, path-sensitive `adjust-no-overflow-p`, because emil's legal inputs exceed 10^9. Also to be proved: the predicate is satisfiable, and a simple sufficient bound as a readable corollary, which doesn't replace the guard. | Claim 4 and generated C | Approved by owner |
| 2026-11-06 | **emil does not guarantee valid points in all windows.** Reproduced by `tests/m2/stale_window.c`: after a revert to a shorter file, another window's point stays at (20,0) on a row of size 2, and later edits keep adjusting it. `tests/m2/stale_kill.c` reproduces a second path through `killBuffer`, and emil's fuzzer saw 636 stale points with no revert. Stale points are outside every claim. Milestone 4 tests that the generated C agrees with emil on them. Logged as defect D2, not fixed. | All claims | Approved by owner |
| 2026-11-06 | `adjustPoint`'s return value is unused. Logged as refactor candidate R1, not changed. | Emil | Approved by owner |
| 2026-11-06 | Supporting evidence only: parsing the generated C with C$ matches `*program*` for this output. Not proof of the printer. | `*program*` to C file step | Recorded per owner request |
| 2026-11-06 | All 15 statements and the two additions approved. Condition: Milestone 3 must also prove the generated C functions match `adjust-spec`, or report where that link stops. | Claims 1 to 4, S1 | Approved by owner |
| 2026-11-06 | Pin recheck at the start of Milestone 3: pin kept. One later commit, `aba876cf`, has reader fixes for `#f`, `#u` and `#d` and an input-clearing fix. It isn't labelled a soundness fix and touches no ATC or C model files. | Whole project | Reported to owner |
