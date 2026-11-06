# Undo stage 2: refactor and evidence

Branch `undo-refactor` of emil, 7 commits on `ac98ba0b`, ending at `0ac84d2`. `main` is untouched. **Pushing it to emil is
refused (403)**, so the commits are saved in `patches/undo-refactor/`. Apply with `git am`.

## Final runs at `0ac84d2`

| Check | Result |
|---|---|
| `make test` | All passed, including source invariants |
| `make sanitize` (ASan, UBSan) | All passed |
| Differential, valid | 300 seeds, 1.5M steps, 0 disagreements |
| Differential, invalid classes | 8 classes, 100 seeds each, 1.6M steps: **0 disagreements, 0 crashes** (all disagreed at `ac98ba0b`). The model wasn't changed |
| Key fuzz with history check, truncated UTF-8 lines added | 1,500 seeds: 0 invalid ranges reached, 0 file-buffer mismatches. 13 replay refusals in prompts, 47 special-buffer history mismatches (U3), 2 other failures with no history message (157, and 1127, the known D4) |
| Refcheck, old against new | 2,000 seeds. 13 diverge (below). 0 warnings, tests clean |

"Lie" reports 8 invalid cursors after undo or redo, the same as before the refactor. I believe that's the hostile generator
pre-empting a pending cursor move, not emil, but haven't traced it. Model and C agree on them.

## 1. Remove `old_text`

**Evidence no caller needs it:** a copy logged every mutation and compared `old_text` with `collectRegionText`:
793,853 calls in `make test`, and 1.1M in 4,000 fuzz seeds. **Every valid range matched.** The only differences were at invalid
ranges, where the supplied text was wrong. So there's no debug check to add, because no caller supplies it now.

**Not run by either:** `region.c:844` (regex replace). That site rests on reading the code: it passes the text of exactly that range.

Cost: `mutateDelete` and `mutateDeleteChar` now allocate a copy on each call. Pure inserts skip it. Not measured.

## 2. Invalid ranges are an explicit error

`mutate*` return `MUTATE_INVALID` with a status message and nothing changed. `bulkDelete` and `bulkInsert` return -1.

**Every caller that passed an invalid range. All come from one cause, truncated UTF-8 at the end of a row:**

| Caller | Command | Fix |
|---|---|---|
| `edit.c:202` | C-d | Cap the character's length at the row |
| `edit.c:502` via `transformRange` | C-t | Same |
| `edit.c:264` via `transformRange` | M-u, M-l, M-c | Cap in `forwardWordEnd` |
| `edit.c:408` via `transformRange` | M-t | Same |

The last two surprised me: the pilot's call-site review listed `edit.c:202` and `:504` only, and I only found these by running.
The fuzz reached them only with truncated-UTF-8 lines that I added to a copy of it. Emil's own fuzz text has none.

**Tests affected: one.** `test_bulk_delete_clamps_out_of_range_end` asserted the clamp. It's now `..._refuses_...`. Its
stated point, no negative length, still holds. The source invariant on record construction was updated too (section 4).

## 3. Pure merge decision

`undoMergeDecision` only reads its arguments, returns none, append or prepend, and has direct tests.

## 4. Record module

`undorecord.c`: `newUndo`, `undoRecordNew`, `undoRecordReserve`, `undoRecordFreeList`. Four hand-built records in `mutate.c`
become `undoRecordNew`. `undoReplaceData` is gone. The invariant now covers both constructors outside `mutate.c` and `undorecord.c`.

## Every behaviour change

| # | Change | Who sees it |
|---|---|---|
| 1 | C-d on a truncated sequence deletes what's there, and undo restores it exactly. Before: undo added a NUL, and a 4-byte lead over-read the heap | Files with truncated UTF-8 |
| 2 | C-t on a truncated sequence works. Before: negative-size `memcpy`. **This is beyond your list**, in its own commit with #1, so you can drop it | Same |
| 3 | M-f, M-u and others stop at the row's end, not past it. Before: the end was past the row, then clamped | Same |
| 4 | An invalid range is refused. Before: clamped, or a crash on insert | No real caller, after 1 to 3 |
| 5 | **Undo and redo refuse a record that doesn't match the text**, with a message. Before: wrong text, or a crash | Prompts after TAB or `/` (U2), rebuilt writable special buffers (U3) |
| 6 | Find's cancel loop and yank-pop stop if undo fails. Find's loop could otherwise spin forever. Neither path was run by tests or fuzz | Only with #5 |
| 7 | On an invalid range or a final-newline refusal, out-params get the cursor. Before: not written, and read uninitialised by `transformRange` in the final-newline case | Internal |
| 8 | Inserting in a buffer with no rows is refused. Before: silently dropped, but a record was still pushed | None seen |

**#5 is my reading of your instruction on the "not checked" assumptions.** It's in the same commit as the invalid-range change.
It doesn't fix U2 or U3: the text still changes without a record, so undo in those places now stops rather than corrupts.
**It also means undo can stick** at that record until the history is cleared.

## Refcheck's 10 findings

- **2 divergences, 13 of 2,000 seeds:** screen (10) and kill ring (3). Both witnesses are undo in a prompt after TAB (U2).
  **Attribution:** I built a variant with only the replay check removed and the old clamps restored. Against old code:
  **2,001 seeds, 0 divergences**, including all 13. So they all come from change 5 or the clamp removal, and the rest of the refactor
  shows no keystroke-level change. That fuzz has no truncated UTF-8, so it can't speak to changes 1 to 3. I read only the two minimised witnesses, not all 13.
