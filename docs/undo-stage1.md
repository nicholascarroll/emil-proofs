# Undo stage 1: model and differential test

Emil `ac98ba0b`, ACL2 `7ac80c83`. Reproduce with `tests/undo/build.sh` and `tests/undo/run-stage1.sh`.

## What was built

- `acl2/undo/model.lisp`: text, edits, records, coalescing, paired records, final-newline repair, undo and redo, cursor.
  Certified, no tags. It reuses `insert-text`, `delete-text`, `flat`, `offset` and `adjust-spec` from the pilot.
- `tests/undo/driver.c`: runs emil's real `mutate.c` and `undo.c` under ASan and UBSan and prints text, cursor, results and history.
- `acl2/undo/diff/check.lsp`: replays each trace on the model and compares every step. The head record of each list is
  compared on every step, and both whole lists every 32 steps, along with `history-matches-p`. It also checks on C's text
  that undoing everything gives the original, and that undo N then redo N gives the text from before the undo.
- `tests/undo/history_check.c`: the same history check in C, after every key of emil's own key fuzzer, so it covers real commands.

**Not modelled:** dirty flag, mark, other windows' points, registers, `INT_MAX` guards, memory, buffers with no rows.

## Valid sequences: 0 disagreements

300 seeds of 5,000 steps: 1,500,000 steps, 0 disagreements, 0 property failures, 0 history mismatches, 0 invalid cursors after undo or redo.

That says the two agree on what the generator produced. It isn't a claim about other inputs.

Test evidence that this could fail:

| Model bug seeded | Clean seeds of 20 | First failure |
|---|---|---|
| merge limit 19 | 19 | :NUNDO |
| repair record not paired | 1 | :UNDO |
| backspace appends | 0 | :UNDO |
| undo ignores saved point | 0 | :CX |
| redo doesn't carry point | 18 | :CX |
| delete ignores chain | 1 | :UNDO |
| final newline delete allowed | 1 | :NUNDO |
| burst ignored | 0 | :UNDO |
| undo leaves run open (expected equivalent) | 20 | NOT DETECTED |
| merge ignores append flag | 0 | :NUNDO |
| edit keeps redo | 0 | :NREDO |
| extend anchored a row early | 0 | :UNDO |
| repair skipped | 1 | :TEXT |
| insert end off by one | 0 | :UNDO |

| C bug seeded | Clean seeds of 20 | First failure |
|---|---|---|
| merge limit 19 | 19 | :NUNDO |
| repair not paired | 1 | :UNDO |
| no repair | 1 | :TEXT |
| backspace merges at wrong end | 0 | :UNDO |
| end not recomputed on merge | 0 | :UNDO |
| redo keeps group apart | 1 | :TEXT |
| undo leaves run open (expected equivalent) | 20 | NOT DETECTED |
| replace not paired | 0 | :UNDO |

"Undo leaves run open" isn't detected in either form, and I believe that's because it changes nothing: only the head record
can have `append` set, since `pushUndo` closes the old head. So the `undoCloseRun` at the end of `undoStep` looks redundant
on the undo side. That's reasoning, not a proof.

Line coverage of the driver over 20 valid seeds and the hostile classes: `undo.c` 95.5%, `mutate.c` 95.9%. The lines not run are
the `abort()` size guards, the `INT_MAX` branches, the rowless branch of `mutateExtendRows`, an empty `bulkInsert`, and
`if (prev->paired || new->paired) return 0` in `undoMerge`, which looks unreachable because coalescing is off whenever a record is paired.

Two generator and check faults found and fixed along the way, neither in the model:

1. My redo check compared "undo all, redo all" even when the redo list already held records. Redo then goes further than the
   undo did, so the texts rightly differ. The check now needs an empty redo list in that case.
2. The driver started every text with an extra empty row, because `newBuffer` already holds one. So "no final newline" was
   never tested. It now loads as `fileio.c` does. Also, runs never reached the merge limit until I added long typing runs.

## Invalid operations: every class disagrees, and C looks wrong

The model's specification is that an invalid range is refused and changes nothing. C at this commit has no such outcome.
Each class ran 100 seeds of mostly valid operations, stopping at the first disagreement.

| Case | Edit gives | Undo gives | Redo gives | Sanitizer |
|---|---|---|---|---|
| valid delete (control) | `ac|def|` | `abc|def|` | `ac|def|` | none |
| end x past row, same row | `a|def|` | `abc||def|` | `a||def|` | none |
| end x past row, next row | `a|` | `abc|def||` | `a||` | none |
| end row past last row | `a|` | `abc|def||` | `a|` | none |
| reversed on one row | `abc|def|` | `abc|c|def|` | `abc|c|def|` | none |
| reversed across rows | `abc|def|` | `abc|def|` | `abc|def|` | none |
| start x past row | `abcdef|` | `abcdef\x00\xbe\xbe||` | `abcdef\x00\xbe\xbe|` | none |
| start row past last row | `abc|def|` | `abc|def|` | `abc|def|` | none |
| old_text differs from range | `ac|def|` | `acc|def|` | `ac|def|` | none |
| insert: x past row | `crash` | `crash` | `crash` | AddressSanitizer: negative-size-param |
| insert: y past last row | `abc|def|` | `abc|def|` | `abc|def|` | none |
| extend: from_row wrong | `abc|def||` | `abc` | `abc|` | none |

Start text `abc|def|`, with `|` between rows.

**Verdict: C looks wrong, not the model,** wherever undo fails to restore the text or memory is misused. "Reversed across
rows", "start row past last row" and "y past last row" do no visible harm to the text, but they still leave a record for an
edit that didn't happen.

## Real paths that break "history matches text" (from the key fuzzer and call-site review)

3,000 key-fuzz seeds with the check on every buffer except the minibuffer, then 400 including it. **No mismatch in a file
buffer**, but three defects outside that, all in code the model treats as out of scope:

| # | Path | What happens | Evidence |
|---|---|---|---|
| U1 | C-d on a truncated UTF-8 lead byte at the end of a row (`edit.c:202`) | Old text is read past the row. Undo then adds a NUL byte: `a\xC3` comes back as `a\xC3\x00`. With a 4-byte lead, **ASan: heap-buffer-overflow read** | `tests/undo/repro_paths.c` |
| U2 | TAB or `/` in a prompt (`prompt.c:312,356`, `insertChar`) changes the text with no record | Undo in the prompt then deletes the wrong bytes: `\tab` becomes `b`. 210 of 400 seeds hit it | Same, and fuzz seed 3 |
| U3 | A special buffer made writable with C-x C-q, edited, then rebuilt by `bufferResetRows`, which keeps the history | Undo and redo replay stale records. **ASan: negative-size memmove** in `bulkInsertRaw` | Keys `C-x r v ~ C-x 0 C-x C-q 本 C-x r v SPC` reach the mismatch. The crash itself comes from simulating that state in `repro_paths.c`, not from those keys |

The key fuzzer doesn't compare undo results and its text has no truncated lead at a row's end, which is why it hadn't shown these.

Seeds failing without a history message on replay: 476, 1127, 1799, 1809, 2780. 1127 is the known D4 runaway. I haven't looked at the others.

## Effort

Model and driver: most of a session segment. Full run: 1m46s. Model certification: under 1s once the measure was right (2 failed attempts: a CL-package name, and a measure).
