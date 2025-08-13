//
//  spline.c
//  MUTE
//
//  Created by Kota on 11/19/R6.
//
#include<Accelerate/Accelerate.h>
#include"spline.h"
__attribute__((visibility("hidden")))
spline_anchor_t const spline_anchor(register double const x,
									register spline_anchor_t const * const anchor,
									intptr_t const length) {
//	for ( register intptr_t k = 0, K = length ; k < K ; ++ k )
//		if ( anchor[k].x.x <= x && x < anchor[k].x.y )
//			return anchor[k];
//	abort();
	register intptr_t lower = 0;
	register intptr_t upper = length - 1;
	while ( lower <= upper ) {
		register intptr_t const split = lower + ( upper - lower ) / 2;
		register simd_long2 const range = x < simd_make_double2(anchor[split].x);
		if (range.x)
			upper = split - 1;
		else if (range.y)
			return anchor[split];
		else
			lower = split + 1;
	}
	return (spline_anchor_t const) {};
}
void spline_interpolation(register double const * __nonnull x,
						  register double       * __nonnull y,
						  spline_anchor_t const * __nonnull const a,
						  intptr_t const anchor, intptr_t const length) {
	spline_anchor_t const(^const search)(double const) = ^(double const x) { // block is faster than functional pointer
		register intptr_t lower = 0;
		register intptr_t upper = length - 1;
		while ( lower <= upper ) { // binary search
			register intptr_t const split = lower + ( upper - lower ) / 2;
			register simd_long2 const range = x < simd_make_double2(a[split].x);
			if (range.x)
				upper = split - 1;
			else if (range.y)
				return a[split];
			else
				lower = split + 1;
		}
		assert("out of rage");
		return (spline_anchor_t const) {};
	};
	for ( register double const * __nonnull const _ = y + length ; y < _ ; ++ x, ++ y ) {
		register spline_anchor_t const s = search(*x);
		register double const t = fma(*x, s.x.z, s.x.w);
		register simd_double2 const w = simd_mix((simd_double2 const){s.y.z, s.y.x}, (simd_double2 const){s.y.w, s.y.y}, t);
		*y = fma(fma(-t, t, t), w.x, w.y);
	}
}
