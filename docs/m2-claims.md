# Milestone 2: proposed claims (for owner review)

**None of these are proved.** They're statements for you to approve, change or reject.
They're written as `defclaim` forms in `acl2/claims/statements.lisp`, and each becomes a
`defthm` of `(implies hyp concl)` in Milestone 3. `acl2/claims/spec.lisp` has the
definitions.

Each of the 17 statements has been run on every case of a small domain (up to 3 lines of 2 characters,
inserted text of up to 2 lines of 2 characters, at `INT_MAX` and at a tight `IMAX` of 4).
None failed, and every hypothesis was satisfied somewhere. Deliberately breaking the spec
made the check fail in 4 of 5 controls, and a sixth, returning 1 for a point past the deletion, was caught by `delete-return-is-exact`. The fifth, weakening the overflow predicate, can't be
seen there. Guard verification and `tests/m2/overflow_exact.c` cover that. This is testing of
the statements, not evidence that they're proved.

## The 15 statements

**None of these are proved.** Every row also leaves out four things: emil's C (`adjust-spec` is
written from it), whole UTF-8 characters (a "character" here is one byte in emil), sequences of edits,
and anything about the wrapper.

| # | Theorem | In plain English | Assumes | Doesn't cover |
|---|---|---|---|---|
| 1 | `insert-keeps-character-before` | A point before an insertion doesn't move and returns 0. It names the same character, and all the text up to and including it is unchanged. | Valid text, valid point, valid insertion. Point strictly before the start. | A point exactly at the insertion or after it (2, 5). |
| 2 | `insert-keeps-character-after` | A point after an insertion moves so that it names the same character, and all the text from there to the end is unchanged. Returns 0. | Valid text, valid point, valid insertion. Point strictly after the start. | A point before or exactly at the insertion (1, 5). |
| 3 | `delete-keeps-character-before` | A point before a deletion doesn't move and returns 0. It names the same character, and all the text up to and including it is unchanged. | Valid text, valid point, valid ordered deletion. Point strictly before the start. | A point at the start, inside, or after (4, 6, 7). |
| 4 | `delete-keeps-character-after` | A point at or after a deletion's end moves so that it names the same character, and all the text from there to the end is unchanged. | Valid text, valid point, valid ordered deletion. Point at or after the end. | The return value (9). Points before the end (3, 6, 7). |
| 5 | `insert-at-point-stays-before` | A point exactly at a real insertion stays and returns 0. **Same character stops here:** it now names the first inserted character, and the old one is at the insertion's end. | Valid text, valid insertion, non-empty text. The point is the insertion start. | Whether staying is the right behaviour for the editor. An empty insertion (10). |
| 6 | `delete-at-start-stays` | A point at a real deletion's start stays and returns 0. **Same character stops here:** it now names what was at the deletion's end. | Valid text, valid ordered deletion, start isn't the end. The point is the start. | An empty deletion (11). It doesn't state separately that the old character is gone. |
| 7 | `delete-inside-clamps` | A point strictly inside a deletion moves to the start and returns 1. **Same character stops here:** it now names what was at the deletion's end. | Valid text, valid point, valid ordered deletion. Point strictly between start and end. | The two ends (6, 8). Where the deleted text went. |
| 8 | `delete-at-end-clamps-but-keeps-character` | A point at a real deletion's end moves to the start and returns 1. **Its character survives,** so 1 doesn't mean lost. | Valid text, valid ordered deletion, start isn't the end. The point is the end. | An empty deletion (11). |
| 9 | `delete-return-is-exact` | A deletion returns 1 exactly when the point is after the start and at or before the end, otherwise 0: start out, end in. | Valid text, valid point, valid ordered deletion. | Insertions, whose 0 is in 1, 2 and 5. Why emil returns this, since no caller uses it. |
| 10 | `empty-insert-changes-nothing` | Inserting nothing leaves the text and every valid point unchanged, and returns 0. | Valid text, valid point, valid start. Inserted text is one empty line. | Non-empty insertions. |
| 11 | `empty-delete-changes-nothing` | Deleting from a position to itself leaves the text and every valid point unchanged, and returns 0. | Valid text, valid point, valid start. End equals start. | Non-empty deletions. |
| 12 | `insert-keeps-point-valid` | After an insertion, the text is still well formed and the point is a valid position in it. | Valid text, valid point, valid insertion. | A point that was already invalid. That's false for stale window points (D2). |
| 13 | `delete-keeps-point-valid` | After a deletion, the text is still well formed and the point is a valid position in it. | Valid text, valid point, valid ordered deletion. | A point that was already invalid. That's false for stale window points (D2). |
| 14 | `insert-within-limits-cannot-overflow` | A valid point and insertion can't overflow if rows and row counts stay within emil's limits, before and after. | Valid text, valid point, valid insertion. Every row at most `IMAX - 1`, at most `IMAX` rows, before and after. | Invalid points. C itself (that's guard verification, 4a). That emil enforces the limits, which is by reading. |
| 15 | `delete-within-limits-cannot-overflow` | A valid point and deletion can't overflow if rows and row counts stay within emil's limits, before and after. | Valid text, valid point, valid ordered deletion. Every row at most `IMAX - 1`, at most `IMAX` rows, before and after. | Invalid points. C itself (4a). That emil enforces the limits, which is by reading. |

Two more were added at your request, alongside the guard and not replacing it: see claim 4c. The full
forms of all 17 are below.

## How to read them

- `tx` is the text, a list of lines. `(x,y)` is the point. `(sx,sy)` and `(ex,ey)` are the
  edit's start and end. `ins` is the inserted text, as a list of lines.
- `adjust-spec` is a readable function written from `adjust.c`. It isn't emil's C. Connecting
  it to C is statement S1 below, and to emil's own C is Milestone 4 testing.
- `char-at` gives the character at a position, `:nl` at a line end, or `:eof` at the end of the
  text.
- `text-from` is everything from a position onward. `text-through` is everything up to and
  including it.
- **Why "same character" needs more than `char-at`.** The statements hold for any contents,
  including all-distinct characters, so equal means same there. But every newline is the same
  token, so `char-at` alone can't tell two newlines apart. That's why claim 1 also compares
  `text-from` or `text-through`, which pin the exact position in the surviving text.

## Claim 1: character preservation

A point outside the edit still refers to the same character.

```lisp
(defclaim insert-keeps-character-before (tx sx sy ins x y)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx)
       (not (pos<= sx sy x y)))              ; point strictly before the insertion
  (let* ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
         (new (insert-text tx sx sy ins)))
    (and (equal (adj-x r) x)
         (equal (adj-y r) y)
         (equal (adj-ret r) 0)
         (equal (char-at x y new) (char-at x y tx))
         (equal (text-through x y new) (text-through x y tx)))))
```
```lisp
(defclaim insert-keeps-character-after (tx sx sy ins x y)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx)
       (not (pos<= x y sx sy)))              ; point strictly after the insertion
  (let* ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil))
         (new (insert-text tx sx sy ins)))
    (and (equal (adj-ret r) 0)
         (equal (char-at (adj-x r) (adj-y r) new) (char-at x y tx))
         (equal (text-from (adj-x r) (adj-y r) new) (text-from x y tx)))))
```
```lisp
(defclaim delete-keeps-character-before (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (not (pos<= sx sy x y)))              ; point strictly before the deletion
  (let* ((r (adjust-spec x y sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) x)
         (equal (adj-y r) y)
         (equal (adj-ret r) 0)
         (equal (char-at x y new) (char-at x y tx))
         (equal (text-through x y new) (text-through x y tx)))))
```
```lisp
(defclaim delete-keeps-character-after (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (pos<= ex ey x y))                    ; point at or after the deletion's end
  (let* ((r (adjust-spec x y sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (char-at (adj-x r) (adj-y r) new) (char-at x y tx))
         (equal (text-from (adj-x r) (adj-y r) new) (text-from x y tx)))))
```

**In plain English:**
- A point before an insertion or deletion doesn't move. It names the same character, and
  all the text up to and including it is unchanged.
- A point after an insertion, or at or after a deletion's end, moves so that it names the
  same character, and all the text from there to the end is unchanged.

**What this doesn't cover:** points exactly at an insertion, or at the start of or inside a
deletion. Claim 2 covers those. It also says nothing about whole characters in UTF-8: emil's
columns are bytes, so here "character" means one element of the line, which is a byte in emil.

## Claim 2: exact boundaries, and where "same character" stops

| Point | Moves to | Returns | Same character? |
|---|---|---|---|
| Exactly at an insertion | Stays | 0 | **No.** It now names the first inserted character. The old one is at the insertion's end |
| At a deletion's start | Stays | 0 | **No.** Its character is gone, and it names what followed the deletion |
| Inside a deletion | Deletion start | 1 | **No.** Its character is gone, and it names what followed the deletion |
| At a deletion's end | Deletion start | 1 | **Yes.** Its character survives and has moved to the start |
| Any point, empty edit | Stays | 0 | Yes, and the text is unchanged |

```lisp
(defclaim insert-at-point-stays-before (tx sx sy ins)
  (and (valid-insert-p tx sx sy ins)
       (not (equal ins '(nil))))             ; a real insertion, point exactly at it
  (let* ((ex (insert-end-x sx ins))
         (ey (insert-end-y sy ins))
         (r (adjust-spec sx sy sx sy ex ey nil))
         (new (insert-text tx sx sy ins)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 0)
         ;; "same character" stops here: the point now names the first inserted
         ;; character, and the old character is at the end of the insertion
         (equal (char-at sx sy new) (char-at 0 0 ins))
         (equal (char-at ex ey new) (char-at sx sy tx)))))
```
```lisp
(defclaim delete-at-start-stays (tx sx sy ex ey)
  (and (valid-delete-p tx sx sy ex ey)
       (not (and (equal sx ex) (equal sy ey))))  ; a real deletion, point at its start
  (let* ((r (adjust-spec sx sy sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 0)                   ; returns 0 though its character went
         (equal (char-at sx sy new) (char-at ex ey tx)))))
```
```lisp
(defclaim delete-inside-clamps (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (not (pos<= x y sx sy))               ; strictly after the start
       (not (pos<= ex ey x y)))              ; strictly before the end
  (let* ((r (adjust-spec x y sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 1)
         (equal (char-at sx sy new) (char-at ex ey tx)))))
```
```lisp
(defclaim delete-at-end-clamps-but-keeps-character (tx sx sy ex ey)
  (and (valid-delete-p tx sx sy ex ey)
       (not (and (equal sx ex) (equal sy ey))))  ; a real deletion, point at its end
  (let* ((r (adjust-spec ex ey sx sy ex ey t))
         (new (delete-text tx sx sy ex ey)))
    (and (equal (adj-x r) sx)
         (equal (adj-y r) sy)
         (equal (adj-ret r) 1)                   ; returns 1 though its character survives
         (equal (char-at sx sy new) (char-at ex ey tx)))))
```
```lisp
(defclaim delete-return-is-exact (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx))
  (equal (adj-ret (adjust-spec x y sx sy ex ey t))
         (if (and (not (pos<= x y sx sy))    ; after the start
                  (pos<= x y ex ey))         ; at or before the end
             1
           0)))
```
```lisp
(defclaim empty-insert-changes-nothing (tx sx sy x y)
  (and (valid-insert-p tx sx sy '(nil))
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy sx sy nil)))
    (and (equal (insert-text tx sx sy '(nil)) tx)
         (equal (adj-x r) x) (equal (adj-y r) y) (equal (adj-ret r) 0))))
```
```lisp
(defclaim empty-delete-changes-nothing (tx sx sy x y)
  (and (valid-delete-p tx sx sy sx sy)
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy sx sy t)))
    (and (equal (delete-text tx sx sy sx sy) tx)
         (equal (adj-x r) x) (equal (adj-y r) y) (equal (adj-ret r) 0))))
```

**What this doesn't cover:** whether staying put is the right behaviour for the editor.
`adjust.h` and `test_adjust.c` chose it, and these statements only pin it down. "The character
is gone" isn't stated as a separate fact: the theorems say what the point names afterwards.

**Specification decision, made by you:** `adjust.h` says "inside a deleted region" without saying
whether the ends count. The start is out and the end is in. The header's wording is logged as defect D1.

## Claim 3: validity

A valid point stays valid in the edited text.

```lisp
(defclaim insert-keeps-point-valid (tx sx sy ins x y)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil)))
    (and (text-p (insert-text tx sx sy ins))
         (valid-pos-p (adj-x r) (adj-y r) (insert-text tx sx sy ins)))))
```
```lisp
(defclaim delete-keeps-point-valid (tx sx sy ex ey x y)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx))
  (let ((r (adjust-spec x y sx sy ex ey t)))
    (and (text-p (delete-text tx sx sy ex ey))
         (valid-pos-p (adj-x r) (adj-y r) (delete-text tx sx sy ex ey)))))
```

**What this doesn't cover:** a point that was already invalid. Those do occur in emil. See
"Does emil guarantee the hypotheses?" below.

## Claim 4: arithmetic safety

### The exact bound isn't 10^9

**The 10^9 bound has to go. It isn't what emil guarantees, and it excludes legal input.**
Emil loads files up to 1 GiB (1,073,741,824 bytes), so a single line, or the row count of a
file of newlines, can already exceed 10^9. Editing can go further. `emil.h` says row sizes are
"NOT bounded by anything at runtime", and only `abort()` checks near `INT_MAX` stop them.

### The exact condition

There's no single numeric limit, because whether an operation overflows depends on which path
the point takes. The exact condition is `adjust-no-overflow-p`, which checks every operation
on the path taken:

```lisp
(defun adjust-no-overflow-p (x y sx sy ex ey del imax)
  (let ((d (- ey sy)))
    (and (in-int-p d imax)
         (if del
             (cond ((pos<= x y sx sy) t)
                   ((pos<= x y ex ey) t)
                   ((= y ey) (and (in-int-p (- x ex) imax)
                                  (in-int-p (+ sx (- x ex)) imax)))
                   (t (in-int-p (- y d) imax)))
           (cond ((pos<= x y sx sy) t)
                 ((= y sy)
                  (if (= d 0)
                      (and (in-int-p (- ex sx) imax)
                           (in-int-p (+ x (- ex sx)) imax))
                    (and (in-int-p (- x sx) imax)
                         (in-int-p (+ ex (- x sx)) imax)
                         (in-int-p (+ y d) imax))))
                 (t (in-int-p (+ y d) imax)))))))
```

**In plain English:** work out which of the function's cases this point falls into, then ask whether
every sum and difference that case computes fits in an `int`. The line difference `endy - starty` is
computed on every call, so it always has to fit. A point before or inside the edit computes nothing else.
A point on the end line of a deletion, or the insertion line, computes its new column. A point on a
later line computes its new row. For example, a point at column `INT_MAX - 1` after a 2-byte
insertion on the same line fails it, because its new column would be `INT_MAX + 1`.

Evidence that it's exact: `tests/m2/overflow_exact.c` ran every combination of 9 corner values
(`INT_MIN`, `INT_MIN + 1`, -2, -1, 0, 1, 2, `INT_MAX - 1`, `INT_MAX`) for all six numbers, with
both `is_delete` values, under UBSan. **On 1,062,882 cases, the predicate and real overflow
disagreed 0 times, for both emil's function and the pointer-free version** (709,947 no overflow,
352,935 overflow). This is tested, not proved, and only at those corners.

