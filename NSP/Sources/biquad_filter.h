//
//  biquad_filter.h
//  MUTE
//
//  Created by Kota on 8/11/R7.
//
#include<stdint.h>
#include<simd/simd.h>
// MARK: Utilities
__attribute__((always_inline))
inline static
simd_double3 const biquad_power_coefficients(simd_double3 const w) {
    register double const
    s = w.x + w.z,
    t = w.x * w.z;
    return (simd_double3 const) {
        fma(-2, t, simd_length_squared(w)),
        2 * s * w.y,
        4 * t
    };
}
__attribute__((always_inline))
inline static
simd_double3 const biquad_delay_coefficients(simd_double3 const w) {
    register double const
    s = 3 * w.z + w.x,
    t = 2 * w.x * w.z;
    return (simd_double3 const) {
        fma(w.y, w.y, t),
        s * w.y,
        t
    };
}
__attribute__((overloadable, always_inline)) static inline
void biquad_filter_convolve_static(register simd_double3 const b,
                                   register simd_double3 const a,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double2 * __nonnull const h,
                                   intptr_t const length) {
    register simd_double2x2 const S = {
        (simd_double2 const) { b.y,  b.z},
        (simd_double2 const) {-a.y, -a.z}
    };
    register simd_double2 s = *h;
    for ( register intptr_t k = 0 ; k < length ; ++ k ) {
        register double const _ = *x++;
        s = simd_mul(S, (simd_double2 const) {
                       _,
            *y++ = fma(_, b.x, s.x) / a.x,
        }) + (simd_double2 const) {s.y, 0};
    }
    *h = s;
}
__attribute__((overloadable, always_inline)) static inline
void biquad_filter_convolve_static(register simd_double3 const b,
                                   register simd_double3 const a,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h,
                                   intptr_t const length) {
    register simd_double4 const c = {b.y, b.z, -a.y, -a.z};
    register simd_double4 z = *h;
    for ( register intptr_t k = 0, K = length ; k < K ; ++ k ) {
        register double const _ = *x++;
        z = (simd_double4 const) {
            _,
            z.x,
            *y++ = fma(_, b.x, simd_dot(z, c)) / a.x,
            z.z
        };
    }
    *h = z;
}
__attribute__((overloadable, always_inline)) static inline /*SOS*/
void biquad_filter_convolve_static(register simd_double3 const * __nonnull const b,
                                   register simd_double3 const * __nonnull const a,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h, intptr_t const c,
                                   intptr_t const length) {
    assert(0 < c);
    for ( register intptr_t k = 0, K = c ; k < K ; ++ k )
        biquad_filter_convolve_static(b[k],
                                      a[k],
                                      k ? y : x,
                                      y,
                                      h + k,
                                      length);
}
__attribute__((overloadable, always_inline)) static inline /*Cascaded Zero-Pole, Paired Real Root*/
void biquad_filter_convolve_static(register simd_double2 const * __nonnull const z,
                                   register simd_double2 const * __nonnull const p,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double2 * __nonnull const h, intptr_t const c,
                                   intptr_t const length) {
    for ( register intptr_t n = 0, N = c ; n < N ; ++ n ) {
        register simd_double2 const zero = z[n];
        register simd_double2 const pole = p[n];
        register simd_double2x2 const S = {
            (simd_double2 const) {-simd_reduce_add(zero),  zero.x * zero.y},
            (simd_double2 const) { simd_reduce_add(pole), -pole.x * pole.y},
        };
        register double const * __nonnull const q = n ? y : x;
        register simd_double2 s = h[n];
        for ( register intptr_t k = 0 ; k < length ; ++ k ) {
            register double const _ = q[k];
            s = simd_mul(S, (simd_double2 const) {
                       _,
                y[k] = _ + s.x
            }) + (simd_double2 const) {s.y, 0};
        }
        h[n] = s;
    }
}
__attribute__((overloadable, always_inline)) static inline /*Cascaded Zero-Pole, Paired Complex Root*/
void biquad_filter_convolve_static(register __complex double const * __nonnull const z,
                                   register __complex double const * __nonnull const p,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double2 * __nonnull const h, intptr_t const c,
                                   intptr_t const length) {
    for ( register intptr_t n = 0, N = c ; n < N ; ++ n ) {
        register __complex double const zero = z[n];
        register __complex double const pole = p[n];
        register simd_double2x2 const S = {
            (simd_double2 const) {-2*__real(zero),  simd_length_squared(__builtin_bit_cast(simd_double2 const, zero))},
            (simd_double2 const) { 2*__real(pole), -simd_length_squared(__builtin_bit_cast(simd_double2 const, pole))},
        };
        register double const * __nonnull const q = n ? y : x;
        register simd_double2 s = h[n];
        for ( register intptr_t k = 0 ; k < length ; ++ k ) {
            register double const _ = q[k];
            s = simd_mul(S, (simd_double2 const) {
                       _,
                y[k] = _ + s.x
            }) + (simd_double2 const) {s.y, 0};
        }
        h[n] = s;
    }
}
__attribute__((overloadable, always_inline)) static inline
void biquad_filter_convolve_active(register double const * __nonnull b, register intptr_t const ldb,
                                   register double const * __nonnull a, register intptr_t const lda,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h,
                                   intptr_t const length) {
    register simd_double3 z = (simd_double3 const) {h->x, h->y, 0};
    register simd_double2 w = (simd_double2 const) {h->z, h->w};
    for ( register intptr_t k = 0, K = length ; k < K ; ++ k, ++ x, ++ y, ++ b, ++ a )
        w = (simd_double2 const) {
            *y = (simd_dot(z = (simd_double3 const) {*x, z.x, z.y}, (simd_double3 const) {*b, b[ldb], b[2*ldb]}) - simd_dot(w, (simd_double2 const) {a[lda], a[2*lda]})) / *a,
            w.x
        };
    *h = (simd_double4 const) {z.x, z.y, w.x, w.y};
}
__attribute__((overloadable, always_inline)) static inline /*SOS*/
void biquad_filter_convolve_active(register double const * __nonnull b, register intptr_t const ldb, // [section][parameter(3)][time<=ld]
                                   register double const * __nonnull a, register intptr_t const lda, // [section][parameter(3)][time<=ld]
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h, intptr_t const c,
                                   intptr_t const length) {
    for ( register intptr_t k = 0, K = length ; k < K ; ++ k, ++ x, ++ y, ++ b, ++ a ) {
        register double v = *x;
        for ( register intptr_t n = 0, N = c ; n < N ; ++ n )
            v = (h[n] = (simd_double4 const) {
                v,
                h[n].x,
                (simd_dot((simd_double3 const) {v, h[n].x, h[n].y}, (simd_double3 const) {b[(n*3+0)*ldb], b[(n*3+1)*ldb], b[(n*3+2)*ldb]}) -
                 simd_dot((simd_double2 const) {   h[n].z, h[n].w}, (simd_double2 const) {                a[(n*3+1)*lda], a[(n*3+2)*lda]})) / a[(3*n+0)*lda],
                h[n].z
            }).z;
        *y = v;
    }
}
__attribute__((overloadable, always_inline)) static inline
void biquad_filter_convolve_active(register double const * __nonnull b0,
                                   register double const * __nonnull b1,
                                   register double const * __nonnull b2,
                                   register double const * __nonnull a0,
                                   register double const * __nonnull a1,
                                   register double const * __nonnull a2,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h,
                                   intptr_t const length) {
    register simd_double4 z = *h;
    for ( register intptr_t k = 0, K = length ; k < K ; ++ k ) {
        register double const _ = *x++;
        z = (simd_double4 const) {
            _,
            z.x,
            *y++ = fma(_, *b0++, simd_dot(z, (simd_double4 const) {
                 *b1++,
                 *b2++,
                -*a1++,
                -*a2++
            })) / *a0++,
            z.z
        };
    }
    *h = z;
}
__attribute__((overloadable, always_inline)) static inline /*SOS*/
void biquad_filter_convolve_active(register double const * __nonnull b0, intptr_t const ldb0,
                                   register double const * __nonnull b1, intptr_t const ldb1,
                                   register double const * __nonnull b2, intptr_t const ldb2,
                                   register double const * __nonnull a0, intptr_t const lda0,
                                   register double const * __nonnull a1, intptr_t const lda1,
                                   register double const * __nonnull a2, intptr_t const lda2,
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h, intptr_t const c,
                                   intptr_t const length) {
    assert(0 < c);
    for ( register intptr_t k = 0, K = c ; k < K ; ++ k )
        biquad_filter_convolve_active(b0 + k * ldb0,
                                      b1 + k * ldb1,
                                      b2 + k * ldb2,
                                      a0 + k * lda0,
                                      a1 + k * lda1,
                                      a2 + k * lda2,
                                      k ? y : x,
                                      y,
                                      h + k,
                                      length);
}
__attribute__((overloadable, always_inline)) static inline /*Cascaded Zero-Pole, Paired Real Root*/
void biquad_filter_convolve_active(register simd_double2 const * __nonnull const z, register intptr_t const ldz, // [section][time<=ld], row-major
                                   register simd_double2 const * __nonnull const p, register intptr_t const ldp, // [section][time<=ld], row-major
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h, intptr_t const c,
                                   intptr_t const length) {
    for ( register intptr_t n = 0, N = c ; n < N ; ++ n ) {
        register simd_double2 const * __nonnull zn = z + n * ldz;
        register simd_double2 const * __nonnull pn = p + n * ldp;
        simd_double4 s = h[n];
        register double const * __nonnull const t = n ? y : x;
        for ( register intptr_t k = 0, K = length ; k < K ; ++ k ) {
            register simd_double2 const zero = zn[k];
            register simd_double2 const pole = pn[k];
            register double const _ = t[k];
            s = (simd_double4 const) {
                _,
                s.x,
                y[k] = simd_dot(s, (simd_double4 const) {
                    -simd_reduce_add(zero),  zero.x * zero.y,
                     simd_reduce_add(pole), -pole.x * pole.y,
                }) + _,
                s.z
            };
        }
        h[n] = s;
    }
}
__attribute__((overloadable, always_inline)) static inline /*Cascaded Zero-Pole, Paired Complex Root*/
void biquad_filter_convolve_active(register __complex double const * __nonnull const z, register intptr_t const ldz, // [section][time<=ld], row-major
                                   register __complex double const * __nonnull const p, register intptr_t const ldp, // [section][time<=ld], row-major
                                   register double const * __nonnull x,
                                   register double       * __nonnull y,
                                   simd_double4 * __nonnull const h, intptr_t const c,
                                   intptr_t const length) {
    for ( register intptr_t n = 0, N = c ; n < N ; ++ n ) {
        register __complex double const * __nonnull zn = z + n * ldz;
        register __complex double const * __nonnull pn = p + n * ldp;
        simd_double4 s = h[n];
        register double const * __nonnull const t = n ? y : x;
        for ( register intptr_t k = 0, K = length ; k < K ; ++ k ) {
            register __complex double const zero = zn[k];
            register __complex double const pole = pn[k];
            register double const _ = t[k];
            s = (simd_double4 const) {
                _,
                s.x,
                y[k] = simd_dot(s, (simd_double4 const) {
                    -2*__real(zero),
                     simd_length_squared(__builtin_bit_cast(simd_double2 const, zero)),
                     2*__real(pole),
                    -simd_length_squared(__builtin_bit_cast(simd_double2 const, pole))
                }) + _,
                s.z
            };
        }
        h[n] = s;
    }
}
// MARK: Filter
typedef struct {
    intptr_t const z;
    simd_double4 s[];
} biquad_filter_t;
__attribute__((overloadable)) biquad_filter_t * __nonnull const biquad_filter_create(intptr_t const c);
__attribute__((overloadable)) void biquad_filter_destroy(biquad_filter_t * __nonnull const object);
__attribute__((overloadable)) void biquad_filter_reset(biquad_filter_t * __nonnull const object);
__attribute__((overloadable)) void biquad_filter_active(biquad_filter_t * __nonnull const object,
                                                        double const * __nonnull B, intptr_t const ldB,
                                                        double const * __nonnull A, intptr_t const ldA,
                                                        double const * __nonnull X, intptr_t const ldX,
                                                        double       * __nonnull Y, intptr_t const ldY,
                                                        intptr_t const length);
