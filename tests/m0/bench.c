#define _POSIX_C_SOURCE 199309L
/* Rough, preliminary timing for the Milestone 0 report. Milestone 4 owns the real
 * comparison. Uses a mix of valid-looking edits and points. */
#include <stdio.h>
#include <time.h>
int adjustPoint(int *px, int *py, int startx, int starty, int endx, int endy,
		int is_delete);
int main(void) {
	unsigned s = 12345;
	long sum = 0;
	struct timespec a, b;
	clock_gettime(CLOCK_MONOTONIC, &a);
	for (long i = 0; i < 200000000L; i++) {
		s = s * 1664525u + 1013904223u;
		int x = (s >> 8) & 63, y = (s >> 14) & 63, sx = (s >> 20) & 63;
		int sy = (s >> 26) & 31, ex = sx + 3, ey = sy + (int)(s & 3);
		sum += adjustPoint(&x, &y, sx, sy, ex, ey, (int)((s >> 4) & 1));
		sum += x + y;
	}
	clock_gettime(CLOCK_MONOTONIC, &b);
	printf("%.2f ns/call (checksum %ld)\n",
	       ((double)(b.tv_sec - a.tv_sec) * 1e9 + (double)(b.tv_nsec - a.tv_nsec)) / 2e8, sum);
	return 0;
}