### Proposed statements

**4a. In C (Milestone 3, guard verification).** `adjust-no-overflow-p` becomes the guard of the
three generated functions, so guard verification proves that no operation in them overflows
when it holds. Its exactness in the other direction stays tested, as above. For `adjust_new_x`
alone it's stricter than needed, because it includes checks for `adjust_new_y`.

**4b. Connection to the text model.** Within emil's row limits, a valid point and edit can't
overflow:

```lisp
(defclaim insert-within-limits-cannot-overflow (tx sx sy ins x y imax)
  (and (valid-insert-p tx sx sy ins)
       (valid-pos-p x y tx)
       (emil-limits-p tx imax)
       (emil-limits-p (insert-text tx sx sy ins) imax))
  (adjust-no-overflow-p x y sx sy (insert-end-x sx ins) (insert-end-y sy ins) nil imax))
```
```lisp
(defclaim delete-within-limits-cannot-overflow (tx sx sy ex ey x y imax)
  (and (valid-delete-p tx sx sy ex ey)
       (valid-pos-p x y tx)
       (emil-limits-p tx imax)
       (emil-limits-p (delete-text tx sx sy ex ey) imax))
  (adjust-no-overflow-p x y sx sy ex ey t imax))
```

Here, `emil-limits-p` is "every row has at most `IMAX - 1` characters and there are at most
`IMAX` rows", which is what `undo.c` states as its limits. The hypotheses apply to the text
both before and after the edit.

