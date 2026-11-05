/* Milestone 1: exhaustive small-scope test of adjustPoint against a text model.
 *
 * The domain is every text of 1..MAX_LINES lines with 0..MAX_COLS characters per
 * line, every valid point in it, and every valid edit:
 *   - insert any text of 1..MAX_LINES segments of 0..MAX_COLS characters at any
 *     valid position (one segment means no newline)
 *   - delete between any two valid positions, start <= end
 *
 * The oracle doesn't use adjustPoint's arithmetic. Every character, newline and the
 * end of text has a unique id. The model performs the edit on lists of lines, then
 * looks up where each surviving id ended up. So "expected position" means "wherever
 * the same character now is", except for the two rules adjust.h specifies for
 * characters that don't survive or for points at an insertion.
 *
 * Usage: harness [--stop-first] [max_lines max_cols]. Exit 0 if no failures. */
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int adjustPoint(int *px, int *py, int startx, int starty, int endx, int endy,
		int is_delete);

enum { LMAX = 10, CMAX = 16, IDS = 512, EOF_ID = 0, INS_BASE = 256 };

typedef struct {
	int n;
	int len[LMAX];
	int c[LMAX][CMAX]; /* character ids */
	int nl[LMAX];      /* id of the newline after line i (i < n-1) */
} Text;

static int max_lines = 4, max_cols = 4, stop_first = 0;
static int del_value = 1; /* the is_delete argument used for deletions */

static long total, failures;
/* Coverage of each case, so a pass can't be vacuous. */
static long ins_before, ins_at, ins_at_empty, ins_same_line_after, ins_multi_after,
	ins_later;
static long del_before, del_at_start, del_at_start_empty, del_inside, del_at_end,
	del_after_end_line, del_later;
static long char_kept, char_lost_at_insert, char_lost_del_start, char_lost_del_inside,
	ret1_char_survives;

static int char_at(const Text *t, int x, int y) {
	if (x < t->len[y]) return t->c[y][x];
	if (y < t->n - 1) return t->nl[y];
	return EOF_ID;
}

static int valid(const Text *t, int x, int y) {
	return y >= 0 && y < t->n && x >= 0 && x <= t->len[y];
}

/* (ax,ay) compared with (bx,by) in text order */
static int cmp(int ax, int ay, int bx, int by) {
	if (ay != by) return ay < by ? -1 : 1;
	if (ax != bx) return ax < bx ? -1 : 1;
	return 0;
}

static void assign_ids(Text *t) {
	int id = 1;
	for (int y = 0; y < t->n; y++) {
		for (int x = 0; x < t->len[y]; x++) t->c[y][x] = id++;
		t->nl[y] = id++;
	}
}

static signed char where_x[IDS], where_y[IDS];

static void index_text(const Text *t) {
	memset(where_y, -1, sizeof where_y);
	for (int y = 0; y < t->n; y++) {
		for (int x = 0; x < t->len[y]; x++) {
			where_x[t->c[y][x]] = (signed char)x;
			where_y[t->c[y][x]] = (signed char)y;
		}
		if (y < t->n - 1) {
			where_x[t->nl[y]] = (signed char)t->len[y];
			where_y[t->nl[y]] = (signed char)y;
		}
	}
	where_x[EOF_ID] = (signed char)t->len[t->n - 1];
	where_y[EOF_ID] = (signed char)(t->n - 1);
}

/* Model edits work on lines and never look at any point. */
static void model_insert(const Text *t, int sx, int sy, int k, const int *seg, Text *out,
			 int *ex, int *ey) {
	int id = INS_BASE, ny = 0;
	for (int y = 0; y < sy; y++) {
		out->len[ny] = t->len[y];
		memcpy(out->c[ny], t->c[y], sizeof(int) * (size_t)t->len[y]);
		out->nl[ny] = t->nl[y];
		ny++;
	}
	int cur = 0;
	memcpy(out->c[ny], t->c[sy], sizeof(int) * (size_t)sx);
	cur = sx;
	for (int s = 0; s < k; s++) {
		for (int i = 0; i < seg[s]; i++) out->c[ny][cur++] = id++;
		*ex = cur;
		*ey = ny;
		if (s < k - 1) {
			out->len[ny] = cur;
			out->nl[ny] = id++;
			ny++;
			cur = 0;
		}
	}
	for (int x = sx; x < t->len[sy]; x++) out->c[ny][cur++] = t->c[sy][x];
	out->len[ny] = cur;
	out->nl[ny] = t->nl[sy];
	ny++;
	for (int y = sy + 1; y < t->n; y++) {
		out->len[ny] = t->len[y];
		memcpy(out->c[ny], t->c[y], sizeof(int) * (size_t)t->len[y]);
		out->nl[ny] = t->nl[y];
		ny++;
	}
	out->n = ny;
}

