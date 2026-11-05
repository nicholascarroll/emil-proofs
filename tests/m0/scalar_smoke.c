/* Pointer-free prototype smoke test: the wrapper against emil's adjustPoint on a
 * tiny grid, with the pointers aimed at the three kinds of storage emil's callers
 * and ATC's theorem care about. Not the Milestone 1 or 4 test, and not evidence
 * for any claim. The grid includes meaningless edits. */
#include <stdio.h>
#include <stdlib.h>
#include "adjust_wrapper.h"

int emil_adjustPoint(int *px, int *py, int startx, int starty, int endx,
		     int endy, int is_delete);
struct holder { int pad; int cx; int cy; };

int main(void) {
	long n = 0, bad = 0;
	const int M = 4;
	struct holder *h = malloc(sizeof *h);
	int *hx = malloc(sizeof *hx), *hy = malloc(sizeof *hy);
	if (!h || !hx || !hy) return 2;
	for (int x = 0; x < M; x++) for (int y = 0; y < M; y++)
	for (int sx = 0; sx < M; sx++) for (int sy = 0; sy < M; sy++)
	for (int ex = 0; ex < M; ex++) for (int ey = 0; ey < M; ey++)
	for (int del = 0; del < 2; del++) {
		int ax = x, ay = y;
		int ra = emil_adjustPoint(&ax, &ay, sx, sy, ex, ey, del);
		int lx = x, ly = y;                        /* stack locals */
		int rl = adjustPoint(&lx, &ly, sx, sy, ex, ey, del);
		h->cx = x; h->cy = y;                      /* struct members */
		int rm = adjustPoint(&h->cx, &h->cy, sx, sy, ex, ey, del);
		*hx = x; *hy = y;                          /* whole heap objects */
		int rh = adjustPoint(hx, hy, sx, sy, ex, ey, del);
		n++;
		if (ra != rl || ax != lx || ay != ly ||
		    ra != rm || ax != h->cx || ay != h->cy ||
		    ra != rh || ax != *hx || ay != *hy)
			bad++;
	}
	free(h); free(hx); free(hy);
	printf("cases=%ld storage_kinds=3 differences=%ld\n", n, bad);
	return bad != 0;
}
