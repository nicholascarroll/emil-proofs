# Milestone 0: toolchain and ATC reality check

Pins: ACL2 `7ac80c83` (8.7+, 2026-11-04) on SBCL 2.2.9, emil `ac98ba0b`.
Sources: `kestrel/c/atc/doc.lisp`, `tutorial.lisp`, `defstruct-doc.lisp`,
`function-and-loop-generation.lisp` and `tests/` at that commit, plus our own runs.
The 2022 paper was not used.

## Result

ATC can express `adjustPoint` with the same signature and the same conditions, but
with two caveats:

1. ATC's generated proof fails unless every path writes both pointers, so paths
   that change nothing need `*px = *px;`.
2. ATC's generated theorem only covers pointers to `:alloc` objects. Emil's callers
   pass struct members and stack locals, so it doesn't literally cover any real call.

## What ATC supports now

| Area | Supported | Not supported |
|---|---|---|
| Integer types | `signed`/`unsigned` `char`, `short`, `int`, `long`, `long long` | Plain `char`, floating point, `_Bool` |
| Integer model | Fixed: 8-bit char, 32-bit `int`, 64-bit `long` and `long long`, two's complement, no padding | Other formats |
| Pointers | Parameters that point to an integer or struct, read and written with `*` or `->` | Pointer locals, pointer returns, pointers to pointers, pointer arithmetic |
| Arrays | Integer array parameters, read and write by index | Array locals (external objects via `defobject` instead) |
| Structs | By value or by pointer. Members are integers or integer arrays | Other member types, such as pointers or nested structs |
| Control flow | `if`/`else`, `?:`, `&&`, `||`, `while`, non-recursive calls to earlier functions | `for`, `do`, `switch`, recursion in C. A loop body must end in the recursive call on every path, so no `return` inside a loop |
| Multiple outputs | `(mv ret var1 ... varn)`: one C return value plus changes through pointer or array parameters | Returning a pointer or array |
| Undefined behaviour | Guards must be verified, so each operation's condition (such as no signed overflow) has to be proved | |

## The trust tags

- ATC's include tree has 922 books. The audit found no skipped proofs or axioms in
  any of them.
- 13 community books carry a trust tag, and all look like file or OS plumbing: the
  ATC entry points (`atc`, `generation`, `input-processing`), the printer and file
  writers, `oslib`, and the quicklisp libraries (`base`, `uiop`, `cl-fad`, `osicat`).
- None of the 13 is in the C model (`kestrel/c/language`) or ATC's symbolic-execution
  rules, so the semantics and proof rules themselves carry no tag.
- **Limit:** this doesn't prove the tags can't affect a proof. Tagged code runs raw
  Lisp in the same image as the prover, so it is trusted not to interfere.
- Only four tags actually appear. `:open-output-channel!` never does, so I removed it
  from the allowlist.

## Tiny function

`add_one` generated `return x + 1;`, certified, compiled with gcc and clang, and ran.

## How adjustPoint is represented

```lisp
(defun |adjustPoint| (|px| |py| |startx| |starty| |endx| |endy| |is_delete|)
  (declare (xargs :guard (and (c::star (c::sintp |px|)) (c::star (c::sintp |py|))
                              (c::sintp |startx|) ... bounds ...) ...))
  ... (mv (c::sint-dec-const 0) |px| |py|) ...)
```

In ACL2, `px` and `py` are the integers pointed to, and the function returns
`(mv ret new-px new-py)`. In C, they are `int *` parameters. The generated header is
`int adjustPoint(int *px, int *py, int startx, int starty, int endx, int endy, int is_delete);`,
which matches emil's declaration exactly.

The source is `acl2/atc-proto/adjust-shape.lisp`. Its 10^9 bound is a prototype
convenience. The real bounds are a Milestone 2 question.

### Differences in shape from emil's function

| # | Emil | Generated | Effect |
|---|---|---|---|
| 1 | Unchanged paths don't write | `*px = *px;` and `*py = *py;` on those paths | Extra stores in the C source. Same values, unless the pointers overlap, which the theorem excludes. An optimiser may remove them; not yet measured (Milestone 4). |
| 2 | Early `return`, then fall through | Nested `if`/`else` | Same paths, deeper nesting. |
| 3 | `*py -= d`, `*px += d` | `*py = *py - d` | Same meaning. |
| 4 | `(a && b)` parenthesised inside `\|\|` | No parentheses | Same meaning, but 3 warnings at `-Wall` (below). |
| 5 | Comments | None | ATC has no way to emit comments. |

`lines_delta = endy - starty` is still computed on entry, as in emil, so its overflow
condition applies to every call.

### Compile and smoke test

Built with `-std=c99 -Wall -Wextra -Wpedantic -Wconversion` and ASan and UBSan:

- gcc 13.3: 3 `-Wparentheses` warnings. clang 18.1: 3 `-Wlogical-op-parentheses`.
- No sanitizer reports. 0 differences from emil's function on 8,192 inputs: every
  value 0 to 3, with both values of `is_delete`.

That grid is a smoke test, not the Milestone 1 harness. It includes meaningless edits
and checks nothing about the intended property. Emil's `DEFAULT_CFLAGS` include
`-Wall` but not `-Werror`, so these warnings wouldn't break its build, but they would
be new noise.

## Caveat 1: paths that don't write

A minimal function fails, with no user lemmas involved:

```c
if (*x < 0) return 0;   /* no write */
*x = 7; return 1;
```

The generated theorem `v1-POP-FRAME` fails and no C file is written. ATC's hints use
a fixed theory, so a lemma of ours can't be added to them. Writing the value back on
every path gets through. This looks like a gap in ATC's proof generation, not a
fundamental limit, but I haven't traced the cause.

