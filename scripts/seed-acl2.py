#!/usr/bin/env python3
"""Vacuity check: seed bugs in copies of the ACL2 functions and confirm the proofs then fail.

Usage: seed-acl2.py TOOLS_DIR. Works in build/m3/seed. Each seeded version must fail to certify.
A proof can fail at a helper lemma before reaching a theorem, so this also runs the executable
statement check, which names an approved statement the bug makes false, where there is one."""
import os, re, shutil, subprocess, sys
tools = sys.argv[1]
here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = f"{here}/build/m3/seed"
M = [
 ("S1", "spec", "End-line column forgets the start column", "(list (+ sx (- x ex)) sy 0)", "(list (- x ex) sy 0)"),
 ("S2", "spec", "Later lines don't shift up after a deletion", "(t (list x (- y d) 0)))                 ; on a later line", "(t (list x y 0)))"),
 ("S3", "spec", "Clamped point returns 0", "((pos<= x y ex ey) (list sx sy 1))", "((pos<= x y ex ey) (list sx sy 0))"),
 ("S4", "spec", "Point at insertion moves with the text", "(cond ((pos<= x y sx sy) (list x y 0))          ; before, or exactly at", "(cond ((and (pos<= x y sx sy) (not (and (= x sx) (= y sy)))) (list x y 0))"),
 ("S5", "spec", "Same-line insert adds the end column", "((= y sy) (list (+ x (- ex sx)) (+ y d) 0))", "((= y sy) (list (+ x ex) (+ y d) 0))"),
 ("S6", "spec", "Later lines don't shift down after an insertion", "(t (list x (+ y d) 0))))))", "(t (list x y 0))))))"),
 ("S7", "spec", "Deletion model keeps the wrong suffix", "(nthcdr ex (nth ey tx))", "(nthcdr (+ ex 1) (nth ey tx))"),
 ("S8", "spec", "Overflow predicate ignores the end-line sum", "(in-int-p (+ sx (- x ex)) imax)", "t"),
 ("F1", "c", "adjust_new_x: end-line column forgets the start", "(c::add-sint-sint |startx| (c::sub-sint-sint |x| |endx|))", "(c::sub-sint-sint |x| |endx|)"),
 ("F2", "c", "adjust_new_y: later lines don't shift up", "(c::sub-sint-sint |y| |lines_delta|)", "|y|"),
 ("F3", "c", "adjust_clamped: inside returns 0", "(c::sint-dec-const 1)\n          (c::sint-dec-const 0)))", "(c::sint-dec-const 0)\n          (c::sint-dec-const 0)))"),
 ("F4", "c", "Guard drops the overflow predicate", "(adjust-no-overflow-p (c::integer-from-sint |x|) (c::integer-from-sint |y|)\n                              (c::integer-from-sint |startx|) (c::integer-from-sint |starty|)\n                              (c::integer-from-sint |endx|) (c::integer-from-sint |endy|)\n                              (c::boolean-from-sint |is_delete|) 2147483647)", "t"),
]
env = dict(os.environ, ACL2=f"{tools}/acl2/saved_acl2", ACL2_CUSTOMIZATION="NONE")
print("| ID | Seeded bug | Result | Approved statement made false | First event to fail |\n|---|---|---|---|---|")
bad = 0
for mid, kind, desc, old, new in M:
    d = f"{W}/{mid}"
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for sub in ("claims", "c-link"):
        os.makedirs(f"{d}/{sub}")
        for f in os.listdir(f"{here}/acl2/{sub}"):
            if f.endswith((".lisp", ".acl2")):
                shutil.copy(f"{here}/acl2/{sub}/{f}", f"{d}/{sub}/{f}")
    target = f"{d}/claims/spec.lisp" if kind == "spec" else f"{d}/c-link/functions.lisp"
    t = open(target).read()
    if old not in t:
        sys.exit(f"{mid}: pattern not found")
    open(target, "w").write(t.replace(old, new, 1))
    fails = []
    false_claim = "-"
    if kind == "spec":
        subprocess.run([f"{tools}/acl2/books/build/cert.pl", "--acl2", env["ACL2"], "statements.lisp"],
                       cwd=f"{d}/claims", env=env, capture_output=True, text=True, timeout=900)
        so = open(f"{d}/claims/statements.cert.out", errors="replace").read() if os.path.exists(f"{d}/claims/statements.cert.out") else ""
        m = re.search(r"CLAIM FAILS:\s*([A-Z0-9-]+)", so)
        if m:
            false_claim = "`" + m.group(1).lower() + "`"
    for book, sub in (("proofs", "claims"), ("functions", "c-link")):
        r = subprocess.run([f"{tools}/acl2/books/build/cert.pl", "--acl2", env["ACL2"], f"{book}.lisp"],
                           cwd=f"{d}/{sub}", env=env, capture_output=True, text=True, timeout=900)
        if r.returncode:
            path = f"{d}/{sub}/{book}.cert.out"
            out = open(path, errors="replace").read() if os.path.exists(path) else ""
            m = re.search(r"ACL2 Error \[?[A-Za-z]*\]? ?in \( ?(?:DEFTHM|DEFUN|DEFUND) ([^ ]+)", out)
            fails.append(f"{book}: `{m.group(1) if m else 'see log'}`")
    if not fails:
        bad += 1
    print(f"| {mid} | {desc} | {'caught' if fails else '**NOT CAUGHT**'} | {false_claim} | {'; '.join(fails) or '-'} |", flush=True)
sys.exit(1 if bad else 0)
