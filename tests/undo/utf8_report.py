#!/usr/bin/env python3
"""Summarise fuzz_utf8.sh runs. Usage: utf8_report.py WORK_DIR [F6_LOG]"""
import collections, re, sys

work = sys.argv[1]
ALPHA = {"c3", "f0", "e282", "f09f"}  # the truncated tails the harness adds


def bad_runs(b):
    """Maximal runs of bytes that aren't part of a valid UTF-8 sequence."""
    out, i, cur = [], 0, b""
    while i < len(b):
        n = 1 if b[i] < 0x80 else 2 if 0xC2 <= b[i] <= 0xDF else 3 if 0xE0 <= b[i] <= 0xEF else 4 if 0xF0 <= b[i] <= 0xF4 else 0
        ok = False
        if n:
            try:
                b[i:i + n].decode("utf-8")
                ok = len(b[i:i + n]) == n
            except UnicodeDecodeError:
                pass
        if ok:
            if cur:
                out.append(cur); cur = b""
            i += n
        else:
            cur += b[i:i + 1]; i += 1
    if cur:
        out.append(cur)
    return out


seeds, ended, leads, rows = set(), set(), {}, []
writes = collections.Counter(); refused = 0; firstkey = {}
for line in open(work + "/utf8.log", errors="replace"):
    w = line.split()
    if not w:
        continue
    if w[0] == "SEED":
        seeds.add(int(w[1]))
    elif w[0] == "END":
        ended.add(int(w[1]))
    elif w[0] == "LEAD":
        leads[int(w[1])] = (int(w[2]), w[3], line.split('"')[1])
    elif w[0] == "ROW":
        try:
            hx = bytes.fromhex(w[-1])
        except ValueError:
            continue
        rows.append((int(w[1]), int(w[2]), w[3], w[4], " ".join(w[5:-2]), hx))
    elif w[0] == "WRITE":
        writes["valid" if "valid=1" in line else "INVALID"] += 1
    elif w[0] == "REFUSED":
        refused += 1

printed = set()
try:
    for line in open(work + ".out", errors="replace"):
        m = re.match(r"seed (\d+) LEAD", line)
        if m:
            printed.add(int(m.group(1)))
except OSError:
    pass

print(f"seeds {len(seeds)}, ran out of keys {len(ended)}, ended early {len(seeds - ended)}")
print(f"seeds with a lead, logged {len(leads)}; printed by the fuzzer {len(printed)}; "
      f"logged but not printed {len(set(leads) - printed)}, of which ended early {len((set(leads) - printed) - ended)}")
print("lead kinds:", collections.Counter(v[2] for v in leads.values()).most_common())
lk = collections.Counter("key 1" if v[0] == 1 else "later" for s, v in leads.items() if s in printed)
print("printed leads by key:", dict(lk))
print("printed leads, buffer class of E.buf:", collections.Counter(leads[s][1] for s in printed if s in leads).most_common())

# Classify later-key printed leads: was the row present at start in that seed?
start_rows = collections.defaultdict(set)
for s, k, kn, cls, name, hx in rows:
    if k == 0:
        start_rows[s].add(hx)
print(f"invalid-row sightings {len(rows)}, seeds with any {len({r[0] for r in rows})}, at start {sum(1 for r in rows if r[1] == 0)}")
print("sightings by buffer class:", collections.Counter(r[3] for r in rows).most_common())
print("sightings by buffer name (specials):", collections.Counter(r[4] for r in rows if r[3] == "special").most_common(8))

cause = collections.Counter(); byclass = collections.defaultdict(collections.Counter); new = []
for r in rows:
    s, k, kn, cls, name, hx = r
    runs = {x.hex() for x in bad_runs(hx)}
    if k == 0:
        c = "A loaded as-is by the harness, before any key"
    elif runs <= ALPHA:
        c = "B an injected truncated tail, carried by an edit or a copy"
    elif all(any(x.startswith(a) or a.startswith(x) or x in a or a in x for a in ALPHA) for x in runs):
        c = "C part of an injected tail, or tails joined"
    else:
        c = "D bytes not traceable to an injected tail"
        new.append(r)
    cause[c] += 1
    byclass[c][cls] += 1
for c, n in sorted(cause.items()):
    print(f"  {c}: {n}  {dict(byclass[c])}")
kinds = collections.Counter(k for r in new for k in [r[2]])
print("D by key:", kinds.most_common(12))
print("D seeds:", len({r[0] for r in new}))
for r in new[:12]:
    print("   D", r[0], r[1], r[2], r[3], r[4][:20], r[5].hex()[:70], [x.hex() for x in bad_runs(r[5])][:4])
print("file writes:", dict(writes), "refused saves:", refused)
kept = [r for r in rows if r[3] in ("file", "unnamed-then-named")]
print("seeds with invalid rows in a named file buffer:", len({r[0] for r in kept}))
