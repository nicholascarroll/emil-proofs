# Milestone 2: proposed claims (for owner review)

**None of these are proved.** They're statements for you to approve, change or reject.
They're written as `defclaim` forms in `acl2/claims/statements.lisp`, and each becomes a
`defthm` of `(implies hyp concl)` in Milestone 3. `acl2/claims/spec.lisp` has the
definitions.

Each statement has been run on every case of a small domain (up to 3 lines of 2 characters,
inserted text of up to 2 lines of 2 characters, at `INT_MAX` and at a tight `IMAX` of 4).
None failed, and every hypothesis was satisfied somewhere. Deliberately breaking the spec
made the check fail in 4 of 5 controls. The fifth, weakening the overflow predicate, can't be
seen there. Guard verification and `tests/m2/overflow_exact.c` cover that. This is testing of
the statements, not evidence that they're proved.

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

CLAIM(insert-keeps-character-before)
CLAIM(insert-keeps-character-after)
CLAIM(delete-keeps-character-before)
CLAIM(delete-keeps-character-after)

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

CLAIM(insert-at-point-stays-before)
CLAIM(delete-at-start-stays)
CLAIM(delete-inside-clamps)
CLAIM(delete-at-end-clamps-but-keeps-character)
CLAIM(delete-return-is-exact)
CLAIM(empty-insert-changes-nothing)
CLAIM(empty-delete-changes-nothing)

**What this doesn't cover:** whether staying put is the right behaviour for the editor.
`adjust.h` and `test_adjust.c` chose it, and these statements only pin it down. "The character
is gone" isn't stated as a separate fact: the theorems say what the point names afterwards.

**Specification decision for you:** `adjust.h` says "inside a deleted region" without saying
whether the ends count. These statements make the existing behaviour the spec: the start isn't
inside, the end is. That's in the ledger as a new decision.

## Claim 3: validity

A valid point stays valid in the edited text.

CLAIM(insert-keeps-point-valid)
CLAIM(delete-keeps-point-valid)

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
PREDICATE
```

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

CLAIM(insert-within-limits-cannot-overflow)
CLAIM(delete-within-limits-cannot-overflow)

Here, `emil-limits-p` is "every row has at most `IMAX - 1` characters and there are at most
`IMAX` rows", which is what `undo.c` states as its limits. The hypotheses apply to the text
both before and after the edit.

**What this doesn't cover:** invalid points. For those, the predicate still says exactly when
overflow happens, but nothing says the predicate holds.

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
| Edit start and end | Valid and ordered on the paths I read: `deleteRange` orders and clamps them, and `bulkDelete` clamps them. **`bulkDelete` doesn't order them, and I haven't checked all of the roughly 30 call sites of the mutation functions** |
| `is_delete` | Any `int` is fine. Callers pass 0, 1 or a record's flag |
| Mark and mark ring | Checked to be non-negative before the call. The sentinel is -1 |
| **Other windows' cursor** | **No validity check, and no upper limit** |
| Register points | No check, but they're set from the cursor |

### Unbounded: a stale point in another window

**Confirmed by running emil's code (`tests/m2/stale_window.c`).** With two windows on one buffer,
when the file shrinks on disk and one window reverts, the other window's cursor isn't updated.
Emil only corrects it when that window next gets focus. Until then, edits run `adjustPoint` on it:

```
row 0 size after revert: 2
other window's point after revert: (20,0), valid: NO
after inserting 1 byte at (0,0): row size 3, other window's point (21,0), valid: NO
```

Consequences:
- Claims 1 to 3 and 4b **don't apply** to this point, because their hypotheses are false for it.
- Its column has no upper bound. It grows with insertions before it on its line, and nothing
  checks it. Overflow would still need a column near `INT_MAX`, so it would take either about
  2^31 inserted bytes or a stale point from an enormous row. It's unbounded, not likely.
- If it did overflow, it would be undefined behaviour in emil's C. The generated functions would
  be outside their guard in the same way.
- I didn't find a user-visible failure beyond that window's status line showing the stale line
  number. The status line's column lookup is bounded. I haven't changed anything in emil.

I didn't find other stale-point paths, but I didn't search exhaustively. `showOutputBuffer`
resets rows without touching window cursors, so it's a candidate I didn't test. Registers aren't
one: after a revert, a register still names the destroyed buffer, stops being adjusted, and is
rejected at jump by `bufferAlive`.

## What each theorem assumes

| Assumption | Claims | Basis |
|---|---|---|
| Text is a non-empty list of lines | All | Model. See the differences below |
| The point is valid in the text before the edit | 1, 2 (where it takes a point), 3, 4b | **False for stale window points** |
| The edit is valid and ordered | All | Holds on the paths I read, but not checked at every call site |
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

## Questions for you

1. **Do you approve the statements?** In particular, are you happy with "same character" meaning
   `char-at` plus `text-from` or `text-through`?
2. **Should "inside a deleted region" mean the start is out and the end is in?** That's emil's
   current behaviour. The alternative is to treat the header's wording as a defect to report.
3. **How should stale window points be treated?** I recommend recording them in the ledger as
   outside every claim, with Milestone 4 testing the generated C and emil on them for agreement.
   The theorems stay as they are, because weakening them to cover invalid points would prove
   nothing useful.
4. **Is 4a's guard right?** I recommend the exact, path-sensitive `adjust-no-overflow-p`, not a
   simpler but stricter numeric bound. The cost is a guard that's harder to read.
