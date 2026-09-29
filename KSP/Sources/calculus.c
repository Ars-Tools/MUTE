//
//  calculus.c
//  MUTE
//
//  Created by Kota on 11/22/R6.
//
#include"calculus.h"
__attribute__((always_inline))
void calculus_integration(register double const * __nonnull x,
						  register double const * __nonnull y, // reset
						  register double       * __nonnull z,
						  simd_double2 * __nonnull const w,
						  intptr_t const length) {
	register simd_double2 s = *w;
	for ( register double const * __nonnull const _ = z + length ; z < _ ; ++ x, ++ y, ++ z ) {
		*z = (s = (simd_double2 const) {
			*x,
			(*y<=0) * simd_dot((simd_double3 const){0.5, 1, 0.5}, (simd_double3 const){s.x, s.y, *x})
		}).y;
	}
	*w = s;
}
__attribute__((always_inline))
void calculus_differentiation(register double const * __nonnull x,
							  register double const * __nonnull y, // reset
							  register double       * __nonnull z,
							  simd_double2 * __nonnull const w,
							  intptr_t const length) {
	register simd_double2 s = *w;
	for ( register double const * __nonnull const _ = z + length ; z < _ ; ++ x, ++ y, ++ z )
		*z = (s = (simd_double2 const) {
			*x,
			simd_dot((simd_double3 const){-2, (0<*y) - 1, 2}, (simd_double3 const){s.x, s.y, *x}),
		}).y;
	*w = s;
}
