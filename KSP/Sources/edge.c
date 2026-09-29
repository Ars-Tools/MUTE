//
//  edge.c
//  MUTE
//
//  Created by Kota on 11/14/R6.
//
#include"edge.h"
// detect rise edge
void edge_rise(double const * __nonnull const X, intptr_t const ldX,
			   double       * __nonnull const Y, intptr_t const ldY,
			   bool         * __nonnull const S,
			   dispatch_source_t const __nullable notify, intptr_t const offset,
			   intptr_t const stream, intptr_t const length) {
	for ( register intptr_t c = stream ; 0 < c -- ; ) {
		register bool s = S[c];
		register double const * __nonnull x = X + c * ldX;
		for ( register double * __nonnull y = Y + c * ldY, * __nonnull const w = y + length ; y < w ; ++ x, ++ y )
			if ((*y = (s ^ (bool const)*x) && (s = (bool const)*x)) && notify)
				dispatch_source_merge_data(notify, offset + w - y);
		S[c] = s;
	}
}
// detect fall edge
void edge_fall(double const * __nonnull const X, intptr_t const ldX,
			   double       * __nonnull const Y, intptr_t const ldY,
			   bool         * __nonnull const S,
			   dispatch_source_t const __nullable notify, intptr_t const offset,
			   intptr_t const stream, intptr_t const length) {
	for ( register intptr_t c = stream ; 0 < c -- ; ) {
		register bool s = S[c];
		register double const * __nonnull x = X + c * ldX;
		for ( register double * __nonnull y = Y + c * ldY, * __nonnull const w = y + length ; y < w ; ++ x, ++ y )
			if ((*y = (s ^ (bool const)*x) && !(s = *x)) && notify)
				dispatch_source_merge_data(notify, offset + w - y);
		S[c] = s;
	}
}
// a.k.a. sample & hold, thru signal while gate is true, capture signal when gate will close
void edge_hold(double const * __nonnull const X, intptr_t const ldX,
			   double const * __nonnull const Y, intptr_t const ldY,
			   double       * __nonnull const Z, intptr_t const ldZ,
			   double       * __nonnull const S,
			   intptr_t const stream, intptr_t const length) {
	for ( register intptr_t c = stream ; 0 < c -- ; ) {
		register double s = S[c];
		register double const * __nonnull x = X + c * ldX;
		register double const * __nonnull y = Y + c * ldY;
		for ( register double * __nonnull z = Z + c * ldZ, * __nonnull const w = z + length ; z < w ; ++ x, ++ y, ++ z )
			*z = *y ? (s = *x) : s;
		S[c] = s;
	}
}
