/* Milestone 4: run the M1 harness's whole domain through both versions. Called as adjustPoint
 * by tests/m1/harness.c; returns emil's answer, so the harness also checks the model. */
#include <stdio.h>
int emil_adjustPoint(int *px, int *py, int sx, int sy, int ex, int ey, int del);
int gen_adjustPoint(int *px, int *py, int sx, int sy, int ex, int ey, int del);
long shim_calls, shim_diffs;
int adjustPoint(int *px, int *py, int sx, int sy, int ex, int ey, int del) {
	int ax = *px, ay = *py, bx = *px, by = *py;
	int ra = emil_adjustPoint(&ax, &ay, sx, sy, ex, ey, del);
	int rb = gen_adjustPoint(&bx, &by, sx, sy, ex, ey, del);
	shim_calls++;
	if (ra != rb || ax != bx || ay != by) {
		if (shim_diffs++ < 10)
			fprintf(stderr, "DIFF p=(%d,%d) s=(%d,%d) e=(%d,%d) del=%d: emil (%d,%d)->%d generated (%d,%d)->%d\n",
				*px, *py, sx, sy, ex, ey, del, ax, ay, ra, bx, by, rb);
	}
	*px = ax; *py = ay;
	return ra;
}
__attribute__((destructor)) static void report(void) {
	printf("differential: calls=%ld differences=%ld\n", shim_calls, shim_diffs);
}