- **3 footprints:** `mutateReplaceEx` (argument renumbering), `undoStep` (now writes the status message), `bulkInsert` (reads row sizes). All expected.
- **5 "changed lines no test runs":** guards, abort paths, `region.c:844` and `region.c:487`.

Incomplete: new tests can't run on old code because they use the new API, and the fuzzer's first 300 seeds didn't reach some changed lines.
Also: `make hal` reformatted `display.c`, which I reverted. It's not in the branch.

## Not fixed, for you to decide

- **U2:** `insertChar` in prompts makes no record. Clearing or recording would close it.
- **U3:** `bufferResetRows` keeps history. Clearing it there would close it.
- `edit.c` cursor moves after C-t and arrow keys on truncated sequences can still go past the row, until `clampPositions`.

## After the proofs

Owner's decisions: keep the replay check and the C-t fix. The stuck state is a known limitation. U2 and U3 are fixed in separate commits, and neither needed a model change.

- **U2 (`0b091b6`):** TAB and `/` in a prompt use `selfInsert`. `insertChar` is gone.
- **U3 (`b0638c8`):** `mutateRebuildBegin` and `End` replace `bufferResetRows` at the six special-buffer sites. With no history, nothing changes. With history, the rebuild is a normal `mutateReplace`. Effect: such a buffer can gain a final empty row.
- **Regex replace (`1e5f0c3`):** tests drive the prompts and walk the whole history. A seeded range bug at that call fails them.
- **Sanitizers:** my new tests first failed under LeakSanitizer by initialising the editor twice. Fixed in `415c942`. Sanitizers were not rerun between `1e5f0c3` and that fix.

**All 13 earlier refcheck seeds** (75, 164, 306, 349, 753, 960, 1235, 1266, 1537, 1771, 1800, 1844, 1905) are U2. In each, a logging build shows exactly one replay refusal, in the minibuffer, after an unrecorded `insertChar` on that minibuffer. The last logged event before the refusal is that `insertChar`, except seed 960, where an unrelated special-buffer rebuild falls between them.

**Key fuzz at `415c942`, 3,000 seeds with truncated UTF-8 lines added:** 0 history mismatches, 0 replay refusals, 0 invalid ranges in any buffer. 11 failures: 10 newline-in-row (assumption 5), and 1127 (D4). Assumption 2 holds for U2 and U3 in this test. Other unrecorded paths could exist that the fuzz doesn't reach.

**Refcheck at `415c942`:** see `docs/undo-report.md`. 24 findings: 5 divergence groups, 9 unminimised groups (listed as incomplete), footprint changes from the rebuild helper and status messages, comments still naming `insertChar`, and changed lines no test runs.

## Newlines in rows (owner request after the report)

**Fix (`53f223a`):** `C-x r V` wrote a point register's filename into a row as it was. It now goes through `utf8SanitizeLine`, in both `*Output*` and the `*Register Preview*` that the same keys show first. A newline shows as `^J`, as do other control bytes. Valid UTF-8 is unchanged. Names over 159 bytes are cut a little sooner than before.

**Test:** `test_register_point_filename_newline`. On the old code its `*Output*` assertions fail. Its preview assertion passes on both, because the renderer also draws a newline as `^J`, so the unit test doesn't cover the preview. The row log below does.

**Every way to put bytes into a row:**

| Path | Can hold a newline? | How I know |
|---|---|---|
| `completion.c:291` `*Completions*` for the buffer prompt (and search prompt, same list) | **Yes** | `repro_paths completion-buffer-newline`: row `qq\x0Ayy`. **Not fixed; for you** |
| `register.c` headers and preview | Not now | Fixed |
| `completion.c:366` `*Completions*` for files and commands | No | File scan refuses names the minibuffer can't hold; `repro_paths completion-file-newline` lists nothing. Commands are fixed names |
| `completion.c:248` minibuffer text | No | Splits on newline |
| `ctags.c:454` tag menu | No | Fields come from one line of the tags file. From reading |
| `fileio.c:550,1398` file and stdin lines | No | `getline`, with line endings stripped. From reading |
| `buffer.c` `bufferLoadBlob` (registers, pipe, palette, stdin) | No | Splits on newline |
| `undo.c` `bulkInsertRaw`, and so all mutations | No | Splits on newline |
| `mutate.c` rebuild | No | Splits on newline |
| `rowInsertChar` | Could | No caller outside tests now. From grep |

**Limit:** this is one search of the `insertRow`, `appendRowRaw`, `rowInsertChar` and direct `chars` writes in non-test code. It rests partly on reading.

**Reruns at `53f223a`:** `make test` passes, sanitizers pass, no build warnings. Key fuzz, 3,000 seeds with truncated UTF-8 lines: 0 rows with a newline, whether checked after each key or logged at each row created, 0 history mismatches, 0 replay refusals, 0 invalid ranges. One failure: 1127, the known D4. The fuzz doesn't hit the `*Completions*` case: it took a direct reproduction to show it.

**So assumption 5 is still false in that one case.** The proofs are unchanged. Differential and refcheck weren't rerun, as you didn't ask.