**What this doesn't cover:** invalid points. For those, the predicate still says exactly when
overflow happens, but nothing says the predicate holds.

**4c. The predicate can be met, and a simple bound implies it.** Both were requested alongside the
guard. Neither replaces it.

```lisp
(defclaim no-overflow-predicate-is-satisfiable ()
  t
  (adjust-no-overflow-p 0 0 0 0 0 0 nil 2147483647))
```

```lisp
(defclaim half-range-cannot-overflow (x y sx sy ex ey del imax)
  (and (natp imax)
       (natp x) (natp y) (natp sx) (natp sy) (natp ex) (natp ey)
       (<= (* 2 x) imax) (<= (* 2 y) imax)
       (<= (* 2 sx) imax) (<= (* 2 sy) imax)
       (<= (* 2 ex) imax) (<= (* 2 ey) imax))
  (adjust-no-overflow-p x y sx sy ex ey del imax))
```

**In plain English:** the point and edit all at (0,0) satisfy the predicate, so the guard isn't
vacuous. And if all six numbers are from 0 to `IMAX/2`, which is 1,073,741,823 for a 32-bit `int`, nothing
can overflow.

**What this doesn't cover:** it's only sufficient. A 1 GiB single-line file has a row of 1,073,741,824 bytes,
one more than this bound, and emil can load it. So this bound is for reading, and the guard stays exact.

