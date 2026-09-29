//
//  gl_quadrature.h
//  MUTE
//
//  Created by Kota on 6/16/26.
//
#include<stdint.h>
#include<simd/simd.h>
typedef struct {
    intptr_t const length;
    float64_t const factor[1];
} gl_quadrature_t;
//__attribute__((always_inline)) static inline
//simd_double2 const legendre(intptr_t const n, double const x);
__attribute__((always_inline))
gl_quadrature_t const * __nullable const gl_quadrature_create(intptr_t const);
__attribute__((always_inline, __overloadable__))
double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const,
                                     double const lower, double const upper,
                                     double const(^__attribute__((noescape))__nonnull integrand)(double const));
__attribute__((always_inline, __overloadable__))
double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const,
                                     double const lower, double const upper,
                                     void(^__attribute__((noescape))__nonnull integrand)(double const*__nonnull const, double*__nonnull const, intptr_t const));
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const,
                                               double const lower, double const upper,
                                               __complex double const(^__attribute__((noescape))__nonnull integrand)(double const));
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const,
                                               double const lower, double const upper,
                                               void(^__attribute__((noescape))__nonnull integrand)(double const*__nonnull const, __complex double *__nonnull const, intptr_t const));
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const,
                                               simd_double2 const lower, simd_double2 const upper,
                                               __complex double const(^__attribute__((noescape))__nonnull integrand)(simd_double2 const));
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const,
                                               simd_double2 const lower, simd_double2 const upper,
                                               void(^__attribute__((noescape))__nonnull integrand)(simd_double2 const*__nonnull const, __complex double*__nonnull const, intptr_t const));
__attribute__((always_inline))
void gl_quadrature_destroy(gl_quadrature_t const*__nonnull const);
