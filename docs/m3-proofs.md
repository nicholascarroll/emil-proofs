# Milestone 3: proofs and C generation

**All 17 approved statements are proved, and the generated C functions are proved to match
`adjust-spec` in ATC's C model. `adjustPoint` as emil calls it is not proved: the link stops at the
wrapper and at the step from the syntax tree to the C file.**

Everything here certifies from `scripts/certify.sh` under the strict audit: no trust tags, skipped
proofs or axioms in the include tree of any cited theorem.

## What's proved

| Book | Theorems | Include tree |
|---|---|---|
| `acl2/claims/proofs.lisp` | The 17 statements. `scripts/check-statements.py` confirms each matches its approved text | 109 books, strict |
| `acl2/c-link/functions.lisp` | Guards of the three C-shaped functions, `adjust_new_x-matches-spec`, `adjust_new_y-matches-spec`, `adjust_clamped-matches-spec`, `adjust-c-guard-is-satisfiable` | 322 books, strict |
| `three-functions-replay` (built by `certify.sh`) | ATC's generated theorems re-proved, plus `adjust_new_x-c-matches-spec`, `adjust_new_y-c-matches-spec`, `adjust_clamped-c-matches-spec` | 613 books, strict |

## How far the link goes

| Step | Status |
|---|---|
| 1. Text-model claims about `adjust-spec` | **Proved** |
| 2. C-shaped ACL2 functions equal `adjust-spec`, under the guard | **Proved** |
| 3. C syntax tree `*program*` executes as those functions, in ATC's C model | **Proved** (ATC's theorems, re-proved with no ATC or tags) |
| 4. So `*program*` matches `adjust-spec`, in ATC's C model | **Proved:** the three `-c-matches-spec` theorems |
| 5. `*program*` is printed as `adjust_scalar.c` | **Trusted.** Evidence only: parsing the file back with C$ matches `*program*`, apart from the octal tag on literal `0`, and C$ also did the printing |
| 6. A C compiler does what ATC's model says | **Trusted** |
| 7. The wrapper's pointer reads, argument order and writes | **Tested only.** The generated theorems cover the three value functions, not the hand-written wrapper |
| 8. Emil's callers meet the guard | **Not guaranteed for stale window points (D2).** For valid points, `-within-limits-cannot-overflow` proves it follows from the row limits, and those limits are enforced by `abort()` in emil, by reading |
| 9. `adjust-spec` matches emil's own `adjustPoint` | **Tested only:** Milestones 1 and 4 |

## In plain English: `adjust_new_x-c-matches-spec`

The other two have the same form.

> In any C computation state, if all seven inputs are `int` values satisfying `adjust-no-overflow-p`
> at `INT_MAX`, and the execution limit is at least the number ATC computed, then running
> `adjust_new_x` from `*program*` in ATC's C model raises no error, leaves the state unchanged, and
> returns an `int` whose value is the new column `adjust-spec` gives.

**It doesn't cover:** the C text, any compiler, or the wrapper. The execution limit is the model's
fuel, not a time bound on real hardware. It assumes `int` is 32-bit two's complement.

## What ATC's generated theorems establish

For each function, `*PROGRAM*-<fn>-CORRECT` says execution in the C model gives the ACL2 function's
result. That model checks every operation and returns an error when one is invalid, so the theorem also
means no such error occurs under the guard, including signed overflow. `*PROGRAM*-WELL-FORMED` says the
syntax tree passes ATC's model of C's static rules.

## What's trusted

| Trusted | Why it can't be removed here |
|---|---|
| Kestrel's C model | It's a formalisation of C17, not C17 itself. Its integer formats are fixed: 8-bit char, 32-bit `int`, two's complement |
| Converting and printing `*program*` to C | It runs in the tag-using session, and the printer was adopted in September 2026 |
| The C compiler and hardware | Not modelled |
| ACL2 and SBCL | Replay removes the trust tags, not these. The pin is a development snapshot after 8.7 |
| Callers meeting the guard | Nothing enforces it at run time |
| The wrapper | Hand-written. Tested in Milestone 4 |

ATC's five declared trust tags aren't in this list, because no cited theorem depends on them.