Alternatives:

| Shape | Result |
|---|---|
| A: emil's branches, with write-backs | **Works. Used here.** |
| B: copy to locals, single exit, write once at the end | Generated proof fails at `adjustPoint-px-IN-SCOPE-62`. Cause not investigated. |
| Report upstream, or patch ATC | Not tried. Patching would mean a modified tool. |

Reproductions are in `experiments/atc-failures/`.

## Caveat 2: what the generated theorem covers

`*PROGRAM*-adjustPoint-CORRECT` says, in plain English: in any C computation state,
if the hypotheses below hold and the execution limit is at least 231, then running
the C function returns the ACL2 function's result and writes its new values through
`px` and `py`, and the model's execution raises no error.

Hypotheses:

- The inputs satisfy the guard, including the bounds.
- `px` and `py` are valid pointers to `int`.
- The two objects don't overlap.
- **Both objects have kind `:alloc`.** ATC generates this for every pointer parameter
  (`function-and-loop-generation.lisp`, line 1242).

The C model has separate kinds for `:auto` (locals), `:member` (struct members),
`:element` and `:static`. Every real caller of `adjustPoint` uses a different kind:

| Caller | Argument | Kind in the model |
|---|---|---|
| `adjustAllPoints` | `&buf->markx`, `&E.windows[i]->cx`, `&buf->mark_ring[m].cx`, register points | `:member` |
| `undo.c:311` | `&px`, `&py` | `:auto` |

So the theorem doesn't literally apply to any call in emil. C itself doesn't treat
an `int` differently by where it is stored, so I expect the behaviour to be the same,
but that would be an assumption, not something the theorem proves.

The theorem also doesn't cover overlapping pointers. All the callers above pass two
different `int`s, so that isn't a practical gap.

## Costs

| Item | Time (2 cores) |
|---|---|
| `scripts/setup.sh`: fetch ACL2 and build | 2m29s |
| First certification, including about 930 community books | 25m22s |
| One ATC book afterwards | About 40s, of which about 29s is loading ATC |

Proof iterations so far on the shape prototype: 4 (missing `int` range hints; the
write-back failure; shape B failed; shape A passed).

## Pointer-free prototype (owner request)

Source: `acl2/atc-scalar/three-functions.lisp`, generated `adjust_scalar.c`, hand-written
`adjust_wrapper.c`. The 10^9 bound is again a prototype convenience.

| Version | Result |
|---|---|
| F: three functions of scalars (`adjust_new_x`, `adjust_new_y`, `adjust_clamped`) | **Works** |
| S: struct passed and returned by value, member written before the branches | ATC supports the types, but its generated proof fails at `adjust_value-lines_delta-IN-SCOPE-26` |
| S: same, with that write removed and a guard requiring `clamped == 0` | Generated proof fails at `adjust_value-CORRECT-59` |

The causes of the two struct failures weren't investigated. Reproductions are in
`experiments/atc-failures/`.

### Does the generated theorem have `:alloc` or pointer hypotheses?

**No.** The three `-CORRECT` theorems were checked by searching the printed
`adjust_new_x` theorem for `alloc`, `pointer`, `objdes` and `disjoint`: 0 matches. The
hypotheses are that the state is a computation state, the function environment is this
program's, all seven inputs are `int` values within the guard's bounds, and the
execution limit is high enough. The conclusion also says the state is left unchanged:
`(mv result compst)`.

### What remains unproven

| Item | Status |
|---|---|
| The wrapper: reads `*px` and `*py`, passes arguments in the right order, writes the results back | **Hand-written C, no theorem.** Evidence is testing and review only |
| That the three results together behave as `adjustPoint` | Provable in ACL2 at Milestone 3, against the spec. Not done yet |
| The wrapper calling generated functions compiled separately | Outside the theorem, whose function environment holds only the generated program |
| Callers meeting the input bounds | A Milestone 2 question, and not proved by any of this |
| `*program*` to C text, then compiler, hardware, C model, ACL2 and SBCL | Trusted, as for the pointer version |

So the gap gets smaller and moves: it doesn't vanish. **`adjustPoint` as emil calls it
would still not be proven.** What's proven would be the three value computations, for
the values real callers pass, whichever storage they came from.

### Effect on shape and effort

| | Emil | Pointer version (A) | Pointer-free (F) |
|---|---|---|---|
| Generated C | n/a | 1 function, 7 extra writes | 3 functions, 0 pointers, no write-backs |
| Hand-written C | 54 lines | None | 7-line wrapper body |
| `-Wparentheses` warnings | 0 | 3 | 8 |
| `.text` at `-O2` (gcc, bytes) | 236 | 235 | 657 (376 + 281) |
| Time per call, separate files | 6.3 to 6.7 ns | 6.3 to 6.5 ns | 10.9 to 11.4 ns |
| Time per call, F with `-flto` | | | 5.2 to 5.5 ns |
| Attempts to get through ATC | | 4 (shape A's path) | 2, one being my own hint syntax error |
| ATC book certification | | About 40s | 39s |

Timings are three runs of one gcc build on a mix of inputs, so they're preliminary.
Milestone 4 owns the real comparison. Each generated function re-evaluates the branch
conditions, so F does the same tests up to three times. `-flto` removes that cost here,
but emil's Makefile doesn't use it, so F would need that or a change in how it's compiled.

The smoke test ran the wrapper on stack locals, struct members and heap objects: 0
differences from emil on 8,192 inputs, with gcc and clang, and no sanitizer reports.

Proof effort from here isn't measured. F replaces reasoning about writes with three plain
functions, so I expect the spec equivalence to be simpler, but it hasn't been attempted.
