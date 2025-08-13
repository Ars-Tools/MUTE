//
//  calculus.h
//  MUTE
//
//  Created by Kota on 11/22/R6.
//
#include<stdint.h>
#include<simd/simd.h>
void calculus_integration(double const * __nonnull x,
						  double const * __nonnull y,
						  double       * __nonnull z,
						  simd_double2 * __nonnull const w,
						  intptr_t const length);
void calculus_differentiation(double const * __nonnull x,
							  double const * __nonnull y,
							  double       * __nonnull z,
							  simd_double2 * __nonnull const w,
							  intptr_t const length);