__attribute__((overloadable)) void biquad_filter_active(biquad_filter_t * __nonnull const,
                                                        double const * __nonnull B0, intptr_t const ldB0,
                                                        double const * __nonnull B1, intptr_t const ldB1,
                                                        double const * __nonnull B2, intptr_t const ldB2,
                                                        double const * __nonnull A0, intptr_t const ldA0,
                                                        double const * __nonnull A1, intptr_t const ldA1,
                                                        double const * __nonnull A2, intptr_t const ldA2,
                                                        double const * __nonnull X, intptr_t const ldX,
                                                        double       * __nonnull Y, intptr_t const ldY,
                                                        intptr_t const length);
// MARK: Filter Bank
typedef struct {
    intptr_t const order;
    intptr_t const count;
    simd_double4 state[];
} biquad_filterbank_t;
__attribute__((overloadable)) biquad_filterbank_t * __nonnull const biquad_filter_create(intptr_t const order, intptr_t const count);
__attribute__((overloadable)) void biquad_filter_destroy(biquad_filterbank_t * __nonnull const);
__attribute__((overloadable)) void biquad_filter_reset(biquad_filterbank_t * __nonnull const);
__attribute__((overloadable)) void biquad_filter_active(biquad_filterbank_t * __nonnull const,
                                                        double const * __nonnull B, intptr_t const ldB,  // [section][parameter(3)][time<=ld]
                                                        double const * __nonnull A, intptr_t const ldA,  // [section][parameter(3)][time<=ld]
                                                        double const * __nonnull X, intptr_t const ldX,
                                                        double       * __nonnull Y, intptr_t const ldY,
                                                        intptr_t const length);
