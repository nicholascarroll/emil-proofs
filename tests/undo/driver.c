/* Drive emil's real undo code over a random or replayed sequence of operations and
 * print the state after each one, as Lisp data for acl2/undo/diff/check.lsp.
 *
 * Linked with the objects of whichever emil commit is under test (tests/undo/build.sh).
 * EMIL_OLD_API is set when that commit's mutation API still takes old_text.
 *
 *   driver --seed N --steps M [--mode valid|CLASS] [--full-every K] [--ops-out FILE]
 *   driver --replay FILE [--full-every K]
 *
 * Hostile classes (a mostly valid sequence with occasional bad operations):
 *   xpast   delete ending past the end of its row (edit.c:202 on malformed UTF-8)
 *   ypast   delete ending past the last row
 *   rev1    reversed range on one row
 *   rev2    reversed range across rows
 *   spast   delete starting past the end of its row
 *   inspast insert past the end of a row, or past the last row
 *   lie     old_text differing from what the range holds
 *   extend  mutateExtendRows with from_row other than the row count
 */
#include "emil.h"
#include "buffer.h"
#include "mutate.h"
#include "undo.h"
#include "test_harness.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum kind {
	K_INSCHAR, K_DELCHAR, K_INSERT, K_DELETE, K_REPLACE, K_EXTEND,
	K_UNDO, K_REDO, K_CURSOR, K_CLOSE, K_CLEAR, K_READONLY, K_NKINDS
};
static const char *kind_name[] = {
	":INS-CHAR", ":DEL-CHAR", ":INSERT", ":DELETE", ":REPLACE", ":EXTEND",
	":UNDO", ":REDO", ":CURSOR", ":CLOSE", ":CLEAR", ":READONLY",
};

#define MAXDATA 256
struct op {
	int kind, sx, sy, ex, ey;
	int flag;  /* chain; or count (undo, redo, extend n); or read-only value */
	int burst;
	int lie;   /* corrupt old_text before passing it */
	int len;
	uint8_t data[MAXDATA];
};

/* xorshift64*: deterministic, and independent of libc */
static uint64_t rng_state;
static uint64_t rnd64(void) {
	uint64_t x = rng_state;
	x ^= x >> 12; x ^= x << 25; x ^= x >> 27;
	rng_state = x;
	return x * 2685821657736338717ULL;
}
static int rnd(int n) { return n <= 0 ? 0 : (int)((rnd64() >> 33) % (uint64_t)n); }
static int chance(int pct) { return rnd(100) < pct; }

static struct buffer *buf;

/* ---- Printing ---- */

static void print_data(const uint8_t *d, int n) {
	putchar('(');
	for (int i = 0; i < n; i++) {
		if (i) putchar(' ');
		if (d[i] == '\n') fputs(":NL", stdout);
		else printf("%d", d[i]);
	}
	putchar(')');
}

static void print_rec(const struct undo *u) {
	printf("(%d %d %d %d %s ", u->startx, u->starty, u->endx, u->endy,
	       u->delete ? "T" : "NIL");
	print_data(u->data, u->datalen);
	printf(" %s %s %d %s %d %d)", u->append ? "T" : "NIL",
	       u->paired ? "T" : "NIL", u->nmerges, u->uncapped ? "T" : "NIL",
	       u->pointx, u->pointy);
}

static int list_len(const struct undo *u) {
	int n = 0;
	for (; u; u = u->prev) n++;
	return n;
}

static void print_list(const struct undo *u, int full) {
	putchar('(');
	for (int i = 0; u && (full || i < 1); u = u->prev, i++) {
		if (i) putchar(' ');
		print_rec(u);
	}
	putchar(')');
}

static void print_text(void) {
	putchar('(');
	for (int i = 0; i < buf->numrows; i++) {
		if (i) putchar(' ');
		putchar('(');
		for (int j = 0; j < buf->row[i].size; j++) {
			if (j) putchar(' ');
			printf("%d", buf->row[i].chars[j]);
		}
		putchar(')');
	}
	putchar(')');
}

