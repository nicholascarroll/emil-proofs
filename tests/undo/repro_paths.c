/* Real emil paths that break "history matches text".  Linked like driver.c.
 * Each case prints what it saw.  Run with: repro_paths CASE */
#include "emil.h"
#include "buffer.h"
#include "edit.h"
#include "completion.h"
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
		bufferResetRows(b);
		insertRow(b, 0, (const uint8_t *)"\tab", 3);
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
	} else if (!strcmp(c, "completion-file-newline") ||
		   !strcmp(c, "completion-buffer-newline")) {
		/* Names that share only the typed prefix, so a second TAB lists
		 * them in *Completions*, one holding a newline. */
		int files = !strcmp(c, "completion-file-newline");
		makeMinibuffer();
		const char *d = argc > 2 ? argv[2] : ".";
		char a[512], b2[512], t[512];
		struct buffer *cur = make_test_buffer("x");
		E.edbuf = cur;
		if (files) {
			snprintf(a, sizeof a, "%s/xx\nyy", d);
			snprintf(b2, sizeof b2, "%s/xxz", d);
			fclose(fopen(a, "w"));
			fclose(fopen(b2, "w"));
			snprintf(t, sizeof t, "%s/xx", d);
		} else {
			struct buffer *n1 = newBuffer(), *n2 = newBuffer();
			n1->filename = xstrdup("qq\nyy");
			n2->filename = xstrdup("qqz");
			n1->next = n2;
			n2->next = E.headbuf;
			E.headbuf = n1;
			snprintf(t, sizeof t, "qq");
		}
		mutateInsert(E.minibuf, 0, 0, (const uint8_t *)t, (int)strlen(t), NULL, NULL);
		E.minibuf->cx = (int)strlen(t);
		E.minibuf->cy = 0;
		for (int i = 0; i < 2; i++)
			handleMinibufferCompletion(E.minibuf, files ? PROMPT_FILES : PROMPT_BUFFER);
		struct buffer *cb = findOrCreateSpecialBuffer("*Completions*");
		int found = 0;
		for (int i = 0; i < cb->numrows; i++)
			if (cb->row[i].size && memchr(cb->row[i].chars, '\n', cb->row[i].size))
				found = 1;
		show("completions", cb);
		printf("row with newline byte: %s\n", found ? "YES" : "no");
		if (files) {
			remove(a);
			remove(b2);
		}
	} else {
		return 2;
	}
	return 0;
}
