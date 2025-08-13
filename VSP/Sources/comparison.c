//
//  comparison.c
//  MUTE
//
//  Created by Kota on 11/13/R6.
//
#include"comparison.h"
void comparison_eq(register double const * __nonnull x, register intptr_t const incx,
				   register double const * __nonnull y, register intptr_t const incy,
				   register double       * __nonnull z, register intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull w = z + length * incz ; z < w ; x += incx, y += incy, z += incz )
		*z = *x == *y;
}
void comparison_ne(register double const * __nonnull x, register intptr_t const incx,
				   register double const * __nonnull y, register intptr_t const incy,
				   register double       * __nonnull z, register intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull w = z + length * incz ; z < w ; x += incx, y += incy, z += incz )
		*z = *x != *y;
}
void comparison_lt(register double const * __nonnull x, register intptr_t const incx,
				   register double const * __nonnull y, register intptr_t const incy,
				   register double       * __nonnull z, register intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull w = z + length * incz ; z < w ; x += incx, y += incy, z += incz )
		*z = *x < *y;
}
void comparison_gt(register double const * __nonnull x, register intptr_t const incx,
				   register double const * __nonnull y, register intptr_t const incy,
				   register double       * __nonnull z, register intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull w = z + length * incz ; z < w ; x += incx, y += incy, z += incz )
		*z = *x < *y;
}
void comparison_le(register double const * __nonnull x, register intptr_t const incx,
				   register double const * __nonnull y, register intptr_t const incy,
				   register double       * __nonnull z, register intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull w = z + length * incz ; z < w ; x += incx, y += incy, z += incz )
		*z = *x <= *y;
}
void comparison_ge(register double const * __nonnull x, register intptr_t const incx,
				   register double const * __nonnull y, register intptr_t const incy,
				   register double       * __nonnull z, register intptr_t const incz, intptr_t const length) {
	for ( register double * __nonnull w = z + length * incz ; z < w ; x += incx, y += incy, z += incz )
		*z = *x >= *y;
}
//void comparison_lt(double const * __nonnull const X, intptr_t const ldx,
//				   double const * __nonnull const Y, intptr_t const ldy,
//				   double       * __nonnull const Z, intptr_t const ldz,
//				   intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		register double const * __nonnull y = Y + c * ldy;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ y, ++ z )
//			*z = *x < *y;
//	}
//}
//void comparison_gt(double const * __nonnull const X, intptr_t const ldx,
//				   double const * __nonnull const Y, intptr_t const ldy,
//				   double       * __nonnull const Z, intptr_t const ldz,
//				   intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		register double const * __nonnull y = Y + c * ldy;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ y, ++ z )
//			*z = *x > *y;
//	}
//}
//void comparison_le(double const * __nonnull const X, intptr_t const ldx,
//				   double const * __nonnull const Y, intptr_t const ldy,
//				   double       * __nonnull const Z, intptr_t const ldz,
//				   intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		register double const * __nonnull y = Y + c * ldy;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ y, ++ z )
//			*z = *x <= *y;
//	}
//}
//void comparison_ge(double const * __nonnull const X, intptr_t const ldx,
//				   double const * __nonnull const Y, intptr_t const ldy,
//				   double       * __nonnull const Z, intptr_t const ldz,
//				   intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		register double const * __nonnull y = Y + c * ldy;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ y, ++ z )
//			*z = *x >= *y;
//	}
//}
//void comparison_lts(double const * __nonnull const X, intptr_t const ldx,
//					double const Y,
//					double       * __nonnull const Z, intptr_t const ldz,
//					intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ z )
//			*z = *x < Y;
//	}
//}
//void comparison_gts(double const * __nonnull const X, intptr_t const ldx,
//					double const Y,
//					double       * __nonnull const Z, intptr_t const ldz,
//					intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ z )
//			*z = *x > Y;
//	}
//}
//void comparison_les(double const * __nonnull const X, intptr_t const ldx,
//					double const Y,
//					double       * __nonnull const Z, intptr_t const ldz,
//					intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ z )
//			*z = *x <= Y;
//	}
//}
//void comparison_ges(double const * __nonnull const X, intptr_t const ldx,
//					double const Y,
//					double       * __nonnull const Z, intptr_t const ldz,
//					intptr_t const stream, intptr_t const length) {
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull x = X + c * ldx;
//		for ( register double * __nonnull z = Z + c * ldz, * __nonnull const w = z + length ; z < w ; ++ x, ++ z )
//			*z = *x >= Y;
//	}
//}
