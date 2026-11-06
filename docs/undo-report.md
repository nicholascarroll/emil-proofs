# Undo refactor and proofs: one page

Emil `ac98ba0b` plus 15 patches (`patches/undo-refactor/`, ending at `18d417c`). The proofs, differential and refcheck ran at `415c942`; the last four patches change the register views, the `*Completions*` display, remove the unused `rowInsertChar`, and add a debug check. ACL2 `7ac80c83`; 31 newer commits, none mentioning soundness in their messages, so the pin stays.

**Assumption 2, "all text changes go through edits, extensions, undo and redo", is currently false in U2 and U3 on `main`.** On the patched branch those two paths are fixed, and the key fuzz found no mismatch. That is test evidence. The proofs still assume it.

## Proved, on the model only

Certified from clean by `scripts/certify.sh`, with no trust tags, skipped proofs or axioms in the include tree.

| Claim | Theorem |
|---|---|
| R. After any sequence, every record matches the text it will replay on | `claim-r-holds` |
| A. Undoing everything restores the starting text | `claim-a-holds` |
| B. If N groups can be undone, redoing N groups restores the text | `claim-b-holds` |
| C. One undo of a coalesced run gives the same text as one undo per edit of the same edits made separately | `claim-c-holds` |

## Tested only

- **The model behaves as the C does:** 3.1M steps, 0 disagreements, valid and invalid. Before the refactor, every invalid class disagreed. The model didn't change.
- **The C:** `make test` and sanitizers pass. No file-buffer, prompt or special-buffer history mismatch in 3,000 key-fuzz seeds.
- **Refcheck against `main`:** 257 of 2,000 seeds differ. All are attributed by rebuilding with one fix at a time: 221 to U2, 25 to U3, 11 to both, 0 to neither. I read only the minimised examples, not all 257.
- **Seeded bugs:** of 19 in the model, 9 make a claim false on the small domain, and each of those breaks a proof. 6 still certify. The other 4 fail only because my proof text mirrors the model, which is no evidence about the claims.

## Assumed

1. The model matches the C. Tested, not proved.
2. All text changes go through the modelled operations (above).
3. The history isn't cleared during the sequence.
4. The buffer isn't read-only and doesn't become so.
5. **At least one row, and no newline byte in a row.** False on `main` (register views, `*Completions*`). **On the patched branch no known exception.** Both are fixed and `EMIL_DEBUG_ROW_BYTES` aborts on a newline entering a row in sanitize and fuzz builds, not normal builds. That is test evidence, not proof. See `docs/undo-stage2.md`.
6. Replacement text is a list of bytes.
7. No `INT_MAX` overflow, and allocation succeeds.

**Not claimed at all:** the final-newline invariant ("repair skipped" still certifies), the cursor, mark, other windows' points, dirty flag, memory safety, and the ATC or C link. Nothing here proves the C correct.

**Known limitation:** if a record ever doesn't match the text, undo refuses and reports it, and stays stuck at that record until the history is cleared. It didn't occur in the last key fuzz.

## What proof found that the model tests and exhaustive checks didn't

- **No bug in the C or the model.** Every statement I proved was true as approved. The one false statement, in C's first draft, was caught by the exhaustive check, not by proof.
- **Assumption 5 got tested because the proof rests on it.** Equal text needs "no newline in a row". No generator made such a row, so the differential couldn't see it. I added the check to the key fuzz only for that reason, and the fuzz then found the filename case. Fuzz found it; proof pointed there.
- **R, A, B and C don't depend on merge policy.** They still certify with the limit changed and the append flag ignored. So the limit and burst handling are usability choices for these claims, and only the position shapes matter. Tests can't show that.
- **Why B holds:** a paired record heads the redo list only when the undo list is empty. No test named this invariant.
- **Generality:** any length and any text, against 3.1M steps and depth 4.

**Found by testing and review, not proof:** U1 to U3, the C-t crash, M-u past the row, the false `old_text` paths.

## Was it worth it?

**The model and differential test, yes:** with the history check on the key fuzz, they found all the defects. Keep them.

**The proofs, modestly.** They took about 30 minutes and about 45 certification runs, for 2,808 lines including 598 reused from the pilot. The reuse is why it was quick. They found no bug, as in the pilot. They do give a real result the tests can't: these properties hold for all sequences, on the model. But the risk here sat outside the model: in callers, unrecorded changes and malformed input. I wouldn't prove the next function of this kind by default. I'd write the model, the differential and the invariant check first, and prove only when a claim has to hold beyond what tests can reach.

## For you to decide

- Behaviour changes to accept: `docs/undo-stage2.md`, plus U2 (undo in a prompt now undoes TAB and `/`) and U3 (an edited special buffer's rebuild is undoable, and may gain a final empty row).