static void model_delete(const Text *t, int sx, int sy, int ex, int ey, Text *out) {
	int ny = 0, cur;
	for (int y = 0; y < sy; y++) {
		out->len[ny] = t->len[y];
		memcpy(out->c[ny], t->c[y], sizeof(int) * (size_t)t->len[y]);
		out->nl[ny] = t->nl[y];
		ny++;
	}
	memcpy(out->c[ny], t->c[sy], sizeof(int) * (size_t)sx);
	cur = sx;
	for (int x = ex; x < t->len[ey]; x++) out->c[ny][cur++] = t->c[ey][x];
	out->len[ny] = cur;
	out->nl[ny] = t->nl[ey];
	ny++;
	for (int y = ey + 1; y < t->n; y++) {
		out->len[ny] = t->len[y];
		memcpy(out->c[ny], t->c[y], sizeof(int) * (size_t)t->len[y]);
		out->nl[ny] = t->nl[y];
		ny++;
	}
	out->n = ny;
}

static void report(const char *why, int x, int y, int sx, int sy, int ex, int ey, int del,
		   int ax, int ay, int ar, int wx, int wy, int wr) {
	failures++;
	if (failures <= 5)
		printf("FAIL %s: p=(%d,%d) start=(%d,%d) end=(%d,%d) del=%d: got (%d,%d)->%d "
		       "want (%d,%d)->%d\n",
		       why, x, y, sx, sy, ex, ey, del, ax, ay, ar, wx, wy, wr);
	if (stop_first) {
		printf("total=%ld failures=%ld\n", total, failures);
		exit(1);
	}
}

static void check(const Text *old, const Text *now, int x, int y, int sx, int sy, int ex,
		  int ey, int del, int wx, int wy, int wr) {
	int ax = x, ay = y;
	int ar = adjustPoint(&ax, &ay, sx, sy, ex, ey, del);
	total++;
	if (ax != wx || ay != wy || ar != wr)
		report("position or return", x, y, sx, sy, ex, ey, del, ax, ay, ar, wx, wy, wr);
	if (!valid(now, ax, ay))
		report("validity", x, y, sx, sy, ex, ey, del, ax, ay, ar, wx, wy, wr);
	(void)old;
}

static void test_insert(const Text *t, int k, const int *seg) {
	Text now;
	for (int sy = 0; sy < t->n; sy++)
		for (int sx = 0; sx <= t->len[sy]; sx++) {
			int ex = 0, ey = 0, nonempty = k > 1 || seg[0] > 0;
			model_insert(t, sx, sy, k, seg, &now, &ex, &ey);
			index_text(&now);
			for (int y = 0; y < t->n; y++)
				for (int x = 0; x <= t->len[y]; x++) {
					int id = char_at(t, x, y), c = cmp(x, y, sx, sy);
					if (c == 0) {
						/* adjust.h: stays there, before the new text */
						if (nonempty) { ins_at++; char_lost_at_insert++; }
						else { ins_at_empty++; char_kept++; }
						check(t, &now, x, y, sx, sy, ex, ey, 0, sx, sy, 0);
						continue;
					}
					if (c < 0) ins_before++;
					else if (y == sy && k == 1) ins_same_line_after++;
					else if (y == sy) ins_multi_after++;
					else ins_later++;
					char_kept++;
					check(t, &now, x, y, sx, sy, ex, ey, 0, where_x[id], where_y[id], 0);
				}
		}
}

