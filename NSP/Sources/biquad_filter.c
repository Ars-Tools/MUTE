//
//  biquad_filter.c
//  MUTE
//
//  Created by Kota on 8/11/R7.
//
#include"module.h"
#include"biquad_filter.h"
__attribute__((always_inline))
biquad_filter_t * __nonnull const biquad_filter_create(intptr_t const c) {
    biquad_filter_t * const object = __malloc__(sizeof(intptr_t const) + c * sizeof(simd_double4 const));
    *(intptr_t*__nonnull const)object = c;
	biquad_filter_reset(object);
	return object;
}
__attribute__((always_inline))
void biquad_filter_destroy(biquad_filter_t * __nonnull const object) {
	__free__(object);
}
__attribute__((always_inline))
void biquad_filter_reset(biquad_filter_t * __nonnull const object) {
    memset(object->s, 0, object->z * sizeof(simd_double4 const));
}
__attribute__((always_inline))
void biquad_filter_active(biquad_filter_t * __nonnull const object,
						  double const * __nonnull B, intptr_t const ldB,
						  double const * __nonnull A, intptr_t const ldA,
						  double const * __nonnull X, intptr_t const ldX,
						  double       * __nonnull Y, intptr_t const ldY,
						  intptr_t const length) {
	for ( register intptr_t c = object->z ; 0 < c -- ; )
		biquad_filter_convolve_active(B, ldB,
									  A, ldA,
									  X + ldX * c,
									  Y + ldY * c,
									  object->s + c,
									  length);
}
