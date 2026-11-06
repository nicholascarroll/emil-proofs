#!/usr/bin/env python3
"""Evidence for Stage 2, not a change to emil: patch an exported copy so every mutation logs
its call site, whether its range is invalid, and whether old_text differs from the range.
Usage: instrument.py SRC_DIR"""
import sys, re
d = sys.argv[1]
h = open(d+'/mutate.h').read()
h = h.replace("#endif\n", """
extern const char *mutate_site;
#define MSTR2(x) #x
#define MSTR(x) MSTR2(x)
#ifndef MUTATE_C_INTERNAL
#define MSITE (mutate_site = __FILE__ ":" MSTR(__LINE__))
#define mutateReplace(...) (MSITE, mutateReplace(__VA_ARGS__))
#define mutateDelete(...) (MSITE, mutateDelete(__VA_ARGS__))
#define mutateInsert(...) (MSITE, mutateInsert(__VA_ARGS__))
#define mutateInsertChar(...) (MSITE, mutateInsertChar(__VA_ARGS__))
#define mutateDeleteChar(...) (MSITE, mutateDeleteChar(__VA_ARGS__))
#endif
#endif
""",1) if h.rstrip().endswith("#endif") else h
open(d+'/mutate.h','w').write(h)
m = open(d+'/mutate.c').read()
m = '#define MUTATE_C_INTERNAL 1\n' + m
m = m.replace('/* Final-newline invariant:', r'''#include <stdio.h>
const char *mutate_site = "unknown";
static void mlog(const char *what) {
	const char *p = getenv("MUTATE_LOG");
	if (!p) return;
	FILE *f = fopen(p, "a");
	if (f) { fprintf(f, "%s %s\n", what, mutate_site ? mutate_site : "?"); fclose(f); }
}
static int mvalid(struct buffer *b, int sx, int sy, int ex, int ey) {
	if (sx < 0 || sy < 0 || ex < 0 || ey < 0) return 0;
	if (sy >= b->numrows || ey >= b->numrows) return 0;
	if (sx > b->row[sy].size || ex > b->row[ey].size) return 0;
	return sy < ey || (sy == ey && sx <= ex);
}
/* Final-newline invariant:''',1)
m = m.replace('''	/* Before clearRedos; out-params untouched on refusal. */
	if (rejectIfReadOnly(buf))
		return;
''','''	/* Before clearRedos; out-params untouched on refusal. */
	if (rejectIfReadOnly(buf))
		return;
	mlog("CALL");
	if (!mvalid(buf, startx, starty, endx, endy)) {
		mlog("INVALID-RANGE");
	} else {
		int cl;
		uint8_t *c = collectRegionText(buf, startx, starty, endx, endy, &cl);
		if (cl != old_len)
			mlog("OLD-TEXT-LENGTH-DIFFERS");
		else if (cl > 0 && memcmp(c, old_text, cl) != 0)
			mlog("OLD-TEXT-BYTES-DIFFER");
		free(c);
	}
''',1)
open(d+'/mutate.c','w').write(m)
