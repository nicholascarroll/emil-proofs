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
| `completion.c:291` `*Completions*` for the buffer prompt (and search prompt, same list) | Not now | Fixed in `49b5902`, shown as `^J`. `repro_paths completion-buffer-newline`: row `qq^Jyy` |
| `register.c` headers and preview | Not now | Fixed |
| `completion.c:366` `*Completions*` for files and commands | No | File scan refuses names the minibuffer can't hold; `repro_paths completion-file-newline` lists nothing. Commands are fixed names |
| `completion.c:248` minibuffer text | No | Splits on newline |
| `ctags.c:454` tag menu | No | Fields come from one line of the tags file. From reading |
| `fileio.c:550,1398` file and stdin lines | No | `getline`, with line endings stripped. From reading |
| `buffer.c` `bufferLoadBlob` (registers, pipe, palette, stdin) | No | Splits on newline |
| `undo.c` `bulkInsertRaw`, and so all mutations | No | Splits on newline |
| `mutate.c` rebuild | No | Splits on newline |
| `rowInsertChar` | Gone | Removed in `17320f2`: it had no non-test caller |

**Limit:** this is one search of the `insertRow`, `appendRowRaw`, `rowInsertChar` and direct `chars` writes in non-test code. It rests partly on reading.

**Reruns at `53f223a`:** `make test` passes, sanitizers pass, no build warnings. Key fuzz, 3,000 seeds with truncated UTF-8 lines: 0 rows with a newline, whether checked after each key or logged at each row created, 0 history mismatches, 0 replay refusals, 0 invalid ranges. One failure: 1127, the known D4. The fuzz doesn't hit the `*Completions*` case: it took a direct reproduction to show it.

**So at `53f223a` assumption 5 was still false in that one case, fixed below.** The proofs are unchanged. Differential and refcheck weren't rerun, as you didn't ask.

## Enforcing the rule (owner request)

**`49b5902`:** `*Completions*` shows a newline as `^J`, in both the buffer list and the column layout, using `utf8SanitizeLine`. Tests: `test_buffer_prompt_lists_newline_name_on_one_row` and `test_search_prompt_lists_newline_name_on_one_row`. With the old `completion.c`, both fail in `make test` and the check aborts in `make sanitize`.

**`17320f2`:** `rowInsertChar` removed, as it had no non-test caller. Its test went; `test_undo_reports_changed_text` now builds its row with `bufferResetRows` and `insertRow`.

**`18d417c`:** `EMIL_DEBUG_ROW_BYTES` aborts if a newline enters a row. On in `make sanitize`, `tests/fuzz_keys.sh` and `refcheck/build.sh`. Not in a normal build: `emil` holds no trace of the string. It covers `insertRow`, `appendRowRaw`, and the three places in `undo.c` that copy into an existing row. A search for direct `chars` writes in non-test code found no others that add bytes. `rowEnsureCap`, the `fileio.c` shrink and `memmove` within a row add no new bytes. A fork test confirms it aborts through `insertRow` and `appendRowRaw`; the `undo.c` sites have no such test.

**What tripped it:** once, in a test fixture. `test_special_buffer_is_not_checked` built a row from `"output\n"` (`tests/test_warnings.c:679`). The test doesn't depend on that byte, so the fixture now says `"output"`. No production path tripped it.

**Reruns at `18d417c`, check on:** `make test` and sanitizers pass, no build warnings. Key fuzz, 3,000 seeds: the check didn't trip, 0 history mismatches, 0 replay refusals, 0 invalid ranges. One failure: 1127, the known D4, with empty stderr. Also 1,521 "row is not valid UTF-8" leads; see "Final checks at `18d417c`" below.

**Assumption 5:** no known exception on the patched branch. On `main`, the register views and `*Completions*` remain exceptions until the patches are applied. Limits: the fuzz doesn't reach the `*Completions*` case, so only the unit tests cover it. The check runs only in debug builds and only sees what those runs execute. "At least one row" isn't part of the check; the fuzz checks it after each key, and it didn't fail. The proofs still assume all of this. Differential and refcheck weren't rerun after `415c942`.

