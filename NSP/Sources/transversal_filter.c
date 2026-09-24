//
//  transversal_filter.c
//  MUTE
//
//  Created by Kota on 9/23/26.
//
#include"module.h"
#include"transversal_filter.h"
__attribute__((visibility("hidden"))) static
intptr_t const _[] = {0, 1, 2};
// MARK: Common
__attribute__((overloadable, always_inline)) // TDF-II
void transversal_filter_static(double const * __nonnull const b, intptr_t const m,
                               double const * __nonnull const a, intptr_t const n,
                               double const * __nonnull const x,
                               double       * __nonnull const y,
                               double       * __nonnull const z, // require MAX(m, n)
                               intptr_t const length) {
    assert(0 < m);
    assert(0 < n);
    intptr_t const m1 = m - 1;
    intptr_t const n1 = n - 1;
    intptr_t const l1 = MAX(m1, n1);
    for ( register intptr_t k = 0 ; k < length ; ++ k ) {
        double const i = x[k];
        double const o = fma(i, *b, *z) / -*a;
        memmove(z, z + 1, l1 * sizeof(double const));
        z[l1] = 0;
        daxpy_(&m1, &i, b + 1, &1[_], z, &1[_]);
        daxpy_(&n1, &o, a + 1, &1[_], z, &1[_]);
        y[k] = -o;
    }
}
__attribute__((overloadable, always_inline)) static inline // DF-I (mirrored ring buffer)
void transversal_filter_static(double const * __nonnull const b, intptr_t const m,
                               double const * __nonnull const a, intptr_t const n,
                               double       * __nonnull const x, intptr_t xc,
                               double       * __nonnull const y, intptr_t yc,
                               double const * __nonnull i,
                               double       * __nonnull o,
                               register intptr_t const length) {
    intptr_t const k = n - 1;
    for ( register intptr_t t = 0 ; t < length ; ++ t ) {
        x[xc+m] = x[xc] = *i++;
        y[yc+n] = y[yc] = *o++ = (ddot_(&m, x+xc-0, &1[_],
                                        b+0, &1[_]) -
                                  ddot_(&k, y+yc+1, &1[_],
                                        a+1, &1[_])) / *a;
        if ( -- xc < 0 )
            xc += m;
        if ( -- yc < 0 )
            yc += n;
    }
}
// MARK: Filter (Single)
__attribute__((overloadable))
transversal_filter_t * __nonnull const transversal_filter_create(intptr_t const b, intptr_t const a) {
    transversal_filter_t * __nonnull const object = __malloc__(sizeof(transversal_filter_t const) + 2 * (b + a) * sizeof(double));
    *__builtin_bit_cast(intptr_t*const, &object->b) = b;
    *__builtin_bit_cast(intptr_t*const, &object->a) = a;
    transversal_filter_reset(object);
    return object;
}
__attribute__((overloadable))
void transversal_filter_destroy(transversal_filter_t * __nonnull const object) {
    __free__(object);
}
__attribute__((overloadable))
void transversal_filter_reset(transversal_filter_t * __nonnull const object) {
    object->x = 0;
    object->y = 0;
    memset(object->z, 0, 2 * (object->b + object->a) * sizeof(double const));
}
__attribute__((overloadable))
void transversal_filter_static(transversal_filter_t * __nonnull const object,
                               double const * __nonnull const b,
                               double const * __nonnull const a,
                               double const * __nonnull const x,
                               double       * __nonnull const y,
                               intptr_t const length) {
    intptr_t const m = object->b;
    intptr_t const n = object->a, k = n - 1;
    register intptr_t xc = object->x; assert(0 <= xc);
    register intptr_t yc = object->y; assert(0 <= yc);
    register double * __nonnull const X = object->z + 0 * m;
    register double * __nonnull const Y = object->z + 2 * m;
    for ( register intptr_t t = 0 ; t < length ; ++ t ) {
        X[xc+m] = X[xc] = x[t];
        Y[yc+n] = Y[yc] = y[t] = (ddot_(&m,
                                        X+xc-0, &1[_],
                                        b+0, &1[_]) -
                                  ddot_(&k,
                                        Y+yc+1, &1[_],
                                        a+1, &1[_])) / *a;
        if ( -- xc < 0 )
            xc += m;
        if ( -- yc < 0 )
            yc += n;
    }
    object->x = xc;
    object->y = yc;
}
__attribute__((overloadable))
void transversal_filter_active(transversal_filter_t * __nonnull const object,
                               double const * __nonnull b, intptr_t const ldb,
                               double const * __nonnull a, intptr_t const lda,
                               double const * __nonnull x,
                               double       * __nonnull y,
                               intptr_t const length) {
    intptr_t const m = object->b;
    intptr_t const n = object->a, k = n - 1;
    register intptr_t xc = object->x; assert(0 <= xc);
    register intptr_t yc = object->y; assert(0 <= yc);
    register double * __nonnull const X = object->z + 0 * m;
    register double * __nonnull const Y = object->z + 2 * m;
    for ( register intptr_t t = 0 ; t < length ; ++ t, ++ b, ++ a ) {
        X[xc+m] = X[xc] = *x++;
        Y[yc+n] = Y[yc] = *y++ = (ddot_(&m,
                                        X+xc-0, &1[_],
                                        b+0*ldb, &ldb) -
                                  ddot_(&k,
                                        Y+yc+1, &1[_],
                                        a+1*lda, &lda)) / *a;
        if ( -- xc < 0 )
            xc += m;
        if ( -- yc < 0 )
            yc += n;
    }
    object->x = xc;
    object->y = yc;
}
// MARK: Filter (Multi-channel, shared coefficients)
__attribute__((overloadable))
transversal_filterbank_t * __nonnull const transversal_filter_create(intptr_t const b, intptr_t const a, intptr_t const c) {
    transversal_filterbank_t * __nonnull const object = __malloc__(sizeof(transversal_filterbank_t const) + 2 * c * ( b + a ) * sizeof(double const));
    *__builtin_bit_cast(intptr_t*const, &object->b) = b;
    *__builtin_bit_cast(intptr_t*const, &object->a) = a;
    *__builtin_bit_cast(intptr_t*const, &object->c) = c;
    transversal_filter_reset(object);
    return object;
}
__attribute__((overloadable))
void transversal_filter_destroy(transversal_filterbank_t * __nonnull const object) {
    __free__(object);
}
__attribute__((overloadable))
void transversal_filter_reset(transversal_filterbank_t * __nonnull const object) {
    object->x = 0;
    object->y = 0;
    memset(object->z, 0, 2 * object->c * ( object->b + object->a ) * sizeof(double const));
}
__attribute__((overloadable))
void transversal_filter_static(transversal_filterbank_t * __nonnull const object,
                               double const * __nonnull const b, intptr_t const ldb, // [channel][coefficients]
                               double const * __nonnull const a, intptr_t const lda, // [channel][coefficients]
                               double const * __nonnull const x, intptr_t const ldx,
                               double       * __nonnull const y, intptr_t const ldy,
                               intptr_t const length) {
    register intptr_t const m = object->b, ldX = 2 * m, xc = object->x;
    register intptr_t const n = object->a, ldY = 2 * n, yc = object->y;
    register double * __nonnull const X = object->z + 0 * m * object->c;
    register double * __nonnull const Y = object->z + 2 * m * object->c;
    for ( register intptr_t k = 0, K = object->c ; k < K ; ++ k )
        transversal_filter_static(b + k * ldb, m,
                                  a + k * lda, n,
                                  X + ldX, xc,
                                  Y + ldY, yc,
                                  x + k * ldx,
                                  y + k * ldy,
                                  length);
    object->x = ( ( object->x - length ) % m + m ) % m;
    object->y = ( ( object->y - length ) % n + n ) % n;
}
__attribute__((overloadable)) // shared kernel (B, A) for all channels
void transversal_filter_static(transversal_filterbank_t * __nonnull const object,
                               double const * __nonnull const b,
                               double const * __nonnull const a,
                               double const * __nonnull const x, intptr_t const ldx,
                               double       * __nonnull const y, intptr_t const ldy,
                               intptr_t const length) {
    static double const w[] = {0, 1, -1};
    intptr_t const m = object->b, ldX = 2 * m, c = object->c;
    intptr_t const n = object->a, ldY = 2 * n, k = n - 1;
    register intptr_t xc = object->x; assert(0 <= xc);
    register intptr_t yc = object->y; assert(0 <= yc);
    register double * __nonnull const X = object->z + 0 * m * c;
    register double * __nonnull const Y = object->z + 2 * m * c;
    for ( register intptr_t t = 0 ; t < length ; ++ t ) {
        dcopy_(&c, x + t, &ldx, X + xc, &ldX);
        dcopy_(&c, x + t, &ldx, X + xc + m, &ldX);
        dgemv_("T", &m, &c,
               (double const[]){ simd_recip(*a)},
               X + xc + 0, &ldX,
               b + 0, &1[_],
               w + 0,
               y + t, &ldy);
        dgemv_("T", &k, &c,
               (double const[]){-simd_recip(*a)},
               Y + yc + 1, &ldY,
               a + 1, &1[_],
               w + 1,
               y + t, &ldy);
        dcopy_(&c, y + t, &ldy, Y + yc, &ldY);
        dcopy_(&c, y + t, &ldy, Y + yc + n, &ldY);
        if ( -- xc < 0 )
            xc += m;
        if ( -- yc < 0 )
            yc += n;
    }
    object->x = xc;
    object->y = yc;
}
__attribute__((overloadable)) // shared kernel (B, A) for all channels
void transversal_filter_active(transversal_filterbank_t * __nonnull const object,
                               double const * __nonnull b, intptr_t const ldb,
                               double const * __nonnull a, intptr_t const lda,
                               double const * __nonnull x, intptr_t const ldx,
                               double       * __nonnull y, intptr_t const ldy,
                               intptr_t const length) {
    static double const w[] = {0, 1, -1};
    intptr_t const m = object->b, ldX = 2 * m, c = object->c;
    intptr_t const n = object->a, ldY = 2 * n, k = n - 1;
    register intptr_t xc = object->x; assert(0 <= xc);
    register intptr_t yc = object->y; assert(0 <= yc);
    register double * __nonnull const X = object->z + 0 * m * c;
    register double * __nonnull const Y = object->z + 2 * m * c;
    for ( register intptr_t t = 0 ; t < length ; ++ t, ++ x, ++ y, ++ b, ++ a ) {
        dcopy_(&c, x, &ldx, X + xc, &ldX);
        dcopy_(&c, x, &ldx, X + xc + m, &ldX);
        dgemv_("T", &m, &c,
               w + 1,
               X + xc + 0, &ldX,
               b + 0 * ldb, &ldb,
               w + 0,
               y, &ldy);
        dgemv_("T", &k, &c,
               w + 2,
               Y + yc + 1, &ldY,
               a + 1 * lda, &lda,
               w + 1,
               y, &ldy);
        __vsdiv__(y, ldy, *a, y, ldy, c);
        dcopy_(&c, y, &ldy, Y + yc, &ldY);
        dcopy_(&c, y, &ldy, Y + yc + n, &ldY);
        if ( -- xc < 0 )
            xc += m;
        if ( -- yc < 0 )
            yc += n;
    }
    object->x = xc;
    object->y = yc;
}
