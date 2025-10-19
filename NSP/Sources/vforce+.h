//
//  vforce+.h
//  MUTE
//
//  Created by Kota on 11/30/R6.
//
#include<stdint.h>
__attribute__((always_inline)) void vvexp10(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vverf(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vverfc(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvlgamma(double * __nonnull const y, register double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvtgamma(double * __nonnull const y, register double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvj0(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvj1(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvjn(double * __nonnull const y, double const * __nonnull const x, intptr_t * __nonnull const n, intptr_t const length);
__attribute__((always_inline)) void vsjn(double * __nonnull const y, double const * __nonnull const x, intptr_t const n, intptr_t const length);
__attribute__((always_inline)) void vvy0(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvy1(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvyn(double * __nonnull const y, double const * __nonnull const x, intptr_t * __nonnull const n, intptr_t const length);
__attribute__((always_inline)) void vsyn(double * __nonnull const y, double const * __nonnull const x, intptr_t const n, intptr_t const length);
// Modified Bessel function
__attribute__((always_inline)) double const i0(double const x);
__attribute__((always_inline)) double const i1(double const x);
__attribute__((always_inline)) double const in(intptr_t const n, double const x);
__attribute__((always_inline)) void vvi0(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
__attribute__((always_inline)) void vvi1(double * __nonnull const y, double const * __nonnull const x, intptr_t const length);
