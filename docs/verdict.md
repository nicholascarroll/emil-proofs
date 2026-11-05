# Verdict

## Emil defects for you to act on

Neither is fixed or investigated further in this branch. Details are in `docs/emil-defects.md`. Subject: emil `ac98ba0b`.

### D2: emil doesn't guarantee valid points in all windows

After `revert` or `killBuffer`, another window keeps a cursor that may not exist in the buffer it now shows, until it next gets
focus. Edits keep adjusting that point. Effect found: a stale line number in that window's status line. Across 2,999 fuzz seeds,
636 stale points reached `adjustPoint` at deletions, in 70 runs, none involving a revert. Other paths are likely: `showPopupBuffer`
looks like one, from reading only.

**Reproduce:** `scripts/run-m1.sh` builds and runs both of these against a scratch copy of emil:

- `tests/m2/stale_window.c` (revert): other window at (20,0) on a row of size 2.
- `tests/m2/stale_kill.c` (killBuffer): other window at (20,8) in a 3-row buffer.

### D4: runaway memory on a short key sequence

On unmodified emil, seed 1127 of its own fuzzer grew by about 1 GB per second until the process was killed, with no sanitizer report.
It minimises to 6 keys: `C-M-r M-9 2 C-u M-4 ^`. The cause isn't known, and I've only run it in the fuzzer's harness, not a real terminal.

**Reproduce:** as an unprivileged user, `FUZZ_WORK=<dir> sh tests/fuzz_keys.sh 1127 1` in a copy of emil.

Smaller items, also logged: D1 (`adjust.h`'s wording about "inside"), D3 (`insertChar` adjusts with a column `rowInsertChar` may have
clamped, no effect found), and R1 (`adjustPoint`'s return value is unused).

## The answer

**For this class of function, proof wasn't worth it, and small-scope exhaustive testing plus large random values is enough.** The proofs
went through and found nothing wrong with `adjustPoint`. What found problems was writing the claims down precisely, tracing whether their
hypotheses hold, and running emil's fuzzer.

ATC's generated C matches the spec in its model, but I wouldn't swap it in: it's about 1.7 to 2.5 times slower per call without `-flto`, about
3 times larger, and adds 8 warnings. And `adjustPoint` itself still wouldn't be proven.

This is one small, pure function of integer arithmetic, already well tested. It says little about harder code.

## What's established

| Claim | Status |
|---|---|
| Character preservation, boundaries and validity, for `adjust-spec` on the text model, for valid points and edits | **Proved** |
| Within emil's row limits, a valid point and edit can't overflow | **Proved,** with the limits as a hypothesis |
| Generated `*program*` matches `adjust-spec` in ATC's C model, under `adjust-no-overflow-p` | **Proved** |
| The guard's exactness: overflow happens whenever it's false | Tested on 1,062,882 corners. Proved only in the other direction |
| Emil's C matches the text model | Tested: 86.4 million cases, and 26.2 billion at 5x5 |
| Generated C and wrapper match emil's C | Tested: 0 differences in about 400 million comparisons |
| The wrapper | **Tested only** |
| `*program*` to C text | **Trusted,** with one round-trip check of this output |
| `adjustPoint` as emil calls it | **Not proved** |

## What did the proof or spec work reveal that the exhaustive test didn't?

**The proofs themselves: no bug, no surprise, and no statement needed changing.** Their real addition is reach: the claims hold for all sizes and all contents, not
just tested ones. In this function, that reach didn't find anything.

**The spec work found the following, none of which the exhaustive test could:**

| Finding | What found it |
|---|---|
| The 10^9 bound was false for legal input | Tracing callers for claim 4 |
| `adjustPoint` can receive invalid points (D2) | Tracing callers, then **testing**: the fuzzer corrected my reading by finding it wasn't mainly revert |
| The exact overflow condition depends on the path | Writing claim 4 |
| `adjust.h`'s return value doesn't mean "character lost" (D1) | Writing the boundary table |
| The return value is unused (R1) | Writing the claims and searching callers |
| Most call sites rely on an invariant, not a local check | Your request to audit the hypothesis |

D4 came from running emil's fuzzer during that audit, and has nothing to do with proof. The `lines_delta == 0` branch for insertions being redundant came from my own seeding mistake.

The exhaustive harness did find something the existing tests missed: M18 and M19, seeded bugs `test_adjust.c` doesn't catch. M15 and M16, which small-scope testing can't see, were caught by random large values, not proof.

## Was any of this close to trivial?

| Part | How it went |
|---|---|
| Installing and certifying | Trivial, but slow: 29 minutes of community books |
| C-shaped functions to spec, guard verification, link | Close to trivial: 7 minutes |
| Sufficient bound, satisfiability, return value, empty edits | Close to trivial |
| Claims about insertion | Moderate, mostly list and offset reasoning |
| Claims about deletion | The hardest, but no real stall |
| **Getting ATC to accept the function's shape** | **The most troublesome part, for what it gave.** See below |

## Effort

| Stage | Clock time |
|---|---|
| M0, including the prototype and rule questions | About 2h10m |
| M1 and M2, including the call-site audit and two review rounds | About 1h45m |
| M3: 17 statements | 37m |
| M3: link to C | 7m |
| M3: seeded bugs | 6m |
| M4 | Under 10m |

Much of the early time was waiting for certification and for review. These are my times, on a function I'd already specified and tested. **A person learning ACL2 would take far longer, and I have no measurement of that.**

About 45 certification runs for M3. The proofs took 136 theorems and 1,049 lines of ACL2 for a 54-line C function. Two stalls, neither stopping the work: a clause explosion that hung twice, and a rule conflict in the deletion proof that took about 6 runs. Certification: 38s for the proofs, 11s for the C link, about 30s for each ATC run or replay, about 11 minutes for the whole script, and about 29 minutes of community books from clean, on 2 cores.

## How readable and usable is the generated C?

**Usable, but not code I'd want a person to maintain.** It's standard C99 that compiles with only 8 parenthesis warnings. Its `else` nesting is deeper than emil's, it has no comments (ATC can't emit them), and the pointer-free form repeats the same branch tests in three functions: 76 generated lines plus a wrapper, against 54 in emil. It's best treated as build output, which then needs ACL2 in the workflow or generated files checked in.

