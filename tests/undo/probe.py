#!/usr/bin/env python3
"""One invalid operation on "abc\\ndef\\n", then undo and redo, on emil's real C.
Shows what each class does.  Usage: probe.py DRIVER WORK_DIR"""
import os, re, subprocess, sys
drv, work = sys.argv[1], sys.argv[2]
START = "0 3\n3 97 98 99\n3 100 101 102\n0\n"
# kind 3 = mutateDelete, 2 = mutateInsert, 5 = extend, 6 = undo, 7 = redo
CASES = [
 ("valid delete (control)",      "3 1 0 2 0 0 0 0 0"),
 ("end x past row, same row",    "3 1 0 9 0 0 0 0 0"),
 ("end x past row, next row",    "3 1 0 9 1 0 0 0 0"),
 ("end row past last row",       "3 1 0 1 7 0 0 0 0"),
 ("reversed on one row",         "3 2 0 1 0 0 0 0 0"),
 ("reversed across rows",        "3 1 1 1 0 0 0 0 0"),
 ("start x past row",            "3 9 0 0 1 0 0 0 0"),
 ("start row past last row",     "3 0 7 0 8 0 0 0 0"),
 ("old_text differs from range", "3 1 0 2 0 0 0 1 0"),
 ("insert: x past row",          "2 9 0 9 0 0 0 0 1 120"),
 ("insert: y past last row",     "2 0 7 0 7 0 0 0 1 120"),
 ("extend: from_row wrong",      "5 1 0 0 0 1 0 0 0"),
]
def text(l):
    m = re.match(r"\((\d+) \(:[-A-Z]+ [^()]*\([^()]*\)\) -?\d+ -?\d+ -?\d+ -?\d+ (\(.*?\)\)|\(\)) ", l)
    if not m: return "?"
    rows = re.findall(r"\(([^()]*)\)", m.group(2)[1:-1])
    return "|".join("".join(chr(int(c)) if 32 <= int(c) < 127 else "\\x%02x" % int(c)
                    for c in r.split()) for r in rows)
print("| Case | Edit gives | Undo gives | Redo gives | Sanitizer |")
print("|---|---|---|---|---|")
for name, op in CASES:
    f = os.path.join(work, "case.ops")
    open(f, "w").write(START + op + "\n6 0 0 0 0 1 0 0 0\n7 0 0 0 0 1 0 0 0\n")
    r = subprocess.run([drv, "--replay", f, "--full-every", "1"], capture_output=True,
                       text=True, env=dict(os.environ, ASAN_OPTIONS="detect_leaks=0"))
    steps = [l for l in r.stdout.splitlines() if re.match(r"\(\d+ ", l)]
    got = [text(l) for l in steps] + ["crash"] * (3 - len(steps))
    m = re.search(r"(AddressSanitizer: [-a-z]+|runtime error: [a-z ]+)", r.stderr)
    print("| %s | `%s` | `%s` | `%s` | %s |" % (name, got[0], got[1], got[2], m.group(1) if m else "none"))
