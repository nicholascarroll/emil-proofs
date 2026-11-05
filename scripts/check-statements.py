#!/usr/bin/env python3
"""Fail unless every approved statement is proved exactly as approved.

Compares each DEFCLAIM in acl2/claims/statements.lisp with the DEFTHM of the same name in
acl2/claims/proofs.lisp, ignoring whitespace and comments and any :hints or :rule-classes.
A DEFTHM must be (implies HYP CONCL), with HYP and CONCL as approved. A statement with
HYP t may be the bare conclusion.
"""
import re, sys
here = sys.argv[1] if len(sys.argv) > 1 else "."

def strip(t):
    return re.sub(r";[^\n]*", "", t)

def forms(t, head):
    out = {}
    for m in re.finditer(r"\(" + head + r"\s+([^\s()]+)", t):
        d, i = 0, m.start()
        j = i
        while True:
            if t[j] == "(":
                d += 1
            elif t[j] == ")":
                d -= 1
                if d == 0:
                    break
            j += 1
        out[m.group(1)] = t[i : j + 1]
    return out

def sexps(t):
    """Top-level s-expressions inside the outer parens of a form."""
    t = t.strip()[1:-1]
    res, i = [], 0
    while i < len(t):
        if t[i].isspace():
            i += 1
        elif t[i] == "(":
            d, j = 0, i
            while True:
                if t[j] == "(":
                    d += 1
                elif t[j] == ")":
                    d -= 1
                    if d == 0:
                        break
                j += 1
            res.append(t[i : j + 1])
            i = j + 1
        else:
            j = i
            while j < len(t) and not t[j].isspace() and t[j] not in "()":
                j += 1
            res.append(t[i:j])
            i = j
    return res

norm = lambda s: re.sub(r"\(\s+", "(", re.sub(r"\s+\)", ")", re.sub(r"\s+", " ", s))).strip().lower()
claims = forms(strip(open(f"{here}/acl2/claims/statements.lisp").read()), "defclaim")
proofs = forms(strip(open(f"{here}/acl2/claims/proofs.lisp").read()), "defthm")
bad = 0
for name, c in claims.items():
    _, _, _vars, hyp, concl = sexps(c)
    if name not in proofs:
        print("NOT PROVED:", name); bad += 1; continue
    body = sexps(proofs[name])[2]
    want = concl if hyp.strip() == "t" else f"(implies {hyp} {concl})"
    if norm(body) != norm(want):
        print("DIFFERS:", name); print(" approved:", norm(want)[:300]); print(" proved:  ", norm(body)[:300]); bad += 1
print(f"statements checked: {len(claims)}, differences: {bad}")
sys.exit(1 if bad or not claims else 0)
