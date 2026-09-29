//
//  folding.c
//  MUTE
//
//  Created by Kota on 11/22/R6.
//
#include"module.h"
#include"folding.h"
void folding_sup(register double const * __nonnull x,
				 register double       * __nonnull y,
				 register double const * __nonnull z, register intptr_t const incz,
				 intptr_t const length) {
	for ( register double const * __nonnull const w = y + length ; y < w ; ++ x, ++ y, z += incz )
		*y = simd_min(*x, *z) - simd_max(*x - *z, 0);
}
void folding_inf(register double const * __nonnull x,
				 register double       * __nonnull y,
				 register double const * __nonnull z, register intptr_t const incz,
				 intptr_t const length) {
	for ( register double const * __nonnull const w = y + length ; y < w ; ++ x, ++ y, z += incz )
		*y = simd_max(*x, *z) - simd_min(*x - *z, 0);
}
void folding_bounds(register double const * __nonnull x,
					register double       * __nonnull y,
					register double const * __nonnull z, register intptr_t const incz,
					intptr_t const length) {
	for ( register double const * __nonnull const w = y + length ; y < w ; ++ x, ++ y, z += incz ) {
		register double const
			u = *x,
			v = fabs(*z),
			s = v + fabs(u),
			t = v * 2;
//		*y = (signbit(u) ? v - fmod(s, t) : fmod(s, t) - v) * fma(fmod(floor(s / t), 2), -2, 1);
		*y = simd_sign(u) * (fmod(s, t) - v) * fma(fmod(floor(s / t), 2), -2, 1);
	}
}
