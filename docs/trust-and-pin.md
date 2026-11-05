# Trust tags and the ACL2 pin

Checked 2026-11-06 against ACL2 `7ac80c83`, using a history clone back to 2026-08-01.

## 1. Do ATC's trust tags affect our theorems?

**The logical theorems: no, for the books tested. The generator and the C text it
writes: yes.** This comes from an experiment, not from reading the source.

### Experiment (`scripts/atc-replay.sh`)

1. Run ATC normally, and dump the events it generated as text.
2. Build a replay book holding the same ACL2 functions and ATC's generated proofs,
   without ATC, without the event that writes the C files, and with no `:ttags`.
3. Certify it, so ACL2 re-proves every theorem without ATC running.
4. Audit its whole include tree for skipped proofs, axioms and any trust tag.
5. Check that the program constant, the functions and the `-CORRECT` theorems are
   identical in the ATC world and the replay world.

Results, run through `scripts/certify.sh` against the clean-built tools:

| ATC book | Replay certified | Include tree | Strict audit | Statements identical |
|---|---|---|---|---|
| `tiny` | 24s | 611 books | Pass: no tags, skipped proofs or axioms | Yes |
| `adjust-shape` (pointer version) | 31s | 611 books | Pass | Yes |
| `three-functions` (pointer-free) | 29s | 611 books | Pass | Yes |

Controls, to show the replay isn't vacuous:

- Changing `+` to `-` in the replay's program constant makes certification fail.
- Changing `+` to `-` in the replay's ACL2 function makes certification fail.

Both fail at early generated lemmas (`*PROGRAM*-FUN-ENV`, `adjust_new_x$NOT-NORMALIZED`),
not at `-CORRECT`. They show the replay notices a mismatch, but not that the final
theorem alone would. The Milestone 3 seeded-bug checks test the theorems themselves.

### What this establishes

| Item | Depends on trust-tagged code? |
|---|---|
| Logical proof of `*program*-<fn>-correct` and `*program*-well-formed` | **No.** Re-proved with no tags in the include tree |
| C model and ATC's proof rules | **No.** `symbolic-execution-rules/top` passes the strict audit |
| Generating the events | Yes, but its output gets re-checked, so a generator error can't produce a false theorem. It can only make the replay fail or produce a different theorem, which the comparison would catch |
| Printing and writing the `.c` and `.h` files | **Yes.** This stays trusted, and the theorems don't cover it anyway |

### What it doesn't establish

- **The link from theorem to C file is still unproven.** The theorems are about the
  syntax tree `*program*`. The tree is converted and printed by `kestrel/c/syntax`,
  and that step runs in the tagged session. Tags aren't the main concern there: the
  printer was already on your trusted list, and this one replaced ATC's old printer
  only in September 2026.
- ACL2 and SBCL are still trusted. Replay removes the tags, not those.
- It holds for the books replayed. `scripts/certify.sh` repeats it for each ATC book
  and fails if any replay fails.

### Tag details

Commit `e1d66835` ("[ATC] Add more trust tags", 2026-09-01) is in the pin. It lists
`:open-output-channel!` in the certify flags, but no book in the tree defines that
tag: `open-output-channel-bang.lisp` defines `file-io!`. The audit finds four tags,
in 13 community books.

### Does the rule need rewording?

**The original rule doesn't need relaxing.** "A theorem may not rely on ... trust
tags" can be met literally, so I recommend tightening how it's applied:

> A theorem cited in the ledger must be certified in a book whose entire include tree
> has no `skip-proofs`, `defaxiom`, trust tags, uncertified books or fast-cert. Books
> that run ATC are generators: they may use the tags in
> `scripts/atc-allowed-ttags.txt`, but no claim may rest on them. For generated C, the
> claim rests on the replay book, and the step from `*program*` to the C file is
> recorded as trusted.

This narrows the exception you approved earlier, which allowed tags in books that run
ATC without saying whether claims could rest on them. It's your decision, so the
wording in `CLAUDE.md` is unchanged for now. `scripts/certify.sh` already enforces the
stricter version.

## 2. Soundness fixes and the pin

**Pin:** `7ac80c830dd91e094c73f869acb06d877e717b36`, 2026-11-04. A development
snapshot after 8.7, not a release. At the time of checking, it was also the head of
both `master` and `testing`.

**It includes the September and October fixes.** History search is by commit message,
so it can miss fixes that don't use the word "sound":

| Period | Commits mentioning "sound", all in the pin |
|---|---|
| 1 to 14 Sep | 3 |
| 15 to 30 Sep | 35 |
| 1 to 14 Oct | 11 |
| 15 to 31 Oct | 10 |
| 1 to 4 Nov | 0 |

The last fix found is `20f539fa` on 2026-10-27 (Boolean reasoning and forward
chaining, among others). `cf72377b` on 2026-10-28 also mentions soundness, but its
headline is an improved error message.

**Recommendation: don't re-pin now, because nothing newer exists.** The fix rate
suggests more are likely, so:

- Check for new soundness commits when Milestone 3 starts, and re-pin if there are any
  (a full recertification is about 29 minutes here).
- Keep the pin frozen during proving, so results stay comparable.
- Check again before writing the verdict, and report any later fix rather than
  silently moving.

## 3. ATC printer migration and proof-generation fix

Both are in the pin, confirmed by ancestry check:

| Commit | Date | Change |
|---|---|---|
| `4319c44c` | 2026-09-01 | Start migration of pretty-printer |
| `10e4b80b` | 2026-09-11 | Use newer pretty-printer |
| `3e25853d`, `c97dd027` | 2026-09-13 | Remove the old printer and its dependencies |
| `7ebafa93` | 2026-09-13 | Use printer option from syntax for tools |
| `4cf446b7` | 2026-10-21 | Fix bug in proof generation |

Our generated events call `c$::write-fileset`, which confirms the new printer is the
one in use.

`4cf446b7` adds `declar` and `assign` to the theory of two guard lemmas generated for
calls. It is a separate issue from either ATC failure in
`docs/atc-reality-check.md`: those fail in different generated theorems, and they
still fail with this fix in place.
