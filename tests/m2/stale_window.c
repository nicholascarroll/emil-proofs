/* Milestone 2 evidence: can adjustPoint receive a point that isn't valid in the
 * current text? Runs emil's real code paths from a copy of its source.
 * A window shows a long line, the file shrinks on disk, and the other window reverts. */
#include "test.h"
#include "test_harness.h"
#include "adjust.h"
#include "fileio.h"
#include "mutate.h"
#include <stdio.h>

void setUp(void) {}
void tearDown(void) {}

static void write_file(const char *p, const char *s) {
	FILE *f = fopen(p, "w");
	fputs(s, f);
	fclose(f);
}

int main(void) {
	const char *path = "/tmp/emil_proofs_stale.txt";
	initTestEditor();
	write_file(path, "abcdefghijklmnopqrst\n");

	struct buffer *buf = newBuffer();
	editorOpen(buf, (char *)path);
	E.buf = buf;
	E.headbuf = buf;
	E.windows = xrealloc(E.windows, 2 * sizeof(struct window *));
	E.windows[1] = xcalloc(1, sizeof(struct window));
	E.nwindows = 2;
	E.windows[0]->buf = buf;
	E.windows[0]->focused = 1;
	E.windows[1]->buf = buf;
	E.windows[1]->focused = 0;
	E.windows[1]->cx = 20;
	E.windows[1]->cy = 0;
	E.registers['q'].rtype = REGISTER_POINT;
	E.registers['q'].data.point.buf = buf;
	E.registers['q'].data.point.cx = 20;
	E.registers['q'].data.point.cy = 0;

	write_file(path, "xy\n");
	revert();

	struct buffer *now = E.buf;
	printf("revert replaced the buffer: %s\n", now != buf ? "yes" : "no");
	printf("row 0 size after revert: %d\n", now->row[0].size);
	printf("other window's point after revert: (%d,%d), valid: %s\n", E.windows[1]->cx,
	       E.windows[1]->cy, E.windows[1]->cx <= now->row[0].size ? "yes" : "NO");
	printf("register q still names the destroyed buffer: %s\n",
	       E.registers['q'].data.point.buf == buf ? "YES" : "no");

	mutateInsert(now, 0, 0, (const uint8_t *)"Z", 1, NULL, NULL);
	printf("after inserting 1 byte at (0,0): row size %d, other window's point (%d,%d), "
	       "valid: %s\n", now->row[0].size, E.windows[1]->cx, E.windows[1]->cy,
	       E.windows[1]->cx <= now->row[0].size ? "yes" : "NO");
	E.registers['q'].rtype = REGISTER_NULL;
	unlink(path);
	return 0;
}
