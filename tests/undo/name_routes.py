#!/usr/bin/env python3
"""Open, edit and save files whose names aren't valid text, in a real emil.

Usage: name_routes.py EMIL_REPO COMMIT WORK_DIR
Exports COMMIT, adds a logger at the top of refreshScreen that records any row, in any
buffer, holding a newline or invalid UTF-8, builds a normal emil, and drives it through a
pty. Each scenario also checks the bytes sent to the terminal and the files on disk.
"""
import fcntl, os, pty, re, select, signal, struct, subprocess, sys, termios, time

repo, commit, work = sys.argv[1:4]
src = os.path.join(work, "src")
os.makedirs(src)
subprocess.check_call(f"git -C {repo} archive {commit} | tar -x -C {src}", shell=True)
p = os.path.join(src, "display.c")
s = open(p).read()
hook = r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "unicode.h"
static void nameLogBuf(FILE *f, struct buffer *b, const char *cls) {
	for (int i = 0; i < b->numrows; i++) {
		erow *r = &b->row[i];
		int nl = r->size > 0 && memchr(r->chars, '\n', r->size) != NULL;
		if (!nl && utf8_validate(r->chars, r->size))
			continue;
		fprintf(f, "BAD %s nl=%d ", cls, nl);
		for (int k = 0; k < r->size; k++)
			fprintf(f, "%02x", r->chars[k]);
		fprintf(f, "\n");
	}
}
static void nameLog(void) {
	const char *lg = getenv("NAME_LOG");
	FILE *f = lg ? fopen(lg, "a") : NULL;
	if (!f)
		return;
	for (struct buffer *b = E.headbuf; b; b = b->next)
		nameLogBuf(f, b, b->special_buffer ? "special" : "file");
	if (E.minibuf)
		nameLogBuf(f, E.minibuf, "minibuffer");
	if (E.buf && E.buf->filename) {
		fprintf(f, "CUR ");
		for (const char *q = E.buf->filename; *q; q++)
			fprintf(f, "%02x", (unsigned char)*q);
		fprintf(f, "\n");
	}
	fclose(f);
}
'''
m = re.search(r"^void refreshScreen\(void\) \{\n", s, re.M)
assert m
s = s[:m.start()] + hook + s[m.start():m.end()] + "\tnameLog();\n" + s[m.end():]
open(p, "w").write(s)
subprocess.check_call(["make", "-j2", "emil"], cwd=src, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
emil = os.path.join(src, "emil")

CX = b"\x18"; CG = b"\x07"; RET = b"\r"; TAB = b"\t"; CQ = b"\x11"; CS = b"\x13"; CC = b"\x03"
GOOD = b"old\n"
NAMES = {"lf": b"qq\nyy", "esc": b"qq\x1b[31myy", "invalid": b"qq\xffyy"}
fails = 0


def forbidden(name):
    """Bytes of the name that must not reach the terminal as they are.  The pty turns a
    line feed into CR LF on the way out."""
    return name.replace(b"\n", b"\r\n")


def drive(tag, files, argv, keys, name, expect_files=None, expect_cur=None, limit=False):
    global fails
    d = os.path.join(work, "run", tag); os.makedirs(d)
    db = d.encode()
    for fn, data in files.items():
        with open(os.path.join(db, fn), "wb") as f:
            f.write(data)
    log = os.path.join(d, "name.log")
    env = dict(os.environ, NAME_LOG=log, TERM="xterm", HOME=d, LC_ALL="C.UTF-8")
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(d)
        os.execve(emil.encode(), [b"emil"] + argv, env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
    out = b""

    def pump(t):
        nonlocal out
        end = time.time() + t
        while time.time() < end:
            r, _, _ = select.select([fd], [], [], 0.05)
            if r:
                try:
                    out += os.read(fd, 65536)
                except OSError:
                    return

    pump(0.5)
    for k in keys:
        try:
            os.write(fd, k)
        except OSError:
            break
        pump(0.2)
    pump(0.2)
    w, st = os.waitpid(pid, os.WNOHANG)
    exited = os.waitstatus_to_exitcode(st) if w else None
    if not w:
        os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)
    os.close(fd)
    lines = open(log, "rb").read().decode().splitlines() if os.path.exists(log) else []
    bad = sorted({l for l in lines if l.startswith("BAD")})
    curs = [l[4:] for l in lines if l.startswith("CUR ")]
    raw_on_terminal = forbidden(name) in out
    problems = []
    if bad:
        problems.append(f"bad rows {bad[:3]}")
    if raw_on_terminal:
        problems.append("raw name reached the terminal")
    for fn, want in (expect_files or {}).items():
        have = open(os.path.join(db, fn), "rb").read() if os.path.exists(os.path.join(db, fn)) else None
        if have != want:
            problems.append(f"file {fn!r}: {have!r}, wanted {want!r}")
    if expect_files is not None:
        extra = set(os.listdir(db)) - set(expect_files) - {b"name.log"} - set(files)
        extra = {x for x in extra if not x.startswith(b".emil") and not x.endswith(b"~")}
        if extra:
            problems.append(f"extra files {sorted(extra)}")
    if expect_cur is not None and (not curs or curs[-1] != expect_cur.hex()):
        problems.append(f"current buffer {bytes.fromhex(curs[-1]) if curs else None!r}, wanted {expect_cur!r}")
    # A known limit: reported, not counted.
    label = "LIMIT" if limit and problems else "FAIL" if problems else "ok  "
    print(f"{label} {tag}: exit={exited} {'; '.join(problems)}")
    fails += bool(problems) and not limit


for k, n in NAMES.items():
    # Open by exact path, edit, save: the real path gets the text.
    drive(f"{k}-open-edit-save", {n: GOOD}, [n], [b"new", CX + CS], n, {n: b"newold\n"}, n)
    # A new file named on the command line.
    drive(f"{k}-new-file-save", {}, [n], [b"new", CX + CS], n, {n: b"new\n"}, n)
    # The default in the buffer prompt refers to the real buffer.
    drive(f"{k}-default-switch", {n: GOOD, b"other": GOOD}, [n, b"other"], [CX + b"b", RET], n, None, n)
    # Completed into the minibuffer: substituted text, which doesn't name the buffer.
    drive(f"{k}-completed-is-just-text", {n: GOOD, b"other": GOOD}, [n, b"other"],
          [CX + b"b", b"qq", TAB, RET, CG], n, None, None)
    # *Completions*, with two matches.
    drive(f"{k}-completions-list", {n: GOOD, b"qqz": GOOD, b"other": GOOD}, [n, b"qqz", b"other"],
          [CX + b"b", b"qq", TAB, TAB, CG], n)
    # Register view.
    drive(f"{k}-register-view", {n: GOOD}, [n], [CX + b"r ", b"a", CX + b"rV", b"a", CG], n)
    # Confirm prompts naming the file.
    drive(f"{k}-kill-confirm", {n: GOOD}, [n], [b"z", CX + b"k", RET, b"n"], n)
    drive(f"{k}-quit-confirm", {n: GOOD}, [n], [b"z", CX + CC, b"n", CG], n)
    # Failing to open at startup: main.c prints the name and the message.
    drive(f"{k}-startup-failure", {n: b"a\xff\n"}, [n], [], n)
    # Save as, typed.  Invalid UTF-8 can't be typed in a prompt.
    if k != "invalid":
        # One key at a time.  C-o makes the line feed.  C-q takes the next key, so an ESC
        # followed at once by [ would be read as a sequence: this name has a plain byte next.
        n2 = {"lf": n, "esc": b"qq\x1bzyy"}[k]
        typed = []
        for c in n2:
            if c == 0x0a:
                typed += [b"\x0f", b"\x06"]  # C-o leaves point before the line feed; C-f steps over
            elif c == 0x1b:
                typed += [CQ, bytes([c]), b"", b"", b"", b"", b""]  # let the ESC time out alone
            else:
                typed.append(bytes([c]))
        drive(f"{k}-save-as-typed", {b"f": GOOD}, [b"f"], [b"new", CX + b"\x17"] + typed + [RET], n2,
              {b"f": GOOD, n2: b"newold\n"}, n2, limit=k == "esc")
        drive(f"{k}-find-file-typed", {n2: GOOD, b"f": GOOD}, [b"f"], [CX + b"\x06"] + typed + [RET], n2, None, n2, limit=k == "esc")
print("FAILURES", fails)
