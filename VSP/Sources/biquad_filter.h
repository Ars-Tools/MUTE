//
//  biquad_filter.h
//  MUTE
//
//  Created by Kota on 8/11/R7.
//
#include<stdint.h>
#include<simd/simd.h>
typedef struct {
	simd_double4 * __nonnull const s;
	intptr_t const z;
} biquad_filter_t;
__attribute__((always_inline)) biquad_filter_t * __nonnull const biquad_filter_create(intptr_t const c);
__attribute__((always_inline)) void biquad_filter_destroy(biquad_filter_t * __nonnull const object);
__attribute__((always_inline)) void biquad_filter_reset(biquad_filter_t * __nonnull const object);
__attribute__((always_inline)) void biquad_filter_active(biquad_filter_t * __nonnull const object,
														 double const * __nonnull B, intptr_t const ldB,
														 double const * __nonnull A, intptr_t const ldA,
														 double const * __nonnull X, intptr_t const ldX,
														 double       * __nonnull Y, intptr_t const ldY,
														 intptr_t const length);
__attribute__((always_inline)) void biquad_filter_convolve_active(double const * __nonnull b, intptr_t const ldb,
																  double const * __nonnull a, intptr_t const lda,
																  double const * __nonnull x,
																  double       * __nonnull y,
																  simd_double4 * __nonnull s,
																  intptr_t const length);