The check caught a loosened hypothesis (`x` up to `IMAX`), after I'd widened the small domain to make that
possible. My first version of the check couldn't see it.

## Does emil guarantee the hypotheses?

Traced by reading emil `ac98ba0b`. **Partly: yes for the row limits, no for point validity.**

### Paths into `adjustPoint`

| Path | Edit coordinates from | Limit check before the arithmetic |
|---|---|---|
| `bulkInsert` (`undo.c:158`) | `computeInsertEnd` | Yes. `computeInsertEnd` and `bulkInsertRaw` abort first |
| `bulkDelete` (`undo.c:188`) | Clamped to the rows first | Yes. A multi-row delete aborts if the joined row wouldn't fit. A single-row delete only shrinks |
| `insertChar` (`edit.c:41`) | Cursor, `at + 1` | Yes. `rowInsertChar` aborts first |
| `mutateExtendRows` (`mutate.c:267`) | Row counts | Yes. `insertRow` limits apply first |
| Redo chain, direct call (`undo.c:311`) | Undo record, not clamped | Runs **before** that record is replayed. It should be fine because the record succeeded on the same text earlier, but no check runs first |

### The inputs

| Input | What emil guarantees |
|---|---|
| Row size | At most `INT_MAX - 1`, enforced by `abort()` on the paths above. Not 10^9 |
| Row count | At most `INT_MAX`, enforced by `abort()`. A file load refuses more than `INT_MAX / 2` |
| Edit start and end | No invalid or unordered edit found at any of the 51 sites, by reading and in about 2 million checked calls. **Most sites rely on an invariant, not a local check.** See `docs/m2-call-sites.md` |
| `is_delete` | Any `int` is fine. Callers pass 0, 1 or a record's flag |
| Mark and mark ring | Checked to be non-negative before the call. The sentinel is -1 |
| **Other windows' cursor** | **No validity check, and no upper limit.** Stale in practice: see below |
| Register points | No check, but they're set from the cursor |

