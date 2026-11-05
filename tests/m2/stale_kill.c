/* Milestone 2 evidence: a second way a stale point reaches adjustPoint, without a revert.
 * Both windows show a long buffer, and that buffer is killed. killBuffer points both windows
 * at the next buffer but leaves the other window's cursor as it was. The fuzzer found this. */
#include "test.h"
#include "test_harness.h"
#include "adjust.h"
#include "mutate.h"
#include "region.h"
#include <stdio.h>

void setUp(void) {}
void tearDown(void) {}

int main(void) {
	initTestEditor();
	const char *short_lines[] = { "ab", "" };
	struct buffer *other = make_test_buffer_lines(short_lines, 2);
	const char *long_lines[] = { "L0", "L1", "L2", "L3", "L4", "L5", "L6", "L7",
				     "a long line in row eight", "" };
	struct buffer *doomed = make_test_buffer_lines(long_lines, 10);
	doomed->next = other; /* the test helper resets the list, so link them */
	E.headbuf = doomed;
	E.buf = doomed;
	E.windows = xrealloc(E.windows, 2 * sizeof(struct window *));
	E.windows[1] = xcalloc(1, sizeof(struct window));
	E.nwindows = 2;
	E.windows[0]->buf = doomed;
	E.windows[0]->focused = 1;
	E.windows[1]->buf = doomed;
	E.windows[1]->focused = 0;
	E.windows[1]->cx = 20;
	E.windows[1]->cy = 8;
	doomed->dirty = 0;
	doomed->special_buffer = 1;

	killBuffer();

	struct window *w = E.windows[1];
	struct buffer *now = w->buf;
	printf("other window now shows the surviving buffer: %s\n", now == other ? "yes" : "no");
	printf("that buffer has %d rows; other window's point: (%d,%d), valid: %s\n", now->numrows,
	       w->cx, w->cy, w->cy < now->numrows ? "yes" : "NO");
	deleteRange(now, 0, 0, 1, 0, 0);
	printf("after deleting 1 byte at (0,0): point (%d,%d), valid: %s\n", w->cx, w->cy,
	       w->cy < now->numrows ? "yes" : "NO");
	return 0;
}
