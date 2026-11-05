# Claims ledger

No claims proposed yet (Milestone 2).

| Claim | Formal theorem | Evidence | Assumptions | Owner review |
|---|---|---|---|---|

## Decisions

| Date | Decision | Applies to | Status |
|---|---|---|---|
| 2026-11-06 | ATC books may use only trust tags the owner approved: `:quicklisp`, `:quicklisp.osicat`, `:oslib`, `:file-io!`. The owner approved a fifth, `:open-output-channel!`, but it never appears, so it was removed from the allowlist. This is an assumption behind every theorem ATC generates: tagged code runs in the prover's image and is trusted not to interfere. See `docs/atc-reality-check.md`. | Books that run ATC only. Spec and claim books stay tag-free. | Approved by owner |
| 2026-11-06 | Proposed: generated C uses shape A, with write-backs on unchanged paths. | Milestone 3 C generation | Awaiting owner review |
| 2026-11-06 | Proposed: record as an assumption that the generated theorem's `:alloc` result also holds for `:member` and `:auto` objects, and test it at Milestone 4 with real struct members and locals. | Every statement about generated C reached from emil's callers | Awaiting owner review |
