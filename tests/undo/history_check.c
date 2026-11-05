/* After every key of emil's key fuzzer, check that each buffer's history matches its
 * text: the assumption undo replay relies on but doesn't check.  This is the C
 * counterpart of history-matches-p in acl2/undo/model.lisp.
 *
 * #included into a copy of tests/fuzz_keys.c by fuzz_history.sh.  emil is not changed. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct hc_text { uint8_t *b; int len, cap; };

static void hc_load(struct hc_text *t, struct buffer *buf) {
	t->len = 0;
	for (int i = 0; i < buf->numrows; i++) {
		int need = t->len + buf->row[i].size + 1;
		if (need + 1 > t->cap) {
			t->cap = need * 2 + 64;
			t->b = realloc(t->b, t->cap);
		}
		memcpy(t->b + t->len, buf->row[i].chars, buf->row[i].size);
		t->len += buf->row[i].size;
		if (i + 1 < buf->numrows) t->b[t->len++] = '\n';
	}
}

/* Byte offset of (x, y), or -1 if there is no such position. */
static int hc_offset(const struct hc_text *t, int x, int y) {
	int o = 0, row = 0;
	if (x < 0 || y < 0) return -1;
	while (row < y) {
		const uint8_t *nl = o <= t->len ? memchr(t->b + o, '\n', t->len - o) : NULL;
		if (!nl) return -1;
		o = (int)(nl - t->b) + 1;
		row++;
	}
	const uint8_t *nl = memchr(t->b + o, '\n', t->len - o);
	int rowlen = (nl ? (int)(nl - t->b) : t->len) - o;
	return x <= rowlen ? o + x : -1;
}

static void hc_splice_in(struct hc_text *t, int o, const uint8_t *d, int n) {
	if (t->len + n + 1 > t->cap) {
		t->cap = (t->len + n) * 2 + 64;
		t->b = realloc(t->b, t->cap);
	}
	memmove(t->b + o + n, t->b + o, t->len - o);
	memcpy(t->b + o, d, n);
	t->len += n;
}

static void hc_splice_out(struct hc_text *t, int o, int n) {
	memmove(t->b + o, t->b + o + n, t->len - o - n);
	t->len -= n;
}

static void hc_fail(struct buffer *buf, const char *list, int i, const struct undo *u,
		    const char *why) {
	fprintf(stderr, "HISTORY-MISMATCH %s: %s record %d: range (%d,%d)-(%d,%d) del=%d "
		"datalen=%d buffer=%s\n", why, list, i, u->startx, u->starty, u->endx, u->endy,
		u->delete, u->datalen,
		buf == E.minibuf ? "minibuf" : (buf->special_buffer ? "special" : "file"));
	abort();
}

/* APPLY_DEL: walking towards a state where this record's data must be present. */
static void hc_walk(struct buffer *buf, struct hc_text *t, const struct undo *u,
		    const char *list, int is_redo) {
	for (int i = 0; u; u = u->prev, i++) {
		int ex, ey;
		computeInsertEnd(u->data, u->datalen, u->startx, u->starty, &ex, &ey);
		if (ex != u->endx || ey != u->endy)
			hc_fail(buf, list, i, u, "end-not-data-end");
		int must_be_present = is_redo ? u->delete : !u->delete;
		int o = hc_offset(t, u->startx, u->starty);
		if (o < 0)
			hc_fail(buf, list, i, u, "start-not-in-text");
		if (must_be_present) {
			int e = hc_offset(t, u->endx, u->endy);
			if (e < 0)
				hc_fail(buf, list, i, u, "end-not-in-text");
			if (e - o != u->datalen ||
			    memcmp(t->b + o, u->data, u->datalen) != 0)
				hc_fail(buf, list, i, u, "text-differs-from-record");
			hc_splice_out(t, o, u->datalen);
		} else {
			hc_splice_in(t, o, u->data, u->datalen);
		}
	}
}

static unsigned long hc_checks, hc_records;

static void hc_check_buffer(struct buffer *buf) {
	static struct hc_text t;
	if (!buf->undo && !buf->redo)
		return;
	hc_checks++;
	hc_load(&t, buf);
	hc_walk(buf, &t, buf->undo, "undo", 0);
	hc_load(&t, buf);
	hc_walk(buf, &t, buf->redo, "redo", 1);
}

static void historyCheckAll(void) {
	for (struct buffer *b = E.headbuf; b; b = b->next)
		if (b != E.minibuf)
			hc_check_buffer(b);
	if (E.minibuf && !getenv("HC_SKIP_MINIBUF"))
		hc_check_buffer(E.minibuf);
	(void)hc_records;
}
