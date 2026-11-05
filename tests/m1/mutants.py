#!/usr/bin/env python3
"""Seed plausible bugs into copies of emil's adjust.c and see what catches them.

Usage: mutants.py EMIL_DIR BUILD_DIR HARNESS_C STUB_C [EMIL_COPY_DIR]
With EMIL_COPY_DIR, also links each mutant into emil's own tests/test_adjust.c.
Each mutant must change the source, or this script fails.
"""
import os, re, subprocess, sys
emil, build, harness, stub = sys.argv[1:5]
copy = sys.argv[5] if len(sys.argv) > 5 else None
src = open(f"{emil}/adjust.c").read()
BEFORE = "*px <= startx"

# (id, kind, description, old text, new text, which occurrence)
M = [
 ("M01", "del", "Point at deletion start treated as inside", BEFORE, "*px < startx", 0),
 ("M02", "del", "Point at deletion end not treated as inside", "*px <= endx", "*px < endx", 0),
 ("M03", "ins", "Point at insertion moves with the text (emil's old Spec 05 P2 bug)", BEFORE, "*px < startx", 1),
 ("M04", "del", "End-line column forgets the start column", "*px = startx + (*px - endx);", "*px = *px - endx;", 0),
 ("M05", "del", "End-line point keeps its old line", "*px = startx + (*px - endx);\n\t\t\t*py = starty;", "*px = startx + (*px - endx);", 0),
 ("M06", "del", "Later lines don't shift up", "*py -= lines_delta;", "", 0),
 ("M07", "del", "Later lines shift by one too many", "*py -= lines_delta;", "*py -= lines_delta + 1;", 0),
 ("M08", "equiv", "Multi-line insert uses the single-line column formula (not a bug: same arithmetic)", "*px = endx + (*px - startx);", "*px += (endx - startx);", 0),
 ("M09", "ins", "Multi-line insert forgets the line on the insertion line", "*px = endx + (*px - startx);\n\t\t\t\t*py += lines_delta;", "*px = endx + (*px - startx);", 0),
 ("M10", "ins", "Later lines don't shift down", "/* Point is after the insertion line */\n\t\t*py += lines_delta;", "/* Point is after the insertion line */", 0),
 ("M11", "del", "Clamp swaps x and y", "*px = startx;\n\t\t\t*py = starty;", "*px = starty;\n\t\t\t*py = startx;", 0),
 ("M12", "del", "Any point on the end line treated as inside", "*py < endy || (*py == endy && *px <= endx)", "*py <= endy", 0),
 ("M13", "ins", "Same-line insert adds the end column, not the length", "*px += (endx - startx);", "*px += endx;", 0),
 ("M14", "del", "Clamped point returns 0", "return 1;", "return 0;", 0),
 ("M15", "big", "Line delta truncated to 8 bits (wrong only for 128+ lines)", "int lines_delta = endy - starty;", "int lines_delta = (signed char)(endy - starty);", 0),
 ("M17", "ins", "Multi-line insert forgets the end column", "*px = endx + (*px - startx);", "*px = *px - startx;", 0),
 ("M18", "del", "Multi-line deletion misses points on its start line", "*py < endy || (*py == endy && *px <= endx)", "(*py < endy && *py > starty) || (*py == endy && *px <= endx)", 0),
 ("M19", "del", "End-line point after deletion clamped when on the end column plus one", "*px <= endx)", "*px <= endx + 1)", 0),
 ("M16", "big", "End-line column truncated to 16 bits (wrong only past 32767)", "*px = startx + (*px - endx);", "*px = (short)(startx + (*px - endx));", 0),
]

def apply(old, new, n):
    i = -1
    for _ in range(n + 1):
        i = src.find(old, i + 1)
        if i < 0:
            sys.exit(f"pattern not found: {old!r}")
    return src[:i] + new + src[i + len(old):]

def cc(*a):
    r = subprocess.run(["gcc", "-std=c99", "-D_DEFAULT_SOURCE", "-O2", "-w", f"-I{emil}", *a],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr)

os.makedirs(f"{build}/mut", exist_ok=True)
cc("-c", stub, "-o", f"{build}/mut/stub.o")
cc("-c", harness, "-o", f"{build}/mut/harness.o")
print("| ID | Seeded bug | Exhaustive harness (failing checks) | Emil's test_adjust |")
print("|---|---|---|---|")
survivors = []
for mid, kind, desc, old, new, n in M:
    text = apply(old, new, n)
    assert text != src
    p = f"{build}/mut/{mid}.c"
    open(p, "w").write(text)
    cc("-c", p, "-o", f"{build}/mut/{mid}.o")
    cc(f"{build}/mut/harness.o", f"{build}/mut/{mid}.o", f"{build}/mut/stub.o", "-o", f"{build}/mut/{mid}")
    r = subprocess.run([f"{build}/mut/{mid}"], capture_output=True, text=True)
    m = re.search(r"failures=(\d+)", r.stdout.split("texts=")[-1]) if "texts=" in r.stdout else None
    fails = int(m.group(1)) if m else -1
    caught = r.returncode != 0
    theirs = "not run"
    if copy:
        cc("-c", p, "-o", f"{copy}/adjust.o")
        cc2 = subprocess.run(["sh", f"{os.path.dirname(harness)}/link_test_adjust.sh", copy, f"{build}/mut/{mid}-emiltest"],
                             capture_output=True, text=True)
        if cc2.returncode:
            sys.exit(cc2.stdout + cc2.stderr)
        t = subprocess.run([f"{build}/mut/{mid}-emiltest"], capture_output=True, text=True, cwd=copy, timeout=120)
        fm = re.findall(r"^(?:\S*test\S*).*FAIL|FAIL", t.stdout, re.M)
        tm = re.search(r"(\d+) Tests (\d+) Failures", t.stdout)
        theirs = (f"caught ({tm.group(2)} of {tm.group(1)} tests)" if t.returncode and tm else
                  ("caught" if t.returncode else "**missed**"))
    if not caught:
        survivors.append(mid)
    print(f"| {mid} | {desc} | {'caught (' + format(fails, ',') + ')' if caught else '**missed**'} | {theirs} |")
print()
print("harness survivors:", " ".join(survivors) or "none")
