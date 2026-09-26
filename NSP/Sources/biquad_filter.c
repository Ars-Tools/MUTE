//
//  biquad_filter.c
//  MUTE
//
//  Created by Kota on 8/11/R7.
//
#include"module.h"
#include"biquad_filter.h"
__attribute__((overloadable))
biquad_filter_t * __nonnull const biquad_filter_create(intptr_t const c) {
    biquad_filter_t * const object = __malloc__(sizeof(biquad_filter_t const) + c * sizeof(simd_double4 const));
    *(intptr_t*__nonnull const)&object->z = c;
	biquad_filter_reset(object);
	return object;
}
__attribute__((overloadable))
void biquad_filter_destroy(biquad_filter_t * __nonnull const object) {
	__free__(object);
}
__attribute__((overloadable))
void biquad_filter_reset(biquad_filter_t * __nonnull const object) {
    memset(object->s, 0, object->z * sizeof(simd_double4 const));
}
__attribute__((overloadable))
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
__attribute__((overloadable))
void biquad_filter_active(biquad_filter_t * __nonnull const object,
                          double const * __nonnull B0, intptr_t const ldB0,
                          double const * __nonnull B1, intptr_t const ldB1,
                          double const * __nonnull B2, intptr_t const ldB2,
                          double const * __nonnull A0, intptr_t const ldA0,
                          double const * __nonnull A1, intptr_t const ldA1,
                          double const * __nonnull A2, intptr_t const ldA2,
                          double const * __nonnull X, intptr_t const ldX,
                          double       * __nonnull Y, intptr_t const ldY,
                          intptr_t const length) {
    for ( register intptr_t c = object->z ; 0 < c -- ; )
        biquad_filter_convolve_active(B0 + c * ldB0,
                                      B1 + c * ldB1,
                                      B2 + c * ldB2,
                                      A0 + c * ldA0,
                                      A1 + c * ldA1,
                                      A2 + c * ldA2,
                                      X + c * ldX,
                                      Y + c * ldY,
                                      object->s + c,
                                      length);
}
__attribute__((overloadable))
biquad_filterbank_t * __nonnull const biquad_filter_create(intptr_t const order, intptr_t const count) {
    biquad_filterbank_t * const object = __malloc__(sizeof(biquad_filterbank_t const) + count * order * sizeof(simd_double4 const));
    *(intptr_t*__nonnull const)&object->order = order;
    *(intptr_t*__nonnull const)&object->count = count;
    biquad_filter_reset(object);
    return object;
}
__attribute__((overloadable)) void biquad_filter_destroy(biquad_filterbank_t * __nonnull const object) {
    __free__(object);
}
__attribute__((overloadable)) void biquad_filter_reset(biquad_filterbank_t * __nonnull const object) {
    memset(object->state, 0, object->count * object->order * sizeof(simd_double4 const));
}
__attribute__((overloadable)) void biquad_filter_active(biquad_filterbank_t * __nonnull const object,
                                                        double const * __nonnull B, intptr_t const ldB,
                                                        double const * __nonnull A, intptr_t const ldA,
                                                        double const * __nonnull X, intptr_t const ldX,
                                                        double       * __nonnull Y, intptr_t const ldY,
                                                        intptr_t const length) {
    for ( register intptr_t c = object->count ; 0 < c -- ; )
        biquad_filter_convolve_active(B + ldB * c * object->order * 3, ldB,
                                      A + ldA * c * object->order * 3, ldA,
                                      X + ldX * c,
                                      Y + ldY * c,
                                      object->state, object->order,
                                      length);
}
__attribute__((overloadable))
void biquad_filter_active(biquad_filterbank_t * __nonnull const object,
                          double const * __nonnull B0, simd_long2 const ldB0/*[channel][section][time]*/,
                          double const * __nonnull B1, simd_long2 const ldB1/*[channel][section][time]*/,
                          double const * __nonnull B2, simd_long2 const ldB2/*[channel][section][time]*/,
                          double const * __nonnull A0, simd_long2 const ldA0/*[channel][section][time]*/,
                          double const * __nonnull A1, simd_long2 const ldA1/*[channel][section][time]*/,
                          double const * __nonnull A2, simd_long2 const ldA2/*[channel][section][time]*/,
                          double const * __nonnull X, intptr_t const ldX,
                          double       * __nonnull Y, intptr_t const ldY,
                          intptr_t const length) {
    for ( register intptr_t c = object->count ; 0 < c -- ; )
        biquad_filter_convolve_active(B0 + c * ldB0.x, ldB0.y,
                                      B1 + c * ldB1.x, ldB1.y,
                                      B2 + c * ldB2.x, ldB2.y,
                                      A0 + c * ldA0.x, ldA0.y,
                                      A1 + c * ldA1.x, ldA1.y,
                                      A2 + c * ldA2.x, ldA2.y,
                                      X + c * ldX,
                                      Y + c * ldY,
                                      object->state + c * object->order, object->order,
                                      length);
}
__attribute__((overloadable)) // shared filter parameter for all channels
void biquad_filter_active(biquad_filterbank_t * __nonnull const object,
                          double const * __nonnull const B0, intptr_t const ldB0/*[section][time]*/,
                          double const * __nonnull const B1, intptr_t const ldB1/*[section][time]*/,
                          double const * __nonnull const B2, intptr_t const ldB2/*[section][time]*/,
                          double const * __nonnull const A0, intptr_t const ldA0/*[section][time]*/,
                          double const * __nonnull const A1, intptr_t const ldA1/*[section][time]*/,
                          double const * __nonnull const A2, intptr_t const ldA2/*[section][time]*/,
                          double const * __nonnull const X, intptr_t const ldX,
                          double       * __nonnull const Y, intptr_t const ldY,
                          intptr_t const length) {
    for ( register intptr_t c = object->count ; 0 < c -- ; )
        biquad_filter_convolve_active(B0, ldB0,
                                      B1, ldB1,
                                      B2, ldB2,
                                      A0, ldA0,
                                      A1, ldA1,
                                      A2, ldA2,
                                      X + c * ldX,
                                      Y + c * ldY,
                                      object->state + c * object->order, object->order,
                                      length);
}
