| Bug seeded in the model | Claims false on the small domain | Proofs |
|---|---|---|
| merge limit 19 | none | certify |
| repair record not paired | none | fail in history: DEFTHM REPAIR-OK |
| backspace appends | C | fail in history: DEFTHM MERGE-SHAPE-DEL |
| undo ignores saved point | none | certify |
| redo doesn't carry point | none | certify |
| delete ignores chain | none | fail in history: DEFTHM EDIT-IS-CORE |
| final newline delete allowed | none | certify |
| burst ignored | none | fail in history: DEFTHM EDIT-IS-CORE |
| undo leaves run open (expected equivalent) | none | fail in history: DEFTHM UNDO-STEP-LISTS |
| merge ignores append flag | none | certify |
| edit keeps redo | B1, R | fail in history: DEFTHM EDIT-IS-CORE |
| extend anchored a row early | A, R | fail in history: DEFTHM EXTEND-OK |
| repair skipped | none | certify |
| insert end off by one | A, B1, B2, R | fail in text: DEFTHM END-AFTER-INSERT-DATA |
| merge at any position | A, B1, B2, R | fail in history: DEFTHM MERGE-SHAPE-INS |
| delete record's data wrong | A, B1, B2, C, R | fail in history: DEFTHM EDIT-IS-CORE |
| redo applies only first of group | B1, B2 | fail in redo: DEFTHM ZIPPER-REDO-REST |
| undo stops after first of group | B1, B2 | fail in redo: DEFTHM ZIPPER-UNDO-GROUP |
| repair replaces instead of inserting | B1, B2, R | fail in history: DEFTHM REPAIR-OK |
