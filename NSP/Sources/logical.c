//
//  logical.c
//  MUTE
//
//  Created by Kota on 11/13/R6.
//
#include"logical.h"
void logical_true(register double const * __nonnull x, intptr_t const incx,
				  register double       * __nonnull y, intptr_t const incy, intptr_t const length) {
	for ( register double * __nonnull const w = y + length * incy ; y < w ; x += incx, y += incy )
		*y = !!*x;
}
void logical_not(register double const * __nonnull x, intptr_t const incx,
				 register double       * __nonnull y, intptr_t const incy, intptr_t const length) {
	for ( register double * __nonnull const w = y + length * incy ; y < w ; x += incx, y += incy )
		*y = !*x;
}
void logical_and(register double const * __nonnull x, intptr_t const incx,
				 register double const * __nonnull y, intptr_t const incy,
				 register double       * __nonnull z, intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull const w = z + length * incz ; y < w ; x += incx, y += incy, z += incz )
		*z = *x && *y;
}
void logical_or(register double const * __nonnull x, intptr_t const incx,
				register double const * __nonnull y, intptr_t const incy,
				register double       * __nonnull z, intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull const w = z + length * incz ; y < w ; x += incx, y += incy, z += incz )
		*z = *x || *y;
}
void logical_nand(register double const * __nonnull x, intptr_t const incx,
				  register double const * __nonnull y, intptr_t const incy,
				  register double       * __nonnull z, intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull const w = z + length * incz ; y < w ; x += incx, y += incy, z += incz )
		*z = !(*x && *y);
}
void logical_nor(register double const * __nonnull x, intptr_t const incx,
				 register double const * __nonnull y, intptr_t const incy,
				 register double       * __nonnull z, intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull const w = z + length * incz ; y < w ; x += incx, y += incy, z += incz )
		*z = !(*x || *y);
}
void logical_xor(register double const * __nonnull x, intptr_t const incx,
				 register double const * __nonnull y, intptr_t const incy,
				 register double       * __nonnull z, intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull const w = z + length * incz ; y < w ; x += incx, y += incy, z += incz )
		*z = (*x || *y) && !(*x && *y);
}
void logical_xnor(register double const * __nonnull x, intptr_t const incx,
				  register double const * __nonnull y, intptr_t const incy,
				  register double       * __nonnull z, intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull const w = z + length * incz ; y < w ; x += incx, y += incy, z += incz )
		*z = !(*x || *y) && (*x && *y);
}
void logical_imply(register double const * __nonnull x, intptr_t const incx,
				   register double const * __nonnull y, intptr_t const incy,
				   register double       * __nonnull z, intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull const w = z + length * incz ; y < w ; x += incx, y += incy, z += incz )
		*z = !*x || *y;
}
void logical_select(register double const * __nonnull x, intptr_t const incx,
                    register double const * __nonnull y, intptr_t const incy,
                    register double const * __nonnull z, intptr_t const incz,
                    register double       * __nonnull w, intptr_t const incw, intptr_t const length) {
    for ( register double * __nonnull const _ = w + length * incw ; w < _ ; x += incx, y += incy, z += incz, w += incw )
        *w = 0 < *z ? *y : *x;
}