__attribute__((overloadable)) void biquad_filter_active(biquad_filterbank_t * __nonnull const,
                                                        double const * __nonnull B0, simd_long2 const ldB0/*[channel][section][time]*/,
                                                        double const * __nonnull B1, simd_long2 const ldB1/*[channel][section][time]*/,
                                                        double const * __nonnull B2, simd_long2 const ldB2/*[channel][section][time]*/,
                                                        double const * __nonnull A0, simd_long2 const ldA0/*[channel][section][time]*/,
                                                        double const * __nonnull A1, simd_long2 const ldA1/*[channel][section][time]*/,
                                                        double const * __nonnull A2, simd_long2 const ldA2/*[channel][section][time]*/,
                                                        double const * __nonnull X, intptr_t const ldX,
                                                        double       * __nonnull Y, intptr_t const ldY,
                                                        intptr_t const length);
__attribute__((overloadable)) void biquad_filter_active(biquad_filterbank_t * __nonnull const object,
                                                        double const * __nonnull B0, simd_long2 const ldB0/*[channel][section][time]*/,
                                                        double const * __nonnull B1, simd_long2 const ldB1/*[channel][section][time]*/,
                                                        double const * __nonnull B2, simd_long2 const ldB2/*[channel][section][time]*/,
                                                        double const * __nonnull A0, simd_long2 const ldA0/*[channel][section][time]*/,
                                                        double const * __nonnull A1, simd_long2 const ldA1/*[channel][section][time]*/,
                                                        double const * __nonnull A2, simd_long2 const ldA2/*[channel][section][time]*/,
                                                        double const * __nonnull X, intptr_t const ldX,
                                                        double       * __nonnull Y, intptr_t const ldY,
                                                        intptr_t const length);
