#!/usr/bin/env python3
"""Instrument a scratch copy of emil to record what actually reaches adjustPoint.

Usage: audit_patch.py COPY_DIR. Changes only the copy. Each adjustAllPoints call and the
direct redo-chain call check the edit against the rows at that moment, and log any
violation with a stack trace to the file named by $PROOFS_AUDIT_LOG. Deletions run before
the rows change, insertions after, so a check is only made where the rows mean something.
"""
import sys
d = sys.argv[1]
AUDIT = r'''
#include <execinfo.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
long proofs_calls, proofs_viol, proofs_stale_del, proofs_points_del;
static void proofs_log(const char *what, int a, int b, int c, int d, int del) {
	const char *p = getenv("PROOFS_AUDIT_LOG");
	if (!p) return;
	int fd = open(p, O_WRONLY | O_APPEND | O_CREAT, 0666);
	if (fd < 0) return;
	char b1[160];
	int n = snprintf(b1, sizeof b1, "VIOLATION %s start=(%d,%d) end=(%d,%d) del=%d\n", what, a, b, c, d, del);
	(void)!write(fd, b1, (size_t)n);
	void *st[12];
	int k = backtrace(st, 12);
	backtrace_symbols_fd(st, k, fd);
	close(fd);
}
static void proofs_summary(void) {
	const char *p = getenv("PROOFS_AUDIT_LOG");
	if (!p || !proofs_calls) return;
	int fd = open(p, O_WRONLY | O_APPEND | O_CREAT, 0666);
	if (fd < 0) return;
	char b1[160];
	int n = snprintf(b1, sizeof b1, "SUMMARY calls=%ld violations=%ld del_points=%ld del_stale_points=%ld\n",
			 proofs_calls, proofs_viol, proofs_points_del, proofs_stale_del);
	(void)!write(fd, b1, (size_t)n);
	close(fd);
}
static int proofs_pos_ok(struct buffer *b, int x, int y) {
	return y >= 0 && y < b->numrows && x >= 0 && x <= b->row[y].size;
}
void proofs_audit(struct buffer *b, int sx, int sy, int ex, int ey, int del, int start_only) {
	static int reg;
	if (!reg) { reg = 1; atexit(proofs_summary); }
	proofs_calls++;
	const char *w = NULL;
	if (!proofs_pos_ok(b, sx, sy)) w = "start not valid";
	else if (!start_only && !proofs_pos_ok(b, ex, ey)) w = "end not valid";
	else if (ey < sy || (ey == sy && ex < sx)) w = "not ordered";
	if (w) { proofs_viol++; proofs_log(w, sx, sy, ex, ey, del); }
}
static void proofs_point(struct buffer *b, int x, int y, const char *kind) {
	proofs_points_del++;
	if (proofs_pos_ok(b, x, y)) return;
	proofs_stale_del++;
	const char *p = getenv("PROOFS_AUDIT_LOG");
	if (!p) return;
	int fd = open(p, O_WRONLY | O_APPEND | O_CREAT, 0666);
	if (fd < 0) return;
	char b1[120];
	int n = snprintf(b1, sizeof b1, "STALE %s point=(%d,%d) numrows=%d rowsize=%d\n", kind, x, y,
			 b->numrows, (y >= 0 && y < b->numrows) ? b->row[y].size : -1);
	(void)!write(fd, b1, (size_t)n);
	close(fd);
}
'''
p = f"{d}/adjust.c"; s = open(p).read()
head = '#include "emil.h"\n'
assert head in s
s = s.replace(head, head + AUDIT, 1)
old = "\t/* Nothing to adjust if the mutation is a no-op */"
assert old in s
s = s.replace(old, """\tproofs_audit(buf, startx, starty, endx, endy, is_delete, 0);
\tif (is_delete) {
\t\tif (buf->markx >= 0 && buf->marky >= 0) proofs_point(buf, buf->markx, buf->marky, "mark");
\t\tfor (int i = 0; i < E.nwindows; i++)
\t\t\tif (E.windows[i]->buf == buf && !E.windows[i]->focused)
\t\t\t\tproofs_point(buf, E.windows[i]->cx, E.windows[i]->cy, "window");
\t}
""" + old, 1)
open(p, "w").write(s)
p = f"{d}/undo.c"; s = open(p).read()
old = "\t\t\tstruct undo *n = buf->redo;\n"
assert old in s
s = s.replace(old, old + "\t\t\tproofs_audit(buf, n->startx, n->starty, n->endx, n->endy, n->delete, !n->delete);\n", 1)
s = s.replace('#include "undo.h"\n', '#include "undo.h"\nvoid proofs_audit(struct buffer *b, int sx, int sy, int ex, int ey, int del, int start_only);\n', 1)
open(p, "w").write(s)
