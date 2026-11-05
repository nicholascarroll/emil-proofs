/* Hand-written wrapper keeping emil's signature. NOT covered by any theorem.
 * It holds all the pointer work; the generated functions see only int values.
 * Each result is computed from the same copies, taken before either write. */
#include "adjust_wrapper.h"
#include "adjust_scalar.h"

int adjustPoint(int *px, int *py, int startx, int starty, int endx, int endy,
		int is_delete) {
	const int x = *px;
	const int y = *py;

	*px = adjust_new_x(x, y, startx, starty, endx, endy, is_delete);
	*py = adjust_new_y(x, y, startx, starty, endx, endy, is_delete);
	return adjust_clamped(x, y, startx, starty, endx, endy, is_delete);
}
