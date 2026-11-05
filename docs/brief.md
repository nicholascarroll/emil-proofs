Run a pilot of ACL2 + ATC (ACL2 To C, from Kestrel) on one small function:
adjustPoint from emil, my C99 terminal text editor
(github.com/nicholascarroll/emil, adjust.c and adjust.h, MIT licence). The
pilot tests the whole pipeline, and tests whether proof adds anything over
strong testing for this class of function. It may turn out that it doesn't.
That's a valid and useful result, so don't oversell it.

WORKSPACE
Attach OWNER/emil-proofs with push access and clone it. Read emil from a separate
read-only clone, record the commit used, and don't change emil. This session
runs in a temporary cloud workspace, so GitHub is the only durable copy:
- Commit and push to a working branch after each meaningful step. A fresh session
  must always be able to continue from CLAUDE.md and docs/status.md.
- Add a setup script that rebuilds the toolchain with pinned versions, and
  confirm that it works.
- Network access may be limited to package registries and GitHub. Use those for
  SBCL and ACL2, such as cloning ACL2 from GitHub. If something is blocked, tell
  me rather than trying ways around it.
- Run long certification jobs in the background, with output logged to a file.
  Don't assume a background job survives once your reply ends.
- Don't commit large toolchains or build output.

MY ROLE
I'm learning C and ACL2, and I own the claims. You write the models, code and
proofs. I review theorem statements. Explain each in plain English, including
what it doesn't cover. Correct me directly if I'm wrong.

MILESTONE 0: TOOLCHAIN AND ATC REALITY CHECK
- Install SBCL and ACL2, and certify a trivial book.
- Read the current ATC manual and source in the ACL2 community books. Record what
  it supports now: types, pointers, structs, loops, and multiple outputs. Don't
  rely on the 2022 paper alone.
- Generate and compile one tiny C function with ATC.
- Decide how adjustPoint's two pointer in/out parameters and its return value
  should be represented in ATC's C subset. Write down any differences in shape
  from emil's function.
Report what you found. If ATC can't express this function reasonably, stop and
tell me, with options.

MILESTONE 1: TESTING BASELINE (BEFORE ANY PROOF)
- Write an exhaustive test harness for emil's actual C adjustPoint, against a
  simple executable text model, covering every valid point and edit on all small
  buffers, up to about 4 lines of 4 characters. Choose bounds that run in
  reasonable time, and state them.
- Test the intended property, including insertions, deletions, multi-line edits
  and every boundary.
- Seed about 10 plausible bugs into a copy of the function, and record which the
  harness catches.
- Check the function against tests/test_adjust.c and the comments in adjust.h.
- Report anything unexpected.

MILESTONE 2: CLAIMS (STOP FOR MY REVIEW)
Show me proposed theorem statements, before proving them, for:
1. Character preservation: in an ACL2 model of text as a list of lines, after
   any valid insertion or deletion, a point outside the edit still refers to the
   same character.
2. Exact boundaries: what happens to a point exactly at an insertion, inside a
   deletion, or at a deletion's end, as documented in adjust.h. In particular,
   state where "same character" stops being true.
3. Validity: a valid point stays valid in the edited text.
4. Arithmetic safety: the exact input bounds under which no signed overflow can
   occur. Trace emil's real callers, and tell me whether emil actually guarantees
   those bounds. Don't assume it does.
Say what each theorem assumes, and how the model differs from emil's real buffer.
Any new specification decision goes in the ledger.

MILESTONE 3: PROOF AND C GENERATION
After I approve the statements:
- Prove them in ACL2, against a readable spec version of adjustPoint.
- Write the C-shaped ACL2 for ATC, prove it equivalent to the spec, and generate
  the C.
- Explain exactly what ATC's generated theorems establish, and what's trusted:
  Kestrel's C model, the pretty-printer, the compiler, the hardware, ACL2 and its
  host Lisp, and callers meeting the hypotheses.

MILESTONE 4: THE GENERATED C MEETS EMIL
- Compile the generated function with a thin adapter if needed, with warnings and
  sanitizers on.
- Differentially test it against emil's adjustPoint, exhaustively on the Milestone
  1 domain and with random large values within the proven bounds.
- Compare generated code size and speed at -O2. Any difference is a finding, so
  report it rather than adjusting things until it goes away.
- Report what would be needed to swap it into emil, but don't do it.

MILESTONE 5: VERDICT
Write docs/verdict.md, answering plainly:
- What did the proof or spec work reveal that the exhaustive test didn't?
- Was any of this close to trivial? Which parts?
- Hours or effort per stage, proof iterations, where proofs stalled, and how long
  certification takes.
- How readable and usable is the generated C?
- Would proving this class of function be worth it, or is small-scope exhaustive
  testing enough?
- Would a claim about arbitrary sequences of edits and undos be a better next
  target? Explain, but don't start it.

RULES
- A theorem may not rely on skip-proofs, defaxiom, trust tags, uncertified books
  or fast-cert. Certify from clean with a single script, and have it fail if any
  appear. If you believe one is needed, stop and ask.
- Don't weaken a theorem to get a proof through. If it needs a new hypothesis or
  narrower claim, tell me and explain why.
- Check for vacuity: show the hypotheses can be satisfied, and seed bugs in the
  ACL2 function to confirm that the theorems then fail.
- Keep a claims ledger in docs/claims.md: each claim, formal theorem name,
  evidence type (proved, tested or assumed), assumptions, and my review status.
- Never say "correct" or "safe" without saying which claim and which assumptions.
- If the proofs stall, report where and what you tried. Honest failure data is a
  useful result.
- Stop for my review after Milestone 0 and at Milestone 2. Don't go beyond
  Milestone 5.

Start by creating CLAUDE.md with these rules and docs/status.md for progress,
then begin Milestone 0.
