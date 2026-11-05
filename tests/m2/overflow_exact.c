/* Milestone 2 evidence for claim 4: does the proposed predicate exactly match signed
 * overflow? Every combination of corner values goes through the real C, with UBSan set
 * to abort on overflow, one child process per case. The predicate is computed in 64-bit
 * arithmetic and doesn't use the C function. Any disagreement, either way, is reported.
 *
 * Build with -fsanitize=signed-integer-overflow -fno-sanitize-recover=all.
 * Link one of: emil's adjust.c, or the generated functions plus the wrapper. */
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int adjustPoint(int *px, int *py, int startx, int starty, int endx, int endy,
		int is_delete);

static int in_int(long long v) { return v >= INT_MIN && v <= INT_MAX; }
static int le(long long ax, long long ay, long long bx, long long by) {
	return ay < by || (ay == by && ax <= bx);
}

/* Must match adjust-no-overflow-p in acl2/claims/spec.lisp. */
static int predicate(long long x, long long y, long long sx, long long sy, long long ex,
		     long long ey, int del) {
	long long d = ey - sy;
	if (!in_int(d)) return 0;
	if (del) {
		if (le(x, y, sx, sy) || le(x, y, ex, ey)) return 1;
		if (y == ey) return in_int(x - ex) && in_int(sx + (x - ex));
		return in_int(y - d);
	}
	if (le(x, y, sx, sy)) return 1;
	if (y == sy) {
		if (d == 0) return in_int(ex - sx) && in_int(x + (ex - sx));
		return in_int(x - sx) && in_int(ex + (x - sx)) && in_int(y + d);
	}
	return in_int(y + d);
}

int main(void) {
	static const int V[] = { INT_MIN, INT_MIN + 1, -2, -1, 0, 1, 2, INT_MAX - 1, INT_MAX };
	enum { N = sizeof V / sizeof V[0] };
	long total = 0, ok = 0, overflow = 0, disagree = 0;
	for (int a = 0; a < N; a++) for (int b = 0; b < N; b++)
	for (int c = 0; c < N; c++) for (int d = 0; d < N; d++)
	for (int e = 0; e < N; e++) for (int f = 0; f < N; f++)
	for (int del = 0; del < 2; del++) {
		int x = V[a], y = V[b], sx = V[c], sy = V[d], ex = V[e], ey = V[f];
		int want_ok = predicate(x, y, sx, sy, ex, ey, del);
		fflush(stdout);
		pid_t p = fork();
		if (p == 0) {
			freopen("/dev/null", "w", stderr);
			adjustPoint(&x, &y, sx, sy, ex, ey, del);
			_exit(0);
		}
		int st;
		waitpid(p, &st, 0);
		int got_ok = WIFEXITED(st) && WEXITSTATUS(st) == 0;
		total++;
		if (got_ok) ok++; else overflow++;
		if (got_ok != want_ok && disagree++ < 10)
			printf("DISAGREE p=(%d,%d) s=(%d,%d) e=(%d,%d) del=%d predicate=%d c=%d\n",
			       x, y, sx, sy, ex, ey, del, want_ok, got_ok);
	}
	printf("corner cases=%ld no_overflow=%ld overflow=%ld disagreements=%ld\n", total, ok,
	       overflow, disagree);
	return disagree != 0;
}
