# Undo stage 3: statements for review

**Nothing here is proved yet.** The formal text is `acl2/undo/statements.lisp`. On a small exhaustive
domain, the statements held in all of about 413,000 sequences (`acl2/undo/diff/check-statements.lsp`).
That can show a statement is false, not that it is true. It did show one was false as first written (see C).

All four are about the ACL2 model, not about emil's C. The link from the model to the C is differential testing only.

## R. The history matches the text

> After any sequence of operations, every undo and redo record describes the text it will be replayed on.
> Undoing a delete has a real position to insert at. Undoing an insert, or redoing a delete, finds a real
> range holding exactly the record's bytes. Each record's end is where its data ends.

**Why it's here:** you asked me to treat undo replay's "not checked" call-site findings as requirements. This
establishes them on the model, and A and B need it anyway. Theorem: `history-matches-p` of any reached state.

**What it means for the C:** the new `UNDO_MISMATCH` should be unreachable from edits alone.

## A. Undoing all edits restores the original

> Start from a text with an empty history. Apply any sequence of edits, undos, redos, cursor moves and
> run-closing. Undo with a count of more than the number of records left. The text is the starting text.

"Any sequence" includes invalid edits (refused), chained edits, final-newline repair, coalesced runs and undos
mixed with redos.

## B. Redo after undo restores the text

> In any state reached as above, if undoing N groups succeeds, then redoing N groups also succeeds, and the text
> is what it was before the undo.

This covers more than "the last edit": any N, in any reached state, including one with redo entries already waiting.

**It doesn't say** that history or the cursor come back. They don't, exactly: `append` flags close, and redo
puts the cursor at the change's start, not where it was.

## C. Coalesced undo gives the same text as separate undos

> In any reached state, take a run of edits: one that doesn't fold into an earlier record, then later ones that each
> fold into the run. Make them once with coalescing and once without. The text after the run is the same both
> ways. Undoing once after the coalesced run gives the same text as undoing once per edit after the separate run.

**Needs these hypotheses (they say what a run is):**

- Each edit only inserts or only deletes, is accepted, and every edit after the first actually merges. Otherwise it isn't a run.
- **The first edit doesn't fold into an earlier record.** My first version lacked this and was false: type `x`, leave the
  run open, and "the run" silently extends it, so one coalesced undo also removes `x`. The small-domain check found it.
  It only corrects the statement: nothing was proved under the old one.

A run may end with an edit that triggers final-newline repair. Both undo paths remove the repair too.

## Assumptions, for all four

| # | Assumption | Status in emil |
|---|---|---|
| 1 | The model behaves as emil's C does | **Tested only:** 1.5M steps, 0 disagreements. Not proved |
| 2 | **All text changes go through edits, extensions, undo and redo** | **False in two known places:** U2 (TAB or `/` in a prompt) and U3 (rebuilt writable special buffer). No mismatch in file buffers in the key fuzz. The C now refuses to replay on a mismatch, instead of corrupting |
| 3 | The history isn't cleared during the sequence, and "original" means the text when it was last cleared | Clearing happens on file load and per prompt |
| 4 | The buffer isn't read-only when undoing, and no read-only change occurs in the sequence | A read-only buffer refuses undo, which the model also does, but read-only changes aren't in the sequences |
| 5 | Starts with at least one row, and no row contains a newline byte | `bufferEnsureRow` and the loaders are meant to ensure this. Not proved |
| 6 | Replacement text is a list of bytes | C passes a pointer and length |
| 7 | No `INT_MAX` overflow, and allocation succeeds | Not modelled. C aborts on the size guards |

**Not covered at all:** the cursor (beyond being recorded), the mark, other windows' points, registers, the dirty
flag, memory safety, and the undo commands above `doUndo` and `doRedo`.

## Spec decisions for the ledger

1. An invalid range is refused and changes nothing. That's the model's spec, and C now matches it.
2. Buffers with no rows are out of scope.
3. A run is as defined in C above.
