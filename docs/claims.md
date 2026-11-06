# Claims ledger

**"Proved" means certified with no trust tags, skipped proofs or axioms in the include tree. It is always about the
stated hypotheses and the model.** The theorems are in `acl2/claims/proofs.lisp`, `acl2/c-link/functions.lisp` and the
replay book. Full statements are in `docs/m2-claims.md`, and what each reaches is in `docs/m3-proofs.md`.

"The generated theorems cover the three value functions, not the hand-written wrapper. For the wrapper's pointer reads
and writes, evidence is testing only." **`adjustPoint` itself isn't proven.**

| Claim | Formal theorem | Evidence | Assumptions | Owner review |
|---|---|---|---|---|
| Edit hypothesis at emil's call sites | Not a theorem: `docs/m2-call-sites.md` | Read at all 51 sites, no violation in about 2 million checked calls | Most sites rely on the cursor invariant or undo history | Awaiting |
| 1. Character preservation | `insert-keeps-character-before`, `insert-keeps-character-after`, `delete-keeps-character-before`, `delete-keeps-character-after` | **Proved** | Valid text, point and ordered edit. Model differences in `docs/m2-claims.md` | Approved |
| 2. Exact boundaries | `insert-at-point-stays-before`, `delete-at-start-stays`, `delete-inside-clamps`, `delete-at-end-clamps-but-keeps-character`, `delete-return-is-exact`, `empty-insert-changes-nothing`, `empty-delete-changes-nothing` | **Proved** | As above | Approved |
| 3. Validity | `insert-keeps-point-valid`, `delete-keeps-point-valid` | **Proved** | As above. False hypothesis for stale window points | Approved |
| 4a. No overflow in the generated functions | Guard verification of `adjust_new_x`, `adjust_new_y`, `adjust_clamped` with `adjust-no-overflow-p` | **Proved** that it's sufficient. That it's also necessary is tested on 1,062,882 corner cases | ATC's 32-bit two's complement model. Hypothesis is the guard | Approved |
| 4b. Valid edits within emil's limits can't overflow | `insert-within-limits-cannot-overflow`, `delete-within-limits-cannot-overflow` | **Proved**, for every `IMAX` | Row limits before and after, enforced by `abort()` in emil, by reading | Approved |
| 4c. The predicate can be met, and a simple bound implies it | `no-overflow-predicate-is-satisfiable`, `half-range-cannot-overflow` | **Proved** | None for satisfiability. All six numbers from 0 to `IMAX/2` for the bound | Approved |
| S1. Generated functions match the spec | `adjust_new_x-matches-spec` and likewise for `y` and `clamped`; `adjust_new_x-c-matches-spec` and likewise | **Proved** in ATC's C model, for `*program*` | Guard. C model. Not the C text, compiler or wrapper | Approved |
| Generated C and wrapper agree with emil's C | Not a theorem: `docs/m4-comparison.md` | Tested: 0 differences on about 400 million cases | Those cases only | Not required |
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
| 2026-11-06 | "Same character" means `char-at` plus `text-from` or `text-through`, because `char-at` alone can't distinguish newlines. | Claim 1 | Approved by owner with the statements |
| 2026-11-06 | The 10^9 prototype bound is dropped. The guard is the exact, path-sensitive `adjust-no-overflow-p`, because emil's legal inputs exceed 10^9. Also to be proved: the predicate is satisfiable, and a simple sufficient bound as a readable corollary, which doesn't replace the guard. | Claim 4 and generated C | Approved by owner |
| 2026-11-06 | **emil does not guarantee valid points in all windows.** Reproduced by `tests/m2/stale_window.c`: after a revert to a shorter file, another window's point stays at (20,0) on a row of size 2, and later edits keep adjusting it. `tests/m2/stale_kill.c` reproduces a second path through `killBuffer`, and emil's fuzzer saw 636 stale points with no revert. Stale points are outside every claim. Milestone 4 tests that the generated C agrees with emil on them. Logged as defect D2, not fixed. | All claims | Approved by owner |
| 2026-11-06 | `adjustPoint`'s return value is unused. Logged as refactor candidate R1, not changed. | Emil | Approved by owner |
| 2026-11-06 | Supporting evidence only: parsing the generated C with C$ matches `*program*` for this output. Not proof of the printer. | `*program*` to C file step | Recorded per owner request |
| 2026-11-06 | All 15 statements and the two additions approved. Condition: Milestone 3 must also prove the generated C functions match `adjust-spec`, or report where that link stops. | Claims 1 to 4, S1 | Approved by owner |
| 2026-11-06 | Pin recheck at the start of Milestone 3: pin kept. One later commit, `aba876cf`, has reader fixes for `#f`, `#u` and `#d` and an input-clearing fix. It isn't labelled a soundness fix and touches no ATC or C model files. | Whole project | Reported to owner |
| 2026-11-06 | Spec change with no change in logic: guards added to `pos<=`, `in-int-p` and `adjust-no-overflow-p`, because a guard can only call guard-verified functions. | Spec | Reported to owner |
| 2026-11-06 | Pin recheck before the verdict: pin kept. Still only `aba876cf` after the pin, with no soundness commits. | Whole project | Reported to owner |

## Undo model (second study)

Statements in `docs/undo-statements.md`, formal text in `acl2/undo/statements.lisp`. One page: `docs/undo-report.md`.
**Assumption 2 is currently false in U2 and U3 on `main`.** They're fixed on the patched branch, as tested, not proved.

| Claim | Formal name | Evidence | Assumptions | Owner review |
|---|---|---|---|---|
| R. History matches text | `claim-r-holds` (`history.lisp`) | **Proved** on the model | 2 to 7 in the statements doc | Approved |
| A. Undo all restores the original | `claim-a-holds` (`history.lisp`) | **Proved** on the model | Same | Approved |
| B. Redo after undo restores the text | `claim-b-holds` (`redo.lisp`) | **Proved** on the model | Same | Approved |
| C. Coalesced undo equals separate undos | `claim-c-holds` (`coalesce.lisp`) | **Proved** on the model | Same, plus the definition of a run | Approved |
| The model behaves as emil's C | None | Tested: differential, 3.1M steps | Generator's reach | n/a |
| Text changes only through the history | None | **Assumed. False in U2 and U3 on `main`;** tested on the branch | | Accepted by owner |
| Every buffer holds valid UTF-8 (README) | None | **Tested, with known exceptions on `main` and `18d417c`:** bad buffer name in the minibuffer, `*Tags*`. No write held invalid bytes in 3,105 logged writes. Not a proof assumption | | **For owner** |
| At least one row, no newline byte in a row | None | **Assumed, and on `main` still false:** register views and `*Completions*`. **On the branch (`18d417c`) no known exception.** Both fixed; `EMIL_DEBUG_ROW_BYTES` aborts on any newline entering a row in sanitize and fuzz builds, and didn't trip outside one test fixture. Tested, not proved. Not checked in normal builds | | **For owner** |

Spec decisions: invalid range refused; buffers with no rows out of scope; a run's first edit doesn't fold into an earlier record.
Known limitation: a record that doesn't match the text makes undo refuse and stay stuck at it until the history is cleared.
