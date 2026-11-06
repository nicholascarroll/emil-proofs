#!/usr/bin/env python3
"""Can invalid UTF-8 reach a row of the real editor, and then a file?

Usage: utf8_paths.py EMIL_REPO COMMIT WORK_DIR
Exports COMMIT, adds a logger at the top of refreshScreen that records every invalid row
in every buffer, builds a normal emil, and drives it through a pty, one scenario at a time.
No fuzz text is injected: every invalid byte has to get in through a real path.
"""
import fcntl, os, pty, re, select, shutil, signal, struct, subprocess, sys, termios, time

repo, commit, work = sys.argv[1:4]
src = os.path.join(work, "src")
os.makedirs(src)
subprocess.check_call(f"git -C {repo} archive {commit} | tar -x -C {src}", shell=True)

p = os.path.join(src, "display.c")
s = open(p).read()
hook = r'''
#include <stdio.h>
#include <stdlib.h>
#include "unicode.h"
static void utf8PathLogBuf(FILE *f, struct buffer *b, const char *cls) {
	for (int i = 0; i < b->numrows; i++) {
		if (utf8_validate(b->row[i].chars, b->row[i].size))
			continue;
		fprintf(f, "INVALID %s name=%s row=%d ", cls, b->filename ? b->filename : "-", i);
		for (int k = 0; k < b->row[i].size; k++)
			fprintf(f, "%02x", b->row[i].chars[k]);
		fprintf(f, "\n");
	}
}
static void utf8PathLog(void) {
	const char *lg = getenv("UTF8_LOG");
	FILE *f = lg ? fopen(lg, "a") : NULL;
	if (!f)
		return;
	for (struct buffer *b = E.headbuf; b; b = b->next)
		utf8PathLogBuf(f, b, b->special_buffer ? "special" : (b->filename ? "file" : "unnamed"));
	if (E.minibuf)
		utf8PathLogBuf(f, E.minibuf, "minibuffer");
	fclose(f);
}
'''
m = re.search(r"^void refreshScreen\(void\) \{\n", s, re.M)
assert m, "refreshScreen"
s = s[:m.start()] + hook + s[m.start():m.end()] + "\tutf8PathLog();\n" + s[m.end():]
open(p, "w").write(s)
subprocess.check_call(["make", "-j2", "emil"], cwd=src, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
emil = os.path.join(src, "emil")

CX = b"\x18"; CG = b"\x07"; RET = b"\r"; TAB = b"\t"; M = b"\x1b"
BADNAME = b"qq\xffy"


def drive(name, files, argv, keys, stdin_shell=None):
    d = os.path.join(work, "run", name)
    os.makedirs(d)
    d_b = d.encode()
    for fn, data in files.items():
        with open(os.path.join(d_b, fn), "wb") as f:
            f.write(data)
    log = os.path.join(d, "utf8.log")
    env = dict(os.environ, UTF8_LOG=log, TERM="xterm", HOME=d, LC_ALL="C.UTF-8")
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(d)
        if stdin_shell:
            os.execvpe("sh", ["sh", "-c", stdin_shell.replace("EMIL", emil)], env)
        os.execve(emil.encode(), [b"emil"] + argv, env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
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

    pump(0.6)
    for k in keys:
        os.write(fd, k)
        pump(0.25)
    pump(0.3)
    screen = out
    os.kill(pid, signal.SIGKILL)
    os.waitpid(pid, 0)
    os.close(fd)
    rows = sorted(set(open(log).read().splitlines())) if os.path.exists(log) else []
    txt = re.sub(rb"\x1b\[[0-9;?]*[a-zA-Z]|\x1b[78=>]", b" ", screen).decode("utf-8", "replace")
    msgs = sorted(set(re.findall(r"(Save failed[^\r\n]*?invalid UTF-8|Failed UTF-8 validation|Shell output contains invalid UTF-8|Wrote \d+|\d+ bytes written)", txt)))
    print(f"== {name}")
    for r in rows[:8]:
        print("  ", r[:110])
    print(f"   invalid rows logged: {len(rows)}; messages: {msgs}")
    for fn, data in files.items():
        now = open(os.path.join(d_b, fn), "rb").read()
        if now != data:
            print(f"   FILE CHANGED {fn!r}: {now!r}")
    return rows, msgs


GOOD = b"good\n"
drive("buffer-prompt-unique", {BADNAME: GOOD, b"other": GOOD}, [BADNAME, b"other"], [CX + b"b", b"qq", TAB, CG])
# The last file named on the command line is the current buffer, and it isn't offered.
drive("buffer-prompt-list", {BADNAME: GOOD, b"qqz": GOOD, b"other": GOOD}, [BADNAME, b"qqz", b"other"], [CX + b"b", b"qq", TAB, TAB, CG])
drive("register-view", {BADNAME: GOOD}, [BADNAME], [CX + b"r ", b"a", CX + b"rV", b"a", CG])
drive("tags-menu", {b"m.c": b"foo\n", b"tags": b"foo\tqq\xffy.c\t1;\"\tf\nfoo\tother.c\t2;\"\tf\n"}, [b"m.c"], [M + b".", CG, CG])
drive("load-invalid-file", {b"bad.txt": b"a\xff\n"}, [b"bad.txt"], [CG])
drive("insert-invalid-file", {b"bad.txt": b"a\xff\n", b"f": GOOD}, [b"f"], [CX + b"i", b"bad.txt", RET, CG])
drive("stdin-invalid", {}, [], [CG], stdin_shell="printf 'a\\377\\n' | EMIL")
drive("shell-output-invalid", {b"f": GOOD}, [b"f"], [M + b"!", b"printf 'a\\377'", RET, CG])
# Does it go further: invalid name to minibuffer, killed there, yanked into a file buffer, saved?
drive("name-yanked-then-saved", {BADNAME: GOOD, b"other": GOOD}, [BADNAME, b"other"],
      [CX + b"b", b"qq", TAB, b"\x01", b"\x0b", CG, b"\x19", CX + b"\x13", CG])
# Control: the same steps without the bad byte must save, so the scenario can reach a write.
drive("control-valid-name-saved", {b"qqay": GOOD, b"other": GOOD}, [b"qqay", b"other"],
      [CX + b"b", b"qq", TAB, b"\x01", b"\x0b", CG, b"\x19", CX + b"\x13", CG])
