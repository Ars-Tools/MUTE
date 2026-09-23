//
//  transversal_filter.h
//  MUTE
//
//  Created by Kota on 9/23/26.
//
#include<stdint.h>
#include<simd/simd.h>
// MARK: Convolution
__attribute__((overloadable, always_inline))
void transversal_filter_static(double const * __nonnull const B, intptr_t const m,
                               double const * __nonnull const A, intptr_t const n,
                               double const * __nonnull const X,
                               double       * __nonnull const Y,
                               double       * __nonnull const Z, // require MAX(m, n)
                               intptr_t const length);
// MARK: Filter
typedef struct {
    intptr_t const b; // length of B
    intptr_t const a; // length of A
    intptr_t x; // cursor of x
    intptr_t y; // cursor of y
    double z[]; // history of X & Y
} transversal_filter_t;
__attribute__((overloadable)) transversal_filter_t * __nonnull const transversal_filter_create(intptr_t const, intptr_t const);
__attribute__((overloadable)) void transversal_filter_destroy(transversal_filter_t * __nonnull const);
__attribute__((overloadable)) void transversal_filter_reset(transversal_filter_t * __nonnull const);
__attribute__((overloadable)) void transversal_filter_static(transversal_filter_t * __nonnull const,
                                                             double const * __nonnull const,
                                                             double const * __nonnull const,
                                                             double const * __nonnull const,
                                                             double       * __nonnull const,
                                                             intptr_t const);
__attribute__((overloadable)) void transversal_filter_active(transversal_filter_t * __nonnull const,
                                                             double const * __nonnull const, intptr_t const,
                                                             double const * __nonnull const, intptr_t const,
                                                             double const * __nonnull const,
                                                             double       * __nonnull const,
                                                             intptr_t const);
// MARK: Filter (Multi-Channel)
typedef struct {
    intptr_t const b; // length of B
    intptr_t const a; // length of A
    intptr_t const c;
    intptr_t x; // cursor of x
    intptr_t y; // cursor of y
    intptr_t _[3]; // padding
    double z[]; // history of X & Y
} transversal_filterbank_t;
__attribute__((overloadable)) transversal_filterbank_t * __nonnull const transversal_filter_create(intptr_t const, intptr_t const, intptr_t const);
__attribute__((overloadable)) void transversal_filter_destroy(transversal_filterbank_t * __nonnull const);
__attribute__((overloadable)) void transversal_filter_reset(transversal_filterbank_t * __nonnull const);
__attribute__((overloadable)) void transversal_filter_static(transversal_filterbank_t * __nonnull const,
                                                             double const * __nonnull const,
                                                             double const * __nonnull const,
                                                             double const * __nonnull const, intptr_t const,
                                                             double       * __nonnull const, intptr_t const,
                                                             intptr_t const);
__attribute__((overloadable)) void transversal_filter_active(transversal_filterbank_t * __nonnull const,
                                                             double const * __nonnull const, intptr_t const,
                                                             double const * __nonnull const, intptr_t const,
                                                             double const * __nonnull const, intptr_t const,
                                                             double       * __nonnull const, intptr_t const,
                                                             intptr_t const);
