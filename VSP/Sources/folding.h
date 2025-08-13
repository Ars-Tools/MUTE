//
//  folding.h
//  MUTE
//
//  Created by Kota on 11/22/R6.
//
#include<stdint.h>
#include<simd/simd.h>
void folding_sup(double const * __nonnull x,
				 double       * __nonnull y,
				 double const * __nonnull z, intptr_t const incz,
				 intptr_t const length);
void folding_inf(double const * __nonnull x,
				 double       * __nonnull y,
				 double const * __nonnull z, intptr_t const incz,
				 intptr_t const length);
void folding_bounds(double const * __nonnull x,
					double       * __nonnull y,
					double const * __nonnull z, intptr_t const incz,
					intptr_t const length);
