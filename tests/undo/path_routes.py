#!/usr/bin/env python3
"""Drive each route a filename can take into a real emil, with a bad path.

Usage: path_routes.py EMIL_REPO COMMIT WORK_DIR
Exports COMMIT, adds a logger at the top of refreshScreen that records each buffer's name
and the working directory, builds a normal emil, and drives it through a pty.
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
#include <unistd.h>
static void routeLog(void) {
	const char *lg = getenv("ROUTE_LOG");
	FILE *f = lg ? fopen(lg, "a") : NULL;
	if (!f)
		return;
	char cwd[4096];
	if (getcwd(cwd, sizeof(cwd)))
		fprintf(f, "CWD %s\n", cwd);
	for (struct buffer *b = E.headbuf; b; b = b->next)
		if (b->filename && !b->special_buffer)
			fprintf(f, "NAME %s\n", b->filename);
	fclose(f);
}
'''
m = re.search(r"^void refreshScreen\(void\) \{\n", s, re.M)
assert m
s = s[:m.start()] + hook + s[m.start():m.end()] + "\trouteLog();\n" + s[m.end():]
open(p, "w").write(s)
subprocess.check_call(["make", "-j2", "emil"], cwd=src, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
emil = os.path.join(src, "emil")

CX = b"\x18"; CG = b"\x07"; RET = b"\r"; M = b"\x1b"; CQ = b"\x11"
BAD_TAB = b"x\ty"; BAD_BYTE = b"qq\xffy"; GOOD = b"good\n"
TYPE_TAB = b"x" + CQ + b"\t" + b"y"


def drive(name, files, argv, keys, cwd_sub=None, mkdirs=(), links=()):
    d = os.path.join(work, "run", name); os.makedirs(d)
    db = d.encode()
    for sub in mkdirs:
        os.makedirs(os.path.join(db, sub))
    for fn, data in files.items():
        with open(os.path.join(db, fn), "wb") as f:
            f.write(data)
    for src_f, dst in links:
        os.link(os.path.join(db, src_f), os.path.join(db, dst))
    before = {fn: open(os.path.join(db, fn), "rb").read() for fn in files}
    log = os.path.join(d, "route.log")
    env = dict(os.environ, ROUTE_LOG=log, TERM="xterm", HOME=d, LC_ALL="C.UTF-8")
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(os.path.join(db, cwd_sub) if cwd_sub else db)
        os.execve(emil.encode(), [b"emil"] + argv, env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
    out = b""; exited = None

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

    pump(0.6)
    for k in keys:
        try:
            os.write(fd, k)
        except OSError:
            break
        pump(0.25)
    pump(0.3)
    w, st = os.waitpid(pid, os.WNOHANG)
    if w:
        exited = os.waitstatus_to_exitcode(st)
    else:
        os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)
    os.close(fd)
    txt = re.sub(rb"\x1b\[[0-9;?]*[a-zA-Z]|\x1b[78=>]", b" ", out).decode("utf-8", "replace")
    msgs = sorted(set(re.findall(r"(File name has a control byte or invalid UTF-8|cd: refused[^\r\n]*?UTF-8|are the same file|Save aborted|Wrote \d+|Overwrite[^\r\n]{0,30})", txt)))
    log_text = open(log, "rb").read() if os.path.exists(log) else b""
    names = {l[5:] for l in log_text.splitlines() if l.startswith(b"NAME ")}
    badnames = sorted(n for n in names if any(c < 0x20 or c == 0x7f for c in n) or not valid(n))
    cwds = [l[4:] for l in log_text.splitlines() if l.startswith(b"CWD ")]
    changed = [fn for fn in files if open(os.path.join(db, fn), "rb").read() != before[fn]]
    print(f"== {name}\n   exit={exited} messages={msgs}\n   bad names held: {badnames}; files changed: {changed}; "
          f"last cwd ends: {cwds[-1][-14:] if cwds else None}; files now: {sorted(os.listdir(db))[:8]}")


def valid(b):
    try:
        b.decode("utf-8"); return True
    except UnicodeDecodeError:
        return False


drive("argv-control", {BAD_TAB: GOOD}, [BAD_TAB], [])
drive("argv-invalid", {BAD_BYTE: GOOD}, [BAD_BYTE], [])
drive("find-file-typed", {BAD_TAB: GOOD, b"f": GOOD}, [b"f"], [CX + b"\x06", TYPE_TAB, RET])
drive("find-file-glob", {BAD_TAB: GOOD, b"f": GOOD}, [b"f"], [CX + b"\x06", b"x*", RET])
drive("find-file-same-file-as-open", {b"f": GOOD}, [b"f"], [CX + b"\x06", TYPE_TAB, RET], links=[(b"f", BAD_TAB)])
drive("tag-jump", {b"m.c": b"foo\n", BAD_BYTE: GOOD, b"tags": b"foo\tqq\xffy\t1;\"\tf\n"}, [b"m.c"], [M + b".", CG])
drive("first-save", {BAD_TAB: b"theirs\n"}, [], [b"hi", CX + b"\x13", TYPE_TAB, RET, b"y"])
drive("save-as", {BAD_TAB: b"theirs\n", b"f": GOOD}, [b"f"], [b"hi", CX + b"\x17", TYPE_TAB, RET, b"y"])
drive("cd-rebase-fails", {b"d\ty/f": GOOD}, [b"f"], [M + b"x", b"cd", RET, b"/", RET], cwd_sub=b"d\ty", mkdirs=[b"d\ty"])
drive("cd-valid-control", {b"sub/f": GOOD}, [b"f"], [M + b"x", b"cd", RET, b"/", RET], cwd_sub=b"sub", mkdirs=[b"sub"])
