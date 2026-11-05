# ATC proof-generation failures (not certified, back no claim)

Kept so the failures can be reproduced at the pinned ACL2 commit. Load each with
the portcullis included, for example:

    (include-book "kestrel/c/portcullis" :dir :system)
    (ld "conditional-write.lisp")

- `conditional-write.lisp`: minimal reproduction. A path that leaves a pointee
  unwritten while another path writes it fails at `<fn>-POP-FRAME`.
- `adjust-shape-b.lisp`: adjustPoint using locals and a single exit fails at
  `adjustPoint-px-IN-SCOPE-62`. The cause wasn't investigated, because shape A works.
- `struct-write-then-branch.lisp`: struct passed and returned by value, with a
  member written before the branches. Fails at `adjust_value-lines_delta-IN-SCOPE-26`.
- `struct-clamped-precondition.lisp`: the same, with that write removed and a guard
  requiring `clamped == 0`. Fails at `adjust_value-CORRECT-59`. Causes weren't
  investigated, because the three-function version works.
