/* Milestone 0 smoke test: does the ATC prototype link and agree with emil's
 * adjustPoint on a tiny grid? Not the Milestone 1 or 4 test, and not evidence
 * for any claim. The grid doesn't filter for valid edits, so it includes
 * meaningless ones such as an end before the start. */
#include <stdio.h>
#include "tiny.h"
#include "adjust_shape.h"

int emil_adjustPoint(int *px, int *py, int startx, int starty, int endx,
		     int endy, int is_delete);

int main(void) {
	long n = 0, bad = 0;
	const int M = 4;
	for (int x = 0; x < M; x++) for (int y = 0; y < M; y++)
	for (int sx = 0; sx < M; sx++) for (int sy = 0; sy < M; sy++)
	for (int ex = 0; ex < M; ex++) for (int ey = 0; ey < M; ey++)
	for (int del = 0; del < 2; del++) {
		int ax = x, ay = y, bx = x, by = y;
		int ra = emil_adjustPoint(&ax, &ay, sx, sy, ex, ey, del);
		int rb = adjustPoint(&bx, &by, sx, sy, ex, ey, del);
		n++;
		if (ra != rb || ax != bx || ay != by) {
			if (bad++ < 5)
				printf("DIFF p=(%d,%d) s=(%d,%d) e=(%d,%d) del=%d: emil (%d,%d)->%d atc (%d,%d)->%d\n",
				       x, y, sx, sy, ex, ey, del, ax, ay, ra, bx, by, rb);
		}
	}
	printf("add_one(41) = %d\n", add_one(41));
	printf("cases=%ld differences=%ld\n", n, bad);
	return bad != 0 || add_one(41) != 42;
}
