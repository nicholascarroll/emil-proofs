#!/usr/bin/env python3
"""Audit a certified book and everything it includes, using ACL2 itself.

.cert files are serialized, so they aren't parsed as text. ACL2 loads the book
with uncertified books, skip-proofs and axioms all refused, then prints the
annotations it records for every book in the include-book tree, including
local includes.

Usage: cert-audit.py BOOK.lisp --strict | --allow FILE    [--list]
Exit 0 only if every book passes. No books listed counts as a failure.
"""
import os, re, subprocess, sys, tempfile

args = sys.argv[1:]
book = os.path.abspath(args[0])
if book.endswith(".lisp"):
    book = book[:-5]
allow = set()
if "--allow" in args:
    with open(args[args.index("--allow") + 1]) as f:
        allow = {line.strip().upper() for line in f if line.strip()}
elif "--strict" not in args:
    sys.exit("need --strict or --allow FILE")
acl2 = os.path.join(os.environ.get("TOOLS_DIR", os.path.expanduser("~/tools")), "acl2/saved_acl2")

script = f'''
(set-fmt-hard-right-margin 1000000 state)
(set-fmt-soft-right-margin 1000000 state)
(include-book "{book}" :ttags :all :uncertified-okp nil :skip-proofs-okp nil :defaxioms-okp nil)
(defun audit-loop (al)
  (declare (xargs :mode :program))
  (if (endp al)
      nil
    (let* ((e (car al))
           (loc (and (consp e) (eq (car e) 'local)))
           (e (if loc (cadr e) e)))
      (prog2$ (cw "~%AUDIT|~x0|~x1|~x2~%" (car e) loc (cadddr e))
              (audit-loop (cdr al))))))
(audit-loop (global-val 'include-book-alist-all (w state)))
(cw "AUDIT-DONE~%")
'''
env = dict(os.environ, ACL2_CUSTOMIZATION="NONE")
out = subprocess.run([acl2], input=script, capture_output=True, text=True, env=env).stdout
if "AUDIT-DONE" not in out or "ACL2 Error" in out:
    print(out[-1500:])
    print(f"AUDIT FAILED: could not load {book}")
    sys.exit(1)

rows = [l.split("|", 3) for l in out.splitlines() if l.startswith("AUDIT|")]
tags_seen, bad = {}, []
for _, path, _loc, ann in rows:
    a = re.sub(r"\s+", " ", ann).upper()
    a = re.sub(r'"[^"]*"', '""', a)
    if ":SKIPPED-PROOFSP" not in a or ":AXIOMSP" not in a or ":TTAGS" not in a:
        bad.append(f"{path}: annotations missing")
        continue
    if not re.search(r"\(:SKIPPED-PROOFSP( \. NIL|\))", a):
        bad.append(f"{path}: skipped proofs")
    if not re.search(r"\(:AXIOMSP( \. NIL|\))", a):
        bad.append(f"{path}: axioms")
    # Each entry is (:TAG (:SYSTEM . "book") ...); :SYSTEM is a path key, not a tag
    ttags = re.sub(r':SYSTEM \. ""', '', a[a.index(":TTAGS") + 6:])
    for t in set(re.findall(r":[^\s()\"]+", ttags)):
        tags_seen.setdefault(t, []).append(path)
        if t not in allow:
            bad.append(f"{path}: trust tag {t}")
print(f"{book}: {len(rows)} books in include tree")
for t in sorted(tags_seen):
    print(f"  tag {t}: {len(tags_seen[t])} books")
if not rows:
    bad.append("no books listed")
if "--list" in args:
    for _, path, _loc, ann in rows:
        print("   ", path, re.sub(r"\s+", " ", ann)[:160])
for b in bad[:20]:
    print("  VIOLATION", b)
sys.exit(1 if bad else 0)