## What ATC costs in practice

1. **Write-on-every-path requirement.** ATC's generated proof fails if a path leaves a pointee unwritten while another path writes it. The C needs `*px = *px;` or a redesign. The minimal reproduction is in `experiments/atc-failures/`.
2. **`:alloc` hypothesis.** ATC's theorem for pointer parameters only covers objects of kind `:alloc`. Emil's callers pass struct members and stack locals, so it doesn't literally cover any real call. Avoiding it took the pointer-free design, with an unproven hand-written wrapper and the speed and size cost above.
3. **Trust tags in the tool.** ATC needs them to run. They turned out not to be part of the theorems, but showing that took a replay script that's now part of the build.

## Open questions

- **Returned struct.** ATC's types allow a struct passed and returned by value, but its generated proof failed both times: at `adjust_value-lines_delta-IN-SCOPE-26` with a member written before the branches, and at `adjust_value-CORRECT-59` with that write removed and a guard requiring `clamped == 0`. The cause wasn't investigated. The locals-and-single-exit shape also failed at an `IN-SCOPE` theorem, and whether these share a cause is unknown. Reproductions are in `experiments/atc-failures/`.
- **The guard's other direction.** It's proved that the guard is enough. That nothing weaker would be is tested, not proved.
- **Other stale-point paths.** I haven't shown the known paths explain all 636.

## Would a claim about arbitrary sequences of edits and undos be a better next target?

**Yes, a better target, but I'd start it with model-based testing, not proof. I haven't started it.**

- **That's where the problems are.** Every issue found here is about state across operations: stale windows, cursors carried over, undo records assuming the text matches. `adjustPoint` itself had none.
- **Exhaustive testing runs out there.** Sequences grow exponentially, so a small scope covers much less than it does for one call. That's the case where a universal claim adds something, which it didn't here.
- **The claim would be useful:** for example, that undoing any sequence of edits restores the text, and that tracked points stay valid throughout. Stale windows mean the second is false today, unless they're excluded or fixed.
- **It's much harder.** The claim would be about a model of emil's undo log, not its C. ATC couldn't generate the real code, which allocates, uses linked lists and has many pointers, so the gap between model and code would be larger than here.

The cheaper first step would be a randomised test of edit and undo sequences against the text model in this pilot, with a check of tracked points after each step. If that holds up and a proof still seems worthwhile, the same statements would carry over.