## Vacuity

**Hypotheses can be satisfied.** `no-overflow-predicate-is-satisfiable` and
`adjust-c-guard-is-satisfiable` are proved. The statement check passes each statement on concrete cases,
which shows that each statement's hypotheses hold somewhere.

**Seeded bugs break the proofs** (`scripts/seed-acl2.py`):

| ID | Seeded bug | Result | Approved statement made false | First event to fail |
|---|---|---|---|---|
| S1 | End-line column forgets the start column | caught | `delete-keeps-character-after` | proofs: `SPEC-DEL-END-LINE`; functions: `ADJUST_NEW_X-MATCHES-SPEC` |
| S2 | Later lines don't shift up after a deletion | caught | `delete-keeps-point-valid` | proofs: `SPEC-DEL-LATER`; functions: `ADJUST_NEW_Y-MATCHES-SPEC` |
| S3 | Clamped point returns 0 | caught | `delete-at-end-clamps-but-keeps-character` | proofs: `SPEC-DEL-INSIDE`; functions: `ADJUST_CLAMPED-MATCHES-SPEC` |
| S4 | Point at insertion moves with the text | caught | `insert-at-point-stays-before` | proofs: `SPEC-AT-OR-BEFORE`; functions: `ADJUST_NEW_X-MATCHES-SPEC` |
| S5 | Same-line insert adds the end column | caught | `insert-keeps-character-after` | proofs: `SPEC-INS-ON-LINE`; functions: `ADJUST_NEW_X-MATCHES-SPEC` |
| S6 | Later lines don't shift down after an insertion | caught | `insert-keeps-character-after` | proofs: `SPEC-INS-LATER`; functions: `ADJUST_NEW_Y-MATCHES-SPEC` |
| S7 | Deletion model keeps the wrong suffix | caught | `delete-at-start-stays` | proofs: `DELETE-TEXT-BASE` |
| S8 | Overflow predicate ignores the end-line sum | caught | - | functions: `|adjust_new_x|` |
| F1 | adjust_new_x: end-line column forgets the start | caught | - | functions: `ADJUST_NEW_X-MATCHES-SPEC` |
| F2 | adjust_new_y: later lines don't shift up | caught | - | functions: `ADJUST_NEW_Y-MATCHES-SPEC` |
| F3 | adjust_clamped: inside returns 0 | caught | - | functions: `ADJUST_CLAMPED-MATCHES-SPEC` |
| F4 | Guard drops the overflow predicate | caught | - | functions: `|adjust_new_x|` |

Most seeded proofs fail first at a helper lemma, which doesn't by itself show a final theorem would fail.
That's why the "statement made false" column runs the approved statements on concrete values. S8 and
F1 to F4 change things those statements don't look at, and the guard or S1 proofs catch them instead.

## Effort

| Stage | Result | Clock time |
|---|---|---|
| Statements 1 to 15 and the 2 additions | 136 theorems, 1,049 lines of ACL2 | 37 minutes |
| C-shaped functions, guard, S1 and the link | 3 book runs, 1 ATC run, 3 replay runs | 7 minutes |

These times are for me, on a problem I'd already specified and tested. They say nothing about how long a
person learning ACL2 would take, which I'd expect to be much longer.

About 45 certification runs. **No proof stalled enough to stop.** The two worst spots:

1. **Clause explosion:** the first claim hung for about 5 minutes twice when `adjust-spec` was expanded
   inside a `:use` hint. Case-by-case rules fixed it.
2. **Rule conflicts in the deletion proof:** a standard `nthcdr` rule fought mine for about 6 runs. Rewriting
   the proof around `offset` steps fixed it.

**No statement had to be changed, weakened or given a new hypothesis.** One non-claim change: `spec.lisp` gained
guards on `pos<=`, `in-int-p` and `adjust-no-overflow-p`, because a guard can only call guard-verified
functions. The logic of those definitions is unchanged.

Certification: `proofs.lisp` 38s, `functions.lisp` 11s, the ATC run 35s, its replay 25 to 31s.
`certify.sh` takes about 11 minutes when community books are built, and they take about 29 minutes on 2 cores.