static void print_op(const struct op *o) {
	printf("(%s %d %d %d %d %d %d %d ", kind_name[o->kind], o->sx, o->sy,
	       o->ex, o->ey, o->flag, o->burst, o->lie);
	print_data(o->data, o->len);
	putchar(')');
}

/* (step op r1 r2 cx cy text nundo nredo undo redo) */
static void print_step(int step, const struct op *o, int r1, int r2, int full) {
	printf("(%d ", step);
	print_op(o);
	printf(" %d %d %d %d ", r1, r2, buf->cx, buf->cy);
	print_text();
	printf(" %d %d %s ", list_len(buf->undo), list_len(buf->redo),
	       full ? "T" : "NIL");
	print_list(buf->undo, full);
	putchar(' ');
	print_list(buf->redo, full);
	puts(")");
	fflush(stdout);
}

/* ---- Executing one operation ---- */

static uint8_t *old_text_of(const struct op *o, int *len) {
	uint8_t *t = collectRegionText(buf, o->sx, o->sy, o->ex, o->ey, len);
	if (o->lie && *len > 0)
		t[rnd(*len)] ^= 1;
	return t;
}

/* Sets r1, r2: mutation out_end, or the undoResult in r1. -1 = not written. */
static void execute(const struct op *o, int *r1, int *r2) {
	*r1 = *r2 = -1;
	E.input_burst = o->burst;
	switch (o->kind) {
	case K_INSCHAR:
		mutateInsertChar(buf, o->sx, o->sy, o->data, o->len, r1, r2);
		break;
	case K_INSERT:
		mutateInsert(buf, o->sx, o->sy, o->data, o->len, r1, r2);
		break;
#ifdef EMIL_OLD_API
	case K_DELCHAR: {
		int n; uint8_t *t = old_text_of(o, &n);
		mutateDeleteChar(buf, o->sx, o->sy, o->ex, o->ey, t, n);
		free(t);
		break;
	}
	case K_DELETE: {
		int n; uint8_t *t = old_text_of(o, &n);
		mutateDelete(buf, o->sx, o->sy, o->ex, o->ey, t, n);
		free(t);
		break;
	}
	case K_REPLACE: {
		int n; uint8_t *t = old_text_of(o, &n);
		mutateReplace(buf, o->sx, o->sy, o->ex, o->ey, t, n, o->data,
			      o->len, o->flag, r1, r2);
		free(t);
		break;
	}
#else
	case K_DELCHAR:
		mutateDeleteChar(buf, o->sx, o->sy, o->ex, o->ey);
		break;
	case K_DELETE:
		mutateDelete(buf, o->sx, o->sy, o->ex, o->ey);
		break;
	case K_REPLACE:
		mutateReplace(buf, o->sx, o->sy, o->ex, o->ey, o->data, o->len,
			      o->flag, r1, r2);
		break;
#endif
	case K_EXTEND:
		mutateExtendRows(buf, o->sx, o->flag);
		break;
	case K_UNDO:
		*r1 = (int)doUndo(buf, o->flag);
		break;
	case K_REDO:
		*r1 = (int)doRedo(buf, o->flag);
		break;
	case K_CURSOR:
		buf->cx = o->sx;
		buf->cy = o->sy;
		break;
	case K_CLOSE:
		undoCloseRun(buf);
		break;
	case K_CLEAR:
		clearUndosAndRedos(buf);
		break;
	case K_READONLY:
		buf->read_only = o->flag;
		break;
	}
	E.input_burst = 0;
}

/* ---- Generating ---- */

static int textsize(void) {
	int n = 0;
	for (int i = 0; i < buf->numrows; i++) n += buf->row[i].size + 1;
	return n;
}

static uint8_t rnd_byte(void) {
	static const uint8_t alpha[] = { 'a', 'b', 'c', ' ', 0xC3, 0xA9, '\t' };
	return alpha[rnd(sizeof alpha)];
}

