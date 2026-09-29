//
//  state_variable_filter.h
//  MUTE
//
//  Created by Kota on 11/23/R6.
//
#include<stdint.h>
#include<simd/simd.h>
void state_variable_filter_static(double const * __nonnull x,
								  double * const __nonnull y, intptr_t const ldy,
								  double const p, // phase, [0, 0.5)
								  double const q, // quality
								  simd_double2 * __nonnull const s, // state
								  intptr_t const length);
void state_variable_filter_active(double const * __nonnull x,
								  double * const __nonnull y, intptr_t const ldy,
								  double const * __nonnull p, // phase, [0, 0.5)
								  double const * __nonnull q, // quality
								  simd_double2 * __nonnull const s, // state
								  intptr_t const length);