## Final checks at `18d417c` (owner request)

### The UTF-8 warnings

Spec: `README.md:172` says every buffer contains only valid UTF-8. `emil.1:498` says load and insertion disallow malformed UTF-8.

**The 1,521 are mine.** `tests/undo/fuzz_history.sh` adds truncated lines to a copy of the fuzzer's text, and `fillBuffer` puts them in the unnamed buffer with `insertRow`, skipping load validation. `tests/undo/fuzz_utf8.sh` reproduces the same 1,521 seeds, and logs every invalid row in every buffer and every file write.

| Printed warnings at `18d417c` | Seeds | Buffer |
|---|---|---|
| Injected row, seen at the first check | 1,379 | Unnamed |
| Injected row, first command took several keys | 80 | Unnamed |
| Injected row, started in a file buffer, switched to it later | 62 | Unnamed |

In all 1,521, the invalid row was present before any key.

**The count is low.** 2,077 seeds have this warning, on `main` and the branch alike. The fuzzer loses the other 556 because `C-x C-c` exits with status 0. That gap is in `tests/fuzz_keys.c` on `main`. The newline and row-count checks abort instead, so they aren't affected.

| 3,000 seeds | `main` stock | `18d417c` stock | `main` truncated | `18d417c` truncated |
|---|---|---|---|---|
| Seeds with an invalid row | 1 | **0** | 2,712 | 2,712 |
| Printed warnings | 0 | 0 | 1,519 | 1,521 |
| File writes (all valid) | 908 | 908 | 643 | 646 |
| Writes with invalid bytes | 0 | 0 | 0 | 0 |
| Saves refused | 0 | 0 | 445 | 441 |
| Seeds with invalid bytes in a named file buffer | 0 | 0 | 73 | 82 |
| Failures | 1127 | 1127 | 949, 1127, 1578, 1620, 2266 | 1127 |

- Seed 753 is the one stock case on `main`: an invalid minibuffer row after `M-%`. It's one of the 13 seeds classified as U2, and is gone on the branch.
- 1578 and 2266 crash on `main` before they can print, which is the difference of 2.
- With invalid bytes already present, edits can spread them: `c3 f0 9f 98 80` becomes `9f 98 80` after `C-d`, as a 2-byte lead takes the next byte (seeds 1874, 2785, 2880). None arise from valid text in the stock runs.

**Real paths, driven through a pty (`tests/undo/utf8_paths.py`, no injected text):**

| Path | `main` | `18d417c` |
|---|---|---|
| Load, `C-x i`, stdin, shell output with invalid bytes | Refused | Refused |
| Buffer named `qq\xFFy`, completed in the minibuffer | **Invalid row** | **Invalid row** |
| Same name in `*Completions*` | **Invalid row** | Fixed |
| Same name in register views | **Invalid rows** | Fixed |
| Tags file with invalid bytes, `*Tags*` | **Invalid row** | **Invalid row** |
| Killed from the minibuffer, yanked into a file buffer, saved | **Invalid row, save refused, file unchanged** | Same |

**File save:** invalid bytes can reach a save attempt, but no write held any. `saveBuffer` is the only route to the write, and it refuses first (`fileio.c:896`). That is from reading plus the 3,105 logged writes, not a proof. A refused buffer can't be saved until the bytes are removed.

**Spec:** the 1,521 aren't a violation by emil, as the harness skips validation. The minibuffer and `*Tags*` paths are violations of the README's sentence, on `main` too, and not regressions. Neither was fixed here.

### Differential

1,100 seeds, 3.1M steps: 0 disagreements, 0 property failures, 0 history mismatches, 0 crashes. Same as `415c942`, including the same 8 "lie" invalid cursors on the same seeds. The driver had the newline check on.

### Refcheck, `ac98ba0` against `18d417c`

2,000 seeds: 260 differ, up from 257. No seed left or changed group. The 3 new ones (744, 1197, 1986) are `53f223a` showing a control byte as `^X` in `*Output*`, and seed 1197's old row holds a real newline. I replayed all 3.

