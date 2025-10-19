//
//  duffing.h
//  MUTE
//
//  Created by Kota on 8/17/R7.
//
#include<stdint.h>
#include<simd/simd.h>
typedef struct {
	simd_double4 * __nonnull const s;
	intptr_t const z;
} duffing_filter_t;
__attribute__((always_inline)) duffing_filter_t * __nonnull const duffing_filter_create(intptr_t const c);
__attribute__((always_inline)) void duffing_filter_destroy(duffing_filter_t * __nonnull const object);
__attribute__((always_inline)) void duffing_filter_reset(duffing_filter_t * __nonnull const object);
__attribute__((always_inline)) void duffing_filter_active(duffing_filter_t * __nonnull const object,
														  double const * __nonnull B, intptr_t const ldB,
														  double const * __nonnull A, intptr_t const ldA,
														  double const * __nonnull X, intptr_t const ldX,
														  double       * __nonnull Y, intptr_t const ldY,
														  intptr_t const length);
__attribute__((always_inline)) void duffing_filter_static(duffing_filter_t * __nonnull const object,
														  double const * __nonnull B, intptr_t const ldB,
														  double const * __nonnull A, intptr_t const ldA,
														  double const * __nonnull X, intptr_t const ldX,
														  double       * __nonnull Y, intptr_t const ldY,
														  intptr_t const length);