static void test_delete(const Text *t) {
	Text now;
	for (int sy = 0; sy < t->n; sy++)
		for (int sx = 0; sx <= t->len[sy]; sx++)
			for (int ey = sy; ey < t->n; ey++)
				for (int ex = (ey == sy ? sx : 0); ex <= t->len[ey]; ex++) {
					model_delete(t, sx, sy, ex, ey, &now);
					index_text(&now);
					for (int y = 0; y < t->n; y++)
						for (int x = 0; x <= t->len[y]; x++) {
							int id = char_at(t, x, y);
							int cs = cmp(x, y, sx, sy), ce = cmp(x, y, ex, ey);
							int wr = cs > 0 && ce <= 0;
							if (cs >= 0 && ce < 0) {
								/* The character was deleted: adjust.h
								 * says the point goes to the start. */
								if (cs == 0) { del_at_start++; char_lost_del_start++; }
								else { del_inside++; char_lost_del_inside++; }
								check(t, &now, x, y, sx, sy, ex, ey, del_value, sx, sy, wr);
								continue;
							}
							/* The character survives. */
							if (cs < 0) del_before++;
							else if (cs == 0) del_at_start_empty++;
							else if (ce == 0) { del_at_end++; ret1_char_survives++; }
							else if (y == ey) del_after_end_line++;
							else del_later++;
							char_kept++;
							check(t, &now, x, y, sx, sy, ex, ey, del_value, where_x[id], where_y[id], wr);
						}
				}
}

static int next_shape(int *a, int n, int base) {
	for (int i = 0; i < n; i++) {
		if (++a[i] < base) return 1;
		a[i] = 0;
	}
	return 0;
}

int main(int argc, char **argv) {
	int ai = 1;
	if (ai < argc && strcmp(argv[ai], "--stop-first") == 0) { stop_first = 1; ai++; }
	if (ai + 1 < argc) { max_lines = atoi(argv[ai]); max_cols = atoi(argv[ai + 1]); }
	if (max_lines < 1 || max_lines > 5 || max_cols < 0 || max_cols > 5) return 2;

	long texts = 0, edits_ins_shapes = 0;
	for (int n = 1; n <= max_lines; n++) {
		int shape[LMAX] = { 0 };
		do {
			Text t;
			t.n = n;
			for (int y = 0; y < n; y++) t.len[y] = shape[y];
			assign_ids(&t);
			texts++;
			test_delete(&t);
			/* C treats any nonzero is_delete as a deletion. These re-runs
			 * add to the delete and same-character counts below. */
			for (int v = 0; v < 3; v++) {
				static const int others[3] = { 2, -1, INT_MIN };
				del_value = others[v];
				test_delete(&t);
			}
			del_value = 1;
			for (int k = 1; k <= max_lines; k++) {
				int seg[LMAX] = { 0 };
				do {
					test_insert(&t, k, seg);
					edits_ins_shapes++;
				} while (next_shape(seg, k, max_cols + 1));
			}
		} while (next_shape(shape, n, max_cols + 1));
	}

	printf("bounds: up to %d lines of up to %d characters; inserted text likewise\n",
	       max_lines, max_cols);
	printf("texts=%ld checks=%ld failures=%ld\n", texts, total, failures);
	printf("insert: before=%ld at(nonempty)=%ld at(empty)=%ld after_same_line=%ld "
	       "after_on_line_multiline=%ld later_line=%ld\n",
	       ins_before, ins_at, ins_at_empty, ins_same_line_after, ins_multi_after, ins_later);
	printf("delete: before=%ld at_start(nonempty)=%ld at_start(empty)=%ld inside=%ld "
	       "at_end=%ld after_on_end_line=%ld later_line=%ld\n",
	       del_before, del_at_start, del_at_start_empty, del_inside, del_at_end,
	       del_after_end_line, del_later);
	printf("same character: kept=%ld lost_at_insert=%ld lost_at_delete_start=%ld "
	       "lost_inside_delete=%ld; returned 1 but character survives=%ld\n",
	       char_kept, char_lost_at_insert, char_lost_del_start, char_lost_del_inside,
	       ret1_char_survives);
	return failures != 0;
}