- Findings 24 to 22: `completion.c` and `register.c` "changed lines no test runs" went, as the new tests run them.
- Incomplete 23 to 28: 5 more suites with changed tests "did not run against the old code", so `newtests` says nothing for 10 suites.
- 31 seeds in 17 groups are still not minimised. The earlier attribution of the 257 wasn't repeated; they kept their groups.
- Still no test or fuzz run reaches a few defensive lines, including `undo.c:360` (`UNDO_MISMATCH`).

## Filename display (owner request, replaces the file path rule)

The owner cancelled the file path rule, `9d6a32d`, and everything after it on `filename-rule`. Its patches are gone from `patches/`; the runs that tested it are in this file's git history. Stored paths stay raw. No refusals, messages or path rules are added.

`patches/filename-display/`, four patches on `18d417c`, ending at `bff04b2`. The first 15 are unchanged. All 19 on `ac98ba0b` give the `bff04b2` tree.

| Patch | Commit | Source | Tests or tool |
|---|---|---|---|
| `*Tags*` rows | `86d7eb6` | +49 -8 | +75 |
| Fuzzer: leads on `C-x C-c` | `63a0ef6` | none | +15 -1 (tool) |
| Names into the minibuffer, `main.c` error | `bd1a67d` | +30 -8 | +163 |
| Docs: `emil.1`, README, CHANGELOG | `bff04b2` | +7 -1 (docs) | none |

**Routes from a stored filename:**

| Route | State | Evidence |
|---|---|---|
| TAB in the buffer and search prompts | Fixed, `bd1a67d` | Unit tests; real editor |
| Completion cycling | Fixed, `bd1a67d` | Unit test only |
| `main.c:380`, error at startup | Fixed, `bd1a67d` (now `:388`) | Real editor; raw at `18d417c` |
| `*Completions*`, register views, `*Output*` | Already sanitised in the 15 | Real editor for the first two |
| Mode line, status messages, prompts, confirm prompts | Stored raw, drawn through `abAppendSafe`. Not changed | Real editor for open, save, kill, quit, default prompt |
| File completion | Name filtered by `nameInsertable`, typed part unchanged. Not changed | Unit test for a typed tab |
| Kill ring, history | Hold only typed or edited text | Reading |

`main.c:282` prints an unrecognised option raw. It isn't a stored filename, so it's left alone and reported.

**Open, edit and save:** with a line feed, ESC or invalid UTF-8 in the name, in `test_fileio` and a real editor (`tests/undo/name_routes.py`). Existing and new files save to the real path, with no extra files. No row holds a newline or invalid UTF-8, and the raw name never reaches the terminal. 29 scenarios pass. At `18d417c`, 4 fail: 3 at the startup error and 1 with invalid UTF-8 in the minibuffer.

**A limit in the documented sentence:** "can be opened by exact path" holds on the command line for every name. In a prompt, a line feed can be typed with `C-o`, but ESC and invalid UTF-8 can't, and file completion hides such names. That's the same at `18d417c`.

**Reruns at `bff04b2`:** `make test` and sanitizers pass, no build warnings. Differential: 3.1M steps, 0 disagreements, 0 crashes, the same 8 "lie" cursors. Key fuzz with history checks, 3,000 seeds: seed 1127 only, 0 refusals, no newline rows. UTF-8 fuzz, own text: 0 invalid rows, 908 writes, all valid. With added lines, all 2,077 warnings print.

**Refcheck:** against `18d417c`, 0 of 2,000 seeds differ. Against `ac98ba0`, 260 differ, the same seeds in the same groups as `18d417c` against `ac98ba0`.

**Limits:** the fuzz never reaches the `*Tags*` or completion-cycling lines. No suite test runs the `main.c` error, only the real-editor scenarios. `newtests` didn't run `ctags` against the old code.

**Assumption 5 and the README rule:** no known exception at `bff04b2`. Tested, not proved.

**Verdict:** go.

