#!/usr/bin/env python3
"""Print the trust annotations ACL2 records in a .cert file.

ACL2 stores (:SKIPPED-PROOFSP ..) (:AXIOMSP ..) (:TTAGS ..) in every certificate,
and these cover included books too. With --strict, exit 1 if any is non-nil.
"""
import re, sys
path = sys.argv[1]
strict = "--strict" in sys.argv
text = open(path, errors="replace").read()

def field(name):
    """Return the balanced s-expression following the last (:NAME in the header."""
    m = re.search(r"\(:%s\b" % name, text, re.I)
    if not m:
        return None
    i, depth = m.start(), 0
    for j in range(i, len(text)):
        if text[j] == "(":
            depth += 1
        elif text[j] == ")":
            depth -= 1
            if depth == 0:
                return re.sub(r"\s+", " ", text[m.end():j]).strip(" .")
    return None

vals = {k: field(k) for k in ("SKIPPED-PROOFSP", "AXIOMSP", "TTAGS")}
print(path)
bad = False
for k, v in vals.items():
    if v is None:
        print(f"  {k}: NOT FOUND IN CERT")
        bad = True
    else:
        print(f"  {k}: {v or 'none'}")
        if v.upper() not in ("", "NIL"):
            bad = True
sys.exit(1 if strict and bad else 0)
