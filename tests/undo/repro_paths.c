/* Real emil paths that break "history matches text".  Linked like driver.c.
 * Each case prints what it saw.  Run with: repro_paths CASE */
#include "emil.h"
#include "buffer.h"
#include "edit.h"
#include "mutate.h"
#include "undo.h"
#include "test_harness.h"
#include <stdio.h>
#include <string.h>

static void show(const char *what, struct buffer *b) {
	printf("%s:", what);
	for (int i = 0; i < b->numrows; i++) {
		printf(" [");
		for (int j = 0; j < b->row[i].size; j++) {
			uint8_t c = b->row[i].chars[j];
			if (c >= 32 && c < 127) putchar(c); else printf("\\x%02X", c);
		}
		printf("]");
	}
	printf("\n");
	fflush(stdout);
}

static void rec(struct buffer *b) {
	if (b->undo)
		printf("  head record: (%d,%d)-(%d,%d) del=%d datalen=%d\n", b->undo->startx,
		       b->undo->starty, b->undo->endx, b->undo->endy, b->undo->delete,
		       b->undo->datalen);
}

int main(int argc, char **argv) {
	initTestEditor();
	const char *c = argc > 1 ? argv[1] : "";
	if (!strcmp(c, "malformed-delchar")) {
		/* C-d on a lead byte with nothing after it: edit.c:202 */
		const char *lines[] = { "a\xC3", "" };
		struct buffer *b = make_test_buffer_lines(lines, 2);
		b->cx = 1;
		show("start ", b);
		delChar(1);
		show("C-d   ", b); rec(b);
		doUndo(b, 1);
		show("undo  ", b);
		doRedo(b, 1);
		show("redo  ", b);
	} else if (!strcmp(c, "malformed-delchar4")) {
		const char *lines[] = { "a\xF0", "b", "" };
		struct buffer *b = make_test_buffer_lines(lines, 3);
		b->cx = 1;
		show("start ", b);
		delChar(1);
		show("C-d   ", b); rec(b);
		doUndo(b, 1);
		show("undo  ", b);
	} else if (!strcmp(c, "minibuf-tab")) {
		/* prompt.c:356 before the U2 fix */
		struct buffer *b = make_test_buffer("");
		bufferEnsureRow(b);
		E.minibuf = b;
		int ex, ey;
		mutateInsert(b, 0, 0, (const uint8_t *)"ab", 2, &ex, &ey);
		b->cx = 0; b->cy = 0;
		show("typed ", b);
		/* What insertChar did before the U2 fix: a change with no record. */
		rowInsertChar(b, &b->row[0], 0, '\t');
		b->cx = 1;
		show("TAB   ", b);
		doUndo(b, 1);
		show("undo  ", b);
	} else if (!strcmp(c, "special-rebuild")) {
		/* A special buffer made writable with C-x C-q, edited, then rebuilt
		 * through bufferResetRows, which keeps the history. */
		struct buffer *b = make_test_buffer("a long line of register text");
		int ex, ey;
		mutateInsert(b, 20, 0, (const uint8_t *)"x", 1, &ex, &ey);
		show("edited", b);
		bufferResetRows(b);
		insertRow(b, 0, (const uint8_t *)"short", 5);
		show("rebuilt", b);
		doUndo(b, 1);
		show("undo  ", b);
		doRedo(b, 1);
		show("redo  ", b);
	} else {
		return 2;
	}
	return 0;
}