static void rnd_data(struct op *o, int maxlen, int nl_pct) {
	o->len = 1 + rnd(maxlen);
	for (int i = 0; i < o->len; i++)
		o->data[i] = chance(nl_pct) ? '\n' : rnd_byte();
}

static void rnd_pos(int *x, int *y) {
	*y = chance(30) ? buf->numrows - 1 - rnd(buf->numrows > 2 ? 3 : buf->numrows)
			: rnd(buf->numrows);
	if (*y < 0) *y = 0;
	int sz = buf->row[*y].size;
	switch (rnd(4)) {
	case 0: *x = 0; break;
	case 1: *x = sz; break;
	default: *x = rnd(sz + 1); break;
	}
}

static int pos_le(int ax, int ay, int bx, int by) {
	return ay < by || (ay == by && ax <= bx);
}

static void rnd_range(struct op *o) {
	int ax, ay, bx, by;
	rnd_pos(&ax, &ay);
	if (chance(50)) {
		/* a short range nearby */
		by = ay + (chance(25) ? rnd(3) : 0);
		if (by >= buf->numrows) by = buf->numrows - 1;
		bx = by == ay ? ax + rnd(6) : rnd(buf->row[by].size + 1);
		if (bx > buf->row[by].size) bx = buf->row[by].size;
	} else {
		rnd_pos(&bx, &by);
	}
	if (!pos_le(ax, ay, bx, by)) {
		int t = ax; ax = bx; bx = t;
		t = ay; ay = by; by = t;
	}
	o->sx = ax; o->sy = ay; o->ex = bx; o->ey = by;
}

/* Real commands run after clampPositions, so edits at the cursor start valid. */
static int cursor_valid(void) {
	return buf->cy >= 0 && buf->cy < buf->numrows && buf->cx >= 0 &&
	       buf->cx <= buf->row[buf->cy].size;
}

static int undo_all_count(void) { return 100000; }

/* A pending undo-then-redo pair: count for the redo, or 0. */
static int pending_redo;

static int pending_cursor, pcx, pcy;
static int run_left, run_kind, run_burst;

