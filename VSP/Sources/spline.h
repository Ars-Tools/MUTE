//
//  spline.h
//  MUTE
//
//  Created by Kota on 11/19/R6.
//
#include<stdint.h>
#include<simd/simd.h>
typedef struct {
	simd_double4 const x;
	simd_double4 const y;
} spline_anchor_t;
void spline_interpolation(register double const * __nonnull X,
						  register double       * __nonnull Y,
						  spline_anchor_t const * __nonnull const A,
						  intptr_t const anchor, intptr_t const length);
