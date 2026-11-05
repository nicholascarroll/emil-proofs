# emil-proofs: pilot of ACL2 + ATC on emil's `adjustPoint`

Tests the whole pipeline, and tests whether proof adds anything over strong
testing for this class of function. It may turn out that it doesn't. That's a
valid and useful result, so don't oversell it.

The full brief is in `docs/brief.md`. Current state and next step are in
`docs/status.md`. **A fresh session starts by reading both.**

## Resuming in a fresh session

1. `scripts/setup.sh` rebuilds the pinned toolchain (`scripts/versions.env`).
2. Read `docs/status.md`, then continue from "Next step".
3. The workspace is temporary. GitHub is the only durable copy: commit and push
   to the working branch after each meaningful step.

## Roles

- The owner is learning C and ACL2 and owns the claims. Claude writes models,
  code and proofs. The owner reviews theorem statements.
- Explain each theorem in plain English, including what it doesn't cover.
- Correct the owner directly if they are wrong.

## Rules

- emil is read-only. Use a separate clone, record the commit, change nothing.
- If network access blocks something, tell the owner. Don't try ways around it.
- Run long certification in the background, logging to a file. Don't assume a
  background job survives once a reply ends.
- Don't commit large toolchains or build output.
- A theorem may not rely on `skip-proofs`, `defaxiom`, trust tags, uncertified
  books or fast-cert. Certify from clean with a single script, which fails if
  any appear. If one seems necessary, stop and ask.
- Owner-approved exception (2026-11-06): books that run ATC may use exactly the
  trust tags in `scripts/atc-allowed-ttags.txt`, because ATC requires them. Spec
  and claim books stay tag-free. Other tags, skipped proofs and axioms still fail.
- Don't weaken a theorem to get a proof through. If it needs a new hypothesis or
  a narrower claim, tell the owner and explain why.
- Check for vacuity: show the hypotheses can be satisfied, and seed bugs in the
  ACL2 function to confirm the theorems then fail.
- Keep the claims ledger in `docs/claims.md`: each claim, formal theorem name,
  evidence type (proved, tested or assumed), assumptions, owner review status.
- Never say "correct" or "safe" without saying which claim and which assumptions.
- If proofs stall, report where and what was tried. Honest failure data is a
  useful result.
- Any difference found in Milestone 4 is a finding. Report it rather than
  adjusting things until it goes away.
- Any new specification decision goes in the ledger.

## Stop points

- **Stop for owner review after Milestone 0 and at Milestone 2.**
- If ATC can't express the function reasonably, stop and give options.
- Don't go beyond Milestone 5. Don't swap anything into emil.
- Record effort per stage, proof iterations, stalls and certification times as
  you go, for `docs/verdict.md`.
- `docs/verdict.md` must list both ATC findings as evidence of what ATC costs in
  practice: the write-on-every-path requirement and the `:alloc` hypothesis.
- Before Milestone 1, finish the owner-requested pointer-free prototype. See the
  decisions in `docs/claims.md`.
