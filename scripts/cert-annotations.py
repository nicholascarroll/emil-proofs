#!/usr/bin/env python3
"""Check the trust annotations ACL2 records in a .cert file.

ACL2 stores (:SKIPPED-PROOFSP ..) (:AXIOMSP ..) (:TTAGS ..) in every certificate,
and these cover included books too.

  --strict         exit 1 on any skipped proof, axiom or trust tag
  --allow FILE     as --strict, except tags listed in FILE are permitted
With neither, only report. A missing annotation always counts as a violation.
"""
import re, sys

args = sys.argv[1:]
path = args[0]
strict = "--strict" in args
allow = None
if "--allow" in args:
    with open(args[args.index("--allow") + 1]) as f:
        allow = {line.strip().upper() for line in f if line.strip()}
text = open(path, errors="replace").read()


def field(name):
    """Return the text inside the first balanced (:NAME ...) form, or None."""
    m = re.search(r"\(:%s\b" % name, text, re.I)
    if not m:
        return None
    depth, in_str = 0, False
    for j in range(m.start(), len(text)):
        c = text[j]
        if in_str:
            if c == '"' and text[j - 1] != "\\":
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return re.sub(r"\s+", " ", text[m.end():j]).strip(" .")
    return None


def is_nil(v):
    return v.upper() in ("", "NIL")


print(path)
bad = []
for k in ("SKIPPED-PROOFSP", "AXIOMSP"):
    v = field(k)
    print(f"  {k}: {'NOT FOUND' if v is None else (v if not is_nil(v) else 'none')}")
    if v is None or not is_nil(v):
        bad.append(k)

raw = field("TTAGS")
if raw is None:
    print("  TTAGS: NOT FOUND")
    bad.append("TTAGS")
else:
    no_strings = re.sub(r'"[^"]*"', '""', raw)
    tags = sorted({t.upper() for t in re.findall(r":[^\s()\"]+", no_strings)})
    print(f"  TTAGS: {' '.join(tags) or 'none'}")
    extra = [t for t in tags if allow is None or t not in allow]
    if extra:
        bad.append("TTAGS not allowed: " + " ".join(extra))

if bad:
    print("  VIOLATIONS: " + "; ".join(bad))
sys.exit(1 if bad and (strict or allow is not None) else 0)
