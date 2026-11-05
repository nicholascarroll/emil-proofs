# Milestone 2: does every call site establish "the edit is valid and ordered"?

Subject: emil `ac98ba0b`. I read all 50 places that reach `adjustPoint`, then checked what
actually arrives by running an instrumented scratch copy of emil (`tests/m2/audit_patch.py`).

**Result: no call site was found passing an invalid or unordered edit, but most don't establish
the hypothesis by themselves. They rely on an invariant or on a helper, and one rests on no
local check at all.** So claims 1 to 3 and 4b rest on these assumptions, not on a guarantee at
each site.

The hypothesis is `valid-insert-p` or `valid-delete-p`: the start and end are inside the text,
and the start isn't after the end.

## Running it

| Run | Calls checked | Invalid or unordered edits |
|---|---|---|
| Emil's full test suite (`ALL PASSED`) | 1,943,212 | 0 |
| Emil's key fuzzer, 3,000 seeds | At least 86,838 | 0 |

The fuzzer's call count is a lower bound, because many of its child processes exit without writing their
totals. Violations are logged immediately, so that count is complete. This shows only what those runs reached. Deletions are checked before the rows change, and
insertions after. A multi-row insertion's start and end are checked against the row they end up
in, which is what the rows can show at that point.

## The 50 sites

| Group | Sites | Establishes order? | Establishes range? | Depends on |
|---|---|---|---|---|
| **A. `deleteRange`, which normalises** | `edit.c:218, 327, 540, 545, 557, 609, 628, 858, 875`, `region.c:366` (10) | **Yes:** `orderPoints` | **Yes for columns and the end row:** clamps and snaps them. Not the start row | Start row exists. If it's past the end, `bulkDelete` returns before adjusting. A negative start row isn't handled. `edit.c:218` and `region.c:366` also check the mark with `markInvalid` |
| **B. Derived from row data** | `edit.c:168, 198, 202, 240, 249`, `region.c:932, 1059, 1120, 1169`, `mutate.c:88, 267` (11) | **Yes,** by construction | **Yes,** given the row. `edit.c:202` can compute an end past the row on malformed UTF-8; `bulkDelete` clamps it before adjusting | Cursor's row is valid. `region.c:932, 1059` also check the mark. `region.c:1169` relies on the `rect_height > 0` check |
| **C. Insert at the cursor** | `edit.c:53, 58, 129`, `region.c:411`, `fileio.c:1458`, `completion.c:715` (6) | Yes: start equals where the text goes, and `computeInsertEnd` gives the end | **No local check** | **The cursor invariant** (below) |
| **D. `transformRange`, which orders only** | `region.c:540`, reached from `edit.c:271, 282, 375, 415, 454, 504`, `region.c:558` (1 + 7) | **Yes:** `orderPoints` | **No local check** | Cursor invariant and motion helpers. `region.c:558` also checks the mark. `edit.c:504` can compute an end past the row on malformed UTF-8; `bulkDelete` clamps it |
| **E. Direct replace from motion or offsets** | `edit.c:711, 797`, `region.c:845` (3) | **Not checked.** It holds because the helpers only move one way (`edit.c`), or because the first offset can't follow the last (`region.c`) | Follows from the helpers, or from counting the region's own text | Cursor invariant and helper behaviour, by reading |
| **F. Undo and redo replay** | `undo.c:235, 240`, direct call `undo.c:311` (3) | **Not checked** | **Not checked.** `undo.c:311` also uses the record's unclamped coordinates | That the history matches the text, which is emil's undo design and isn't checked here |
| **G. `insertChar`** | `prompt.c:312, 356` → `edit.c:41` (2) | Yes | **`prompt.c:312` doesn't establish it:** defect D3 | Minibuffer cursor. No effect found, because nothing tracks points there |
| **Pass-through** | `mutate.c:149, 180, 197, 204, 210, 216, 222`, `region.c:352` (8) | Inherits | `bulkDelete` clamps; **`bulkInsert` doesn't** | Their callers |

**The cursor invariant:** `clampPositions` runs at the end of every `processKeypress`, for `E.buf`
only, including the minibuffer while a prompt is open. Commands then start from a valid cursor,
but nothing checks that at the mutation itself. Two things can break it: a command that moves the
cursor before mutating, and a mutation of a buffer other than `E.buf`. I found neither at these
sites. Group C and D sites use the cursor directly or via helpers that keep it in range.

## Findings

1. **Group F establishes nothing locally.** Replaying an undo record assumes the text is what it
   was when the record was made. That's the design, but it's an assumption of these claims.
2. **Groups C, D and E rely on the cursor invariant.** It's enforced once per keypress, not at the
   mutation.
3. **`bulkDelete` doesn't order rows.** `starty > endy` would pass through. Only its callers prevent
   this. It's safe in all sites above, but it isn't enforced.
4. **Clamping doesn't reach everything.** `bulkDelete` adjusts with clamped coordinates, but the
   undo record, and the `bulkInsert` that follows in a replace, use the unclamped ones. They
   differ only if a caller passes something out of range.
5. **`bulkInsert` adjusts points even if nothing was inserted.** `bulkInsertRaw` returns silently
   when `starty >= numrows`, and `adjustAllPoints` still runs. I found no site that reaches it.
6. **Defect D3:** `insertChar` adjusts with a column `rowInsertChar` may have clamped.

## Points, separately from edits

The edit hypothesis held, but the point hypothesis didn't always:

| Run | Points checked at deletions | Stale |
|---|---|---|
| Emil's test suite | 784,403 | 0 |
| Emil's key fuzzer, 2,999 seeds | At least 13,782 | **636, all other windows' cursors, in 70 runs, none with a revert** |

Insertions aren't counted, because by then the rows have changed. So this understates it. See
"Unbounded: stale points in other windows" in `docs/m2-claims.md`.

## Also found: a runaway seed (not about `adjustPoint`)

Seed 1127 of emil's own fuzzer fails, on unmodified emil as well as the instrumented copy. It's
logged as defect D4 in `docs/emil-defects.md`. Memory grew by about 1 GB per second until the process
was killed. The fuzzer minimises it to 6 keys: `C-M-r M-9 2 C-u M-4 ^`. I didn't investigate the
cause.