static void gen_valid(struct op *o) {
	memset(o, 0, sizeof *o);
	if (pending_cursor) {
		pending_cursor = 0;
		o->kind = K_CURSOR;
		o->sx = pcx; o->sy = pcy;
		return;
	}
	if (pending_redo) {
		o->kind = K_REDO;
		o->flag = pending_redo;
		pending_redo = 0;
		return;
	}
	if (!cursor_valid()) {
		o->kind = K_CURSOR;
		rnd_pos(&o->sx, &o->sy);
		return;
	}
	int big = textsize() > 500;
	int r = rnd(1000);
	if (big && r < 500) r = 620; /* prefer a deletion when the text is big */
	/* Runs long enough to reach UNDO_MERGE_LIMIT.  Sometimes in a burst,
	 * which lifts the limit. */
	if (run_left == 0 && chance(2)) {
		run_left = 15 + rnd(45);
		run_kind = rnd(3);
		run_burst = chance(30);
	}
	if (run_left > 0) {
		run_left--;
		r = run_kind == 0 ? 0 : run_kind == 1 ? 400 : 500;
	}
	if (r < 300) {          /* typing at the cursor */
		o->kind = K_INSCHAR;
		o->sx = buf->cx; o->sy = buf->cy;
		o->len = 1;
		o->data[0] = rnd_byte();
		if (o->data[0] == 0xC3) { o->data[1] = 0xA9; o->len = 2; }
		o->burst = chance(15) || (run_left > 0 && run_burst);
	} else if (r < 360) {   /* newline at the cursor */
		o->kind = K_INSCHAR;
		o->sx = buf->cx; o->sy = buf->cy;
		o->len = 1;
		o->data[0] = '\n';
		o->burst = chance(15);
	} else if (r < 460) {   /* backspace */
		if (buf->cx == 0 && buf->cy == 0) { o->kind = K_CLOSE; return; }
		o->kind = K_DELCHAR;
		o->ex = buf->cx; o->ey = buf->cy;
		if (buf->cx > 0) { o->sx = buf->cx - 1; o->sy = buf->cy; }
		else { o->sy = buf->cy - 1; o->sx = buf->row[o->sy].size; }
		o->burst = chance(15) || (run_left > 0 && run_burst);
	} else if (r < 560) {   /* C-d */
		if (buf->cy == buf->numrows - 1 &&
		    buf->cx == buf->row[buf->cy].size) { o->kind = K_CLOSE; return; }
		o->kind = K_DELCHAR;
		o->sx = buf->cx; o->sy = buf->cy;
		if (buf->cx < buf->row[buf->cy].size) { o->ex = buf->cx + 1; o->ey = buf->cy; }
		else { o->ex = 0; o->ey = buf->cy + 1; }
		o->burst = chance(15) || (run_left > 0 && run_burst);
	} else if (r < 600) {   /* yank */
		o->kind = K_INSERT;
		rnd_pos(&o->sx, &o->sy);
		rnd_data(o, 30, 15);
	} else if (r < 650) {   /* kill region */
		o->kind = K_DELETE;
		rnd_range(o);
	} else if (r < 700) {   /* replace, sometimes chained or inserting nothing */
		o->kind = K_REPLACE;
		rnd_range(o);
		if (!chance(10)) rnd_data(o, 12, 15);
		o->flag = chance(20);
	} else if (r < 715) {   /* delete exactly the final newline, or through it */
		o->kind = K_DELETE;
		int last = buf->numrows - 1;
		if (last >= 1) {
			o->sy = last - 1;
			o->sx = chance(50) ? buf->row[last - 1].size : rnd(buf->row[last - 1].size + 1);
			o->ey = last; o->ex = buf->row[last].size;
		} else {
			o->sx = 0; o->ex = buf->row[0].size;
		}
	} else if (r < 725) {   /* type on the final row, which needs repair */
		o->kind = K_INSCHAR;
		o->sy = buf->numrows - 1; o->sx = buf->row[o->sy].size;
		o->len = 1; o->data[0] = rnd_byte();
	} else if (r < 840) {   /* undo */
		o->kind = K_UNDO;
		o->flag = chance(10) ? 0 : 1 + rnd(3);
		if (chance(20)) pending_redo = o->flag ? o->flag : 1;
	} else if (r < 910) {   /* redo */
		o->kind = K_REDO;
		o->flag = 1 + rnd(3);
	} else if (r < 920) {   /* undo everything */
		o->kind = K_UNDO;
		o->flag = undo_all_count();
		if (chance(50)) pending_redo = undo_all_count();
	} else if (r < 960) {   /* the cursor moves */
		o->kind = K_CURSOR;
		rnd_pos(&o->sx, &o->sy);
	} else if (r < 975) {
		o->kind = K_CLOSE;
	} else if (r < 985) {   /* yank-rectangle overrun */
		o->kind = K_EXTEND;
		o->sx = buf->numrows;
		o->flag = 1 + rnd(3);
	} else if (r < 990) {   /* read-only on, then an edit is refused */
		o->kind = K_READONLY;
		o->flag = !buf->read_only;
	} else if (r < 993) {
		o->kind = K_CLEAR;
	} else {                /* an edit that does nothing still clears redo */
		o->kind = K_INSERT;
		o->sx = buf->cx; o->sy = buf->cy;
		o->len = 0;
	}
}

