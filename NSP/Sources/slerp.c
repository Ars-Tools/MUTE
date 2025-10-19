//
//  slerp.c
//  MUTE
//
//  Created by Kota on 9/2/R7.
//
#include"module.h"
#include"slerp.h"
__attribute__((overloadable))
void slerp_shortest(simd_quatd const q0, simd_quatd const q1,
					double const*__nonnull x,
					double      *__nonnull y, intptr_t const ldy,
					intptr_t const length) {
	for ( register double const * __nonnull const X = x + length ; x < X ; ++ x, ++ y ) {
		simd_double4 const v = simd_slerp(q0, q1, *x).vector;
		y[0*ldy] = v.w;
		y[1*ldy] = v.x;
		y[2*ldy] = v.y;
		y[3*ldy] = v.z;
	}
}
__attribute__((overloadable))
void slerp_longest(simd_quatd const q0, simd_quatd const q1,
				   double const*__nonnull x,
				   double      *__nonnull y, intptr_t const ldy,
				   intptr_t const length) {
	for ( register double const * __nonnull const X = x + length ; x < X ; ++ x, ++ y ) {
		simd_double4 const v = simd_slerp_longest(q0, q1, *x).vector;
		y[0*ldy] = v.w;
		y[1*ldy] = v.x;
		y[2*ldy] = v.y;
		y[3*ldy] = v.z;
	}
}
