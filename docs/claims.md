# Claims ledger

No claims proposed yet (Milestone 2).

| Claim | Formal theorem | Evidence | Assumptions | Owner review |
|---|---|---|---|---|

## Decisions

| Date | Decision | Applies to | Status |
|---|---|---|---|
| 2026-11-06 | ATC books may use exactly the trust tags `:quicklisp`, `:quicklisp.osicat`, `:oslib`, `:open-output-channel!`, `:file-io!`. This is an assumption behind every theorem ATC generates: code running under those tags is trusted. Whether they could affect a proof has not yet been checked. | Books that run ATC only. Spec and claim books stay tag-free. | Approved by owner |
