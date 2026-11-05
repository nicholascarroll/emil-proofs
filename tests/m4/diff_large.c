/* Milestone 4: compare the two versions on values the M1 domain can't reach.
 *   1. Random values across the whole int range, kept only if within the proven guard.
 *   2. Values near the guard's boundary, built from INT_MAX and small offsets.
 *   3. Invalid points: small values with no validity filter, including stale and negative
 *      points such as those emil's windows can hold. Every one is checked against the guard.
 * Usage: diff_large [random_count]. Exit 0 if no differences. Build with UBSan to confirm
 * nothing inside the guard overflows. */
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
int emil_adjustPoint(int *px, int *py, int sx, int sy, int ex, int ey, int del);
int gen_adjustPoint(int *px, int *py, int sx, int sy, int ex, int ey, int del);

static int in_int(long long v) { return v >= INT_MIN && v <= INT_MAX; }
static int le(long long ax, long long ay, long long bx, long long by) {
	return ay < by || (ay == by && ax <= bx);
}
/* Must match adjust-no-overflow-p in acl2/claims/spec.lisp. */
static int guard(long long x, long long y, long long sx, long long sy, long long ex, long long ey, int del) {
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

static uint64_t st = 0x9E3779B97F4A7C15ull;
static uint64_t rnd(void) { st ^= st << 13; st ^= st >> 7; st ^= st << 17; return st; }
static long tested, skipped, diffs;

static void one(int x, int y, int sx, int sy, int ex, int ey, int del) {
	if (!guard(x, y, sx, sy, ex, ey, del)) { skipped++; return; }
	int ax = x, ay = y, bx = x, by = y;
	int ra = emil_adjustPoint(&ax, &ay, sx, sy, ex, ey, del);
	int rb = gen_adjustPoint(&bx, &by, sx, sy, ex, ey, del);
	tested++;
	if (ra != rb || ax != bx || ay != by) {
		if (diffs++ < 10)
			printf("DIFF p=(%d,%d) s=(%d,%d) e=(%d,%d) del=%d: emil (%d,%d)->%d generated (%d,%d)->%d\n",
			       x, y, sx, sy, ex, ey, del, ax, ay, ra, bx, by, rb);
	}
}
static void phase(const char *name) {
	printf("%-34s tested=%ld outside_guard=%ld differences=%ld\n", name, tested, skipped, diffs);
	tested = skipped = 0;
}
static int near(void) {
	static const long long base[] = { 0, INT_MAX, INT_MIN, 128, 32767, 32768, 1073741823, 1073741824 };
	long long v = base[rnd() % 8] + (long long)(rnd() % 7) - 3;
	if (v > INT_MAX) v = INT_MAX;
	if (v < INT_MIN) v = INT_MIN;
	return (int)v;
}
int main(int argc, char **argv) {
	long n = argc > 1 ? atol(argv[1]) : 100000000L;
	for (long i = 0; i < n; i++)
		one((int)rnd(), (int)rnd(), (int)rnd(), (int)rnd(), (int)rnd(), (int)rnd(), (int)(rnd() & 1));
	phase("random, whole int range");
	for (long i = 0; i < n; i++) /* ordered and non-negative, like real edits, but large */ {
		int sy = (int)(rnd() % 2147483647u), ey = sy + (int)(rnd() % (uint64_t)(2147483647u - (unsigned)sy));
		int sx = (int)(rnd() % 2147483647u), ex = sy == ey ? sx + (int)(rnd() % (uint64_t)(2147483647u - (unsigned)sx)) : (int)(rnd() % 2147483647u);
		int y = (rnd() & 1) ? sy : (rnd() & 1) ? ey : (int)(rnd() % 2147483647u);
		int x = (int)(rnd() % 2147483647u);
		one(x, y, sx, sy, ex, ey, (int)(rnd() & 1));
	}
	phase("random, ordered non-negative");
	for (long i = 0; i < n; i++)
		one(near(), near(), near(), near(), near(), near(), (int)(rnd() & 1));
	phase("near INT_MAX, 128, 32768, 2^30");
	for (int x = -2; x < 8; x++) for (int y = -2; y < 8; y++)
	for (int sx = -2; sx < 8; sx++) for (int sy = -2; sy < 8; sy++)
	for (int ex = -2; ex < 8; ex++) for (int ey = -2; ey < 8; ey++)
	for (int d = 0; d < 2; d++)
		one(x, y, sx, sy, ex, ey, d);
	phase("small grid, no validity filter");
	/* The reproduced stale points, against every small edit */
	static const int stale[][2] = { { 20, 0 }, { 21, 0 }, { 20, 8 }, { 34, 0 }, { 0, 14 }, { 5, 3 }, { -1, -1 } };
	for (unsigned s = 0; s < sizeof stale / sizeof stale[0]; s++)
	for (int sx = 0; sx < 10; sx++) for (int sy = 0; sy < 10; sy++)
	for (int ex = 0; ex < 10; ex++) for (int ey = 0; ey < 10; ey++)
	for (int d = 0; d < 2; d++)
		one(stale[s][0], stale[s][1], sx, sy, ex, ey, d);
	phase("stale points against small edits");
	printf("total differences=%ld\n", diffs);
	return diffs != 0;
}