### Unbounded: stale points in other windows

**Emil doesn't guarantee valid points in all windows.** It's wider than I first reported.

| Path | Evidence |
|---|---|
| `revert` to a shorter file (`tests/m2/stale_window.c`) | Reproduced: other window at (20,0) on a row of size 2 |
| `killBuffer` re-points windows at the next buffer and keeps their cursors (`tests/m2/stale_kill.c`) | Reproduced: other window at (20,8) in a 3-row buffer |
| `showPopupBuffer`: `createWindow` copies the current cursor, then the window gets the popup buffer | Reading only. The fuzzer's two minimised examples both use `C-x r V`, which shows a popup |

**Measured:** across 2,999 fuzz seeds, deletions saw **636 stale points, all in other windows' cursors,
in 70 runs, and none of those runs had a revert.** So revert isn't the common path. I haven't shown that the
paths above explain all 636, or that there are no others. No stale mark appeared.

Consequences:
- Claims 1 to 3 and 4b **don't apply** to these points, because their hypotheses are false for them.
- A stale point's row and column have no upper bound. Overflow would still need a value near `INT_MAX`:
  about 2^31 inserted bytes, or a stale point from an enormous buffer. It's unbounded, not likely.
- If it did overflow, that would be undefined behaviour in emil's C. The generated functions would be
  outside their guard in the same way.