static void gen_hostile(struct op *o, const char *cls) {
	memset(o, 0, sizeof *o);
	o->kind = K_DELETE;
	rnd_pos(&o->sx, &o->sy);
	o->ex = o->sx; o->ey = o->sy;
	if (!strcmp(cls, "xpast")) {
		o->ex = buf->row[o->sy].size + 1 + rnd(3);
	} else if (!strcmp(cls, "ypast")) {
		o->ey = buf->numrows + rnd(3);
		o->ex = rnd(3);
	} else if (!strcmp(cls, "rev1")) {
		if (o->sx == 0) o->sx = buf->row[o->sy].size;
		o->ex = o->sx > 0 ? rnd(o->sx) : 0;
	} else if (!strcmp(cls, "rev2")) {
		if (o->sy == 0) o->sy = buf->numrows - 1;
		o->sx = rnd(buf->row[o->sy].size + 1);
		o->ey = o->sy > 0 ? rnd(o->sy) : 0;
		o->ex = rnd(buf->row[o->ey].size + 1);
	} else if (!strcmp(cls, "spast")) {
		o->sx = buf->row[o->sy].size + 1 + rnd(3);
		o->ex = o->sx;
		o->ey = o->sy;
		if (o->sy + 1 < buf->numrows) { o->ey = o->sy + 1; o->ex = 0; }
	} else if (!strcmp(cls, "inspast")) {
		o->kind = K_INSERT;
		rnd_data(o, 4, 10);
		if (chance(50))
			o->sx = buf->row[o->sy].size + 1 + rnd(3);
		else
			o->sy = buf->numrows + rnd(3);
		o->ex = o->sx; o->ey = o->sy;
	} else if (!strcmp(cls, "lie")) {
		rnd_range(o);
		o->lie = 1;
	} else if (!strcmp(cls, "extend")) {
		o->kind = K_EXTEND;
		o->sx = buf->numrows + (chance(50) ? -1 : 1) * (1 + rnd(2));
		if (o->sx < 1) o->sx = buf->numrows + 1;
		if (o->sx > buf->numrows) o->sx = buf->numrows - 1 > 0 ? buf->numrows - 1 : 1;
		o->flag = 1 + rnd(2);
	} else {
		fprintf(stderr, "unknown class %s\n", cls);
		exit(2);
	}
}

/* ---- The initial text ---- */

struct start { int minibuf; int nrows; int len[12]; uint8_t rows[12][24]; };

static void rnd_start(struct start *s) {
	memset(s, 0, sizeof *s);
	s->minibuf = chance(10);
	s->nrows = 1 + rnd(6);
	for (int i = 0; i < s->nrows; i++) {
		s->len[i] = rnd(12);
		for (int j = 0; j < s->len[i]; j++) s->rows[i][j] = rnd_byte();
	}
	/* Most files end with a newline, which is an empty final row. */
	if (chance(80) && s->nrows < 12) {
		s->len[s->nrows] = 0;
		s->nrows++;
	}
}

static void apply_start(const struct start *s) {
	buf = newBuffer();
	/* newBuffer starts with one empty row: load the text as fileio does. */
	bufferResetRows(buf);
	for (int i = 0; i < s->nrows; i++)
		insertRow(buf, i, s->rows[i], s->len[i]);
	buf->cx = buf->cy = 0;
	buf->dirty = 0;
	clearUndosAndRedos(buf);
	E.buf = buf;
	E.headbuf = buf;
	E.windows[0]->buf = buf;
	E.minibuf = s->minibuf ? buf : NULL;
}

/* ---- Replay files: plain numbers, one line each ---- */

static void write_start(FILE *f, const struct start *s) {
	fprintf(f, "%d %d\n", s->minibuf, s->nrows);
	for (int i = 0; i < s->nrows; i++) {
		fprintf(f, "%d", s->len[i]);
		for (int j = 0; j < s->len[i]; j++) fprintf(f, " %d", s->rows[i][j]);
		fputc('\n', f);
	}
}

static void read_start(FILE *f, struct start *s) {
	memset(s, 0, sizeof *s);
	if (fscanf(f, "%d %d", &s->minibuf, &s->nrows) != 2 || s->nrows > 12) exit(2);
	for (int i = 0; i < s->nrows; i++) {
		if (fscanf(f, "%d", &s->len[i]) != 1 || s->len[i] > 24) exit(2);
		for (int j = 0; j < s->len[i]; j++) {
			int b;
			if (fscanf(f, "%d", &b) != 1) exit(2);
			s->rows[i][j] = (uint8_t)b;
		}
	}
}

