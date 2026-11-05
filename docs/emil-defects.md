# Emil: defects and refactor candidates found by this pilot

Logged only. Nothing here has been changed in emil. D2 and D4 are for the owner to act on, and this pilot didn't investigate them further.
Subject: emil `ac98ba0b`.

| ID | Kind | Summary | Evidence | Status |
|---|---|---|---|---|
| D1 | Documentation defect | `adjust.h` is misleading about "inside a deleted region" | Below | Logged |
| D2 | Defect | Emil does not guarantee valid points in all windows | Two paths reproduced by running emil's code, and seen under its fuzzer | Logged, not fixed |
| D3 | Inconsistency, no effect found | `insertChar` adjusts points with a column that `rowInsertChar` may have clamped | Reading only | Logged |
| D4 | Defect, cause not investigated | Runaway memory on a 6-key sequence in emil's own fuzzer | Reproduced on unmodified emil | Logged |
| R1 | Refactor candidate | `adjustPoint`'s return value is unused | Search of all callers | Logged, not changed |

## D1: misleading header wording

`adjust.h` says the function "returns 1 if the point was inside a deleted region (now clamped to
the deletion start), 0 otherwise". It doesn't define "inside". The behaviour, which
`test_adjust.c` pins and which the owner has chosen as the spec, is that the start is out and the
end is in. That means the return value doesn't track whether the point's character was lost:

- At the deletion's start: returns 0, though the character is gone.
- At the deletion's end: returns 1, though the character survives.

## D2: stale points in other windows

**Reproduction:** `tests/m2/stale_window.c`, run by `scripts/run-m1.sh`. With two windows on one
buffer, a long line and the other window's cursor at column 20, the file shrinks on disk and the
focused window reverts:

```
revert replaced the buffer: yes
row 0 size after revert: 2
other window's point after revert: (20,0), valid: NO
after inserting 1 byte at (0,0): row size 3, other window's point (21,0), valid: NO
```

`revert` points every window at the new buffer but only clamps the focused cursor.
`synchronizeBufferCursor` corrects the other window when it next gets focus. Until then, edits run
`adjustPoint` on the invalid point.

**It's wider than revert.** `killBuffer` re-points windows at the next buffer and keeps their cursors
(reproduced by `tests/m2/stale_kill.c`: other window at (20,8) in a 3-row buffer). `showPopupBuffer` looks
like a third path: `createWindow` copies the current cursor, then the window gets the popup buffer (reading
only). Across 2,999 seeds of emil's fuzzer, deletions saw 636 stale points in other windows' cursors, in 70
runs, none with a revert. I haven't shown that these paths explain all of them.

**Effect:** that window's status line shows a stale line number, and the point's column can grow
without any limit check. The status line's column lookup is bounded. Overflow would need a column
near `INT_MAX`. No crash or corruption was found.

## D3: `insertChar` and a clamped column

`insertChar` (`edit.c:39-41`) passes `at = bufr->cx` to both `rowInsertChar` and `adjustAllPoints`.
`rowInsertChar` clamps `at` to the row size, but `adjustAllPoints` gets the unclamped value. They
disagree if `cx` is past the end of row `cy`.

`prompt.c:310-312` looks like the one way to get there: it sets `cx` from row 0 but keeps the current
`cy`, so a multi-row minibuffer could reach it. That needs a path containing a newline, and I didn't
try to build that case. **No effect found:** nothing tracks points in the minibuffer, whose mark is
reset to -1.

## R1: unused return value

No caller uses `adjustPoint`'s return value: `adjustAllPoints` calls it four times and `undo.c:311`
once, all as statements. Claim 2 still pins it, because `adjust.h` documents it.

## D4: runaway memory on a short key sequence

Found when running emil's own `tests/fuzz_keys.sh`. **Seed 1127 fails on unmodified emil.** Replaying
it, memory grew by about 1 GB per second (2.6, 3.8, then 4.9 GB) until the process was killed, with no
sanitizer report. The fuzzer minimises it to 6 keys:

```
C-M-r M-9 2 C-u M-4 ^
```

The cause isn't investigated, and I can't say whether `adjustPoint` is involved. Nothing suggests it
is. I only ran this in the fuzzer's harness, not in a real terminal. Out of scope for this pilot, so
logged only.

Reproduce: `FUZZ_WORK=<dir> sh tests/fuzz_keys.sh 1127 1`, as an unprivileged user.