- The effect I found is a stale line number in that window's status line. The column lookup there is
  bounded. Emil's fuzzer ran these paths under ASan and UBSan and reported nothing on them, but I haven't
  ruled out other effects.

Registers aren't affected the same way. After a revert, a register still names the destroyed buffer,
stops being adjusted, and is rejected at jump by `bufferAlive`.

Decided: these points stay outside every claim, Milestone 4 tests that the generated C and emil agree on
them, and this is logged as defect D2, not fixed.

## What each theorem assumes

| Assumption | Claims | Basis |
|---|---|---|
| Text is a non-empty list of lines | All | Model. See the differences below |
| The point is valid in the text before the edit | 1, 2 (where it takes a point), 3, 4b | **False for stale window points** |
| The edit is valid and ordered | All | No violation found at any of the 51 sites, but most rely on the cursor invariant or undo history: see `docs/m2-call-sites.md` |
| Inserted text's end is `computeInsertEnd`'s answer | Insert claims | Model definition, matching `undo.c` by reading |
| Row limits, before and after the edit | 4b | Enforced by `abort()` in emil |
| `int` is 32-bit two's complement | 4a | ATC's C model |

Generated-C claims also have the assumptions already in the ledger: the step from `*program*` to
the C file, the wrapper, the C model, the compiler, the hardware, ACL2 and SBCL.

## How the model differs from emil's real buffer

| Model | Emil |
|---|---|
| A line is a list of characters | A row is bytes, and columns are byte offsets. A point can be inside a UTF-8 character. `deleteRange` snaps to character boundaries, but that isn't modelled |
| At least one line | `numrows` can be 0 for a moment, in rowless special buffers. `bulkInsertRaw` then returns without inserting, **but `adjustAllPoints` still runs**. I haven't shown that's reachable with a point to adjust |
| Each edit stands alone | A replace is a delete, then an insert. `restoreFinalNewline` can add another insert. Each step is covered, but not the sequence |
| The edit always happens | `bulkDelete` clamps its input, read-only buffers refuse edits, and the final-newline rule can refuse one. `undo.c:311` uses a record's unclamped coordinates |
| Pure function of numbers | Emil adjusts many points through `adjustAllPoints`, skipping the focused window's cursor. `adjustAllPoints` and `adjustRowIndex` aren't in scope |
| No resource limits | `abort()` and allocation failure end the program |

## Supporting statement for Milestone 3

**S1. C-shaped functions equal the spec.** For all inputs satisfying the guard, with `IMAX` as
`INT_MAX`, the three ACL2 functions behind the generated C agree with `adjust-spec`:

```lisp
(equal (c::integer-from-sint (|adjust_new_x| x y sx sy ex ey is_delete))
       (adj-x (adjust-spec (c::integer-from-sint x) ... (c::boolean-from-sint is_delete))))
;; and likewise adjust_new_y with adj-y, and adjust_clamped with adj-ret
```

This is a sketch, not exact ACL2, and I'll show you the exact form in Milestone 3. Together with
ATC's replayed theorems, it would connect claims 1 to 3 to the generated value functions. It
wouldn't connect them to the wrapper, which is testing only, as the ledger says.

## Status of your review

Decided: start out and end in, stale points outside the claims, and the exact guard with its two
corollaries. **Not yet approved: the statements themselves.** Milestone 3 doesn't start until they are.