static void write_op(FILE *f, const struct op *o) {
	fprintf(f, "%d %d %d %d %d %d %d %d %d", o->kind, o->sx, o->sy, o->ex,
		o->ey, o->flag, o->burst, o->lie, o->len);
	for (int i = 0; i < o->len; i++) fprintf(f, " %d", o->data[i]);
	fputc('\n', f);
}

static int read_op(FILE *f, struct op *o) {
	memset(o, 0, sizeof *o);
	if (fscanf(f, "%d %d %d %d %d %d %d %d %d", &o->kind, &o->sx, &o->sy,
		   &o->ex, &o->ey, &o->flag, &o->burst, &o->lie, &o->len) != 9)
		return 0;
	if (o->kind < 0 || o->kind >= K_NKINDS || o->len < 0 || o->len > MAXDATA) exit(2);
	for (int i = 0; i < o->len; i++) {
		int b;
		if (fscanf(f, "%d", &b) != 1) exit(2);
		o->data[i] = (uint8_t)b;
	}
	return 1;
}

int main(int argc, char **argv) {
	long seed = 1;
	int steps = 1000, full_every = 32;
	const char *mode = "valid", *ops_out = NULL, *replay = NULL;
	for (int i = 1; i + 1 < argc; i += 2) {
		if (!strcmp(argv[i], "--seed")) seed = atol(argv[i + 1]);
		else if (!strcmp(argv[i], "--steps")) steps = atoi(argv[i + 1]);
		else if (!strcmp(argv[i], "--mode")) mode = argv[i + 1];
		else if (!strcmp(argv[i], "--full-every")) full_every = atoi(argv[i + 1]);
		else if (!strcmp(argv[i], "--ops-out")) ops_out = argv[i + 1];
		else if (!strcmp(argv[i], "--replay")) replay = argv[i + 1];
		else { fprintf(stderr, "bad option %s\n", argv[i]); return 2; }
	}
	rng_state = 0x9E3779B97F4A7C15ULL ^ ((uint64_t)seed * 0xBF58476D1CE4E5B9ULL);
	if (!rng_state) rng_state = 1;
	for (int i = 0; i < 8; i++) rnd64();

	initTestEditor();
	struct start s;
	FILE *rf = NULL, *of = NULL;
	if (replay) {
		rf = fopen(replay, "r");
		if (!rf) { perror(replay); return 2; }
		read_start(rf, &s);
	} else {
		rnd_start(&s);
	}
	if (ops_out) {
		of = fopen(ops_out, "w");
		if (!of) { perror(ops_out); return 2; }
		write_start(of, &s);
		fflush(of);
	}
	apply_start(&s);

	/* (:start seed mode wants-nl text) */
	printf("(:START %ld \"%s\" %s ", seed, replay ? "replay" : mode,
	       s.minibuf ? "NIL" : "T");
	print_text();
	puts(")");
	fflush(stdout);

	int hostile = strcmp(mode, "valid") != 0;
	for (int step = 0; replay || step < steps; step++) {
		struct op o;
		if (replay) {
			if (!read_op(rf, &o)) break;
		} else if (hostile && chance(3) && cursor_valid() && !buf->read_only) {
			gen_hostile(&o, mode);
		} else {
			gen_valid(&o);
		}
		if (of) { write_op(of, &o); fflush(of); }
		int r1, r2;
		execute(&o, &r1, &r2);
		print_step(step, &o, r1, r2, full_every > 0 && step % full_every == 0);
		/* Commands move the cursor after mutating.  That is a step of
		 * its own, so the model sees it. */
		if (!replay) {
			if (o.kind == K_INSCHAR && r1 >= 0) {
				pending_cursor = 1; pcx = r1; pcy = r2;
			} else if (o.kind == K_DELCHAR && o.lie == 0) {
				pending_cursor = 1; pcx = o.sx; pcy = o.sy;
			}
		}
	}
	puts("(:END)");
	fflush(stdout);
	return 0;
}
