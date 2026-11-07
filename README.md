# emil-proofs

Proofs about the [emil](https://github.com/nicholascarroll/emil) text editor
using the [ACL2](https://www.cs.utexas.edu/~moore/acl2/) prover.

## The Undo System

On the [`undo-model`](../../tree/undo-model) branch, four properties of emil's
undo and redo are proved for **every** sequence of edits, undos and redos, of
any length and on any text:

| Claim | Theorem |
|---|---|
| **R.** Every undo and redo record matches the text it will be replayed on | `claim-r-holds` |
| **A.** Undoing everything restores the starting text | `claim-a-holds` |
| **B.** If N groups can be undone, redoing N groups restores the text | `claim-b-holds` |
| **C.** One undo of a coalesced typing run equals one undo per edit | `claim-c-holds` |

They certify from clean with no trust tags, skipped proofs or axioms.

Those theorems are about an ACL2 model of emil's undo history, not its C. 
The model is checked against the C by differential testing (3.1 million steps, 0 disagreements). 
The proofs also rest on stated assumptions listed in
[`docs/undo-report.md`](../../blob/undo-model/docs/undo-report.md).

The proven commit added 15 patches to emil's undo code, in `patches/undo-refactor/`.

## Branches

Each branch builds on the one before, so `undo-model` contains everything.

| Branch | What's there |
|---|---|
| [`milestone-0`](../../tree/milestone-0) | Pinned ACL2 toolchain, and a reality check of ATC (ACL2 to C) on emil's `adjustPoint` |
| [`milestone-2`](../../tree/milestone-2) | Exhaustive testing baseline, seeded bugs, and theorem statements for `adjustPoint` |
| [`milestone-3`](../../tree/milestone-3) | `adjustPoint` proofs, ATC-generated C, comparison with emil's C, and the pilot's verdict |
| [`undo-model`](../../tree/undo-model) | The undo model, the four proofs above, and the emil patches |

# adjustPoint
Proving this was the first experiment with this approach, and it concluded that strong
testing was enough for that kind of function. Its verdict is in
[`docs/verdict.md`](../../blob/milestone-3/docs/verdict.md).

it proves the active cursor always lands in the right place, but it doesn't prove that the parked cursor positions in other windows are being moved to the right position.

# other important areas for correctness in emil
These are *not* planned to be proven with ACL2:
- unicode.c: this was proven in an earlier commit with [CBMC](https://www.cprover.org/cbmc/) 
- Memory safety, especially the use of int for sizes and capacities.
- A guarantee that rendered text is always sanitised so that that malicious file content cannot send commands to the terminal

## Licence

MIT. See `LICENSE`.
