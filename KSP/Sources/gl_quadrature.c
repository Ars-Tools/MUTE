//
//  gl_quadrature.c
//  MUTE
//
//  Created by Kota on 6/16/26.
//
#include"module.h"
#include"gl_quadrature.h"
__attribute__((visibility("hidden")))
intptr_t static const _[] = {0, 1, 2};
__attribute__((always_inline)) static inline
simd_double2 const legendre(intptr_t const n, double const x) {
    simd_double2 z = {x, 1};
    for ( register intptr_t k = 1 ; k < n ; ++ k )
        z = (simd_double2 const) {
            fma(-k, z.y, z.x * fma(k, 2, 1) * x) / ( k + 1 ),
            z.x
        };
    return (simd_double2 const) {
        z.x,
        n * fma(-x, z.x, z.y) / fma(-x, x, 1)
    };
}
__attribute__((always_inline)) static inline
double const ulp(double const x) {
    return nextafter(x, INFINITY) - x;
}
__attribute__((always_inline)) static inline
double const dydx(simd_double2 const r) {
    return r.x / r.y;
}
__attribute__((always_inline))
gl_quadrature_t const * __nullable const gl_quadrature_create(intptr_t const count) {
    gl_quadrature_t * __nonnull const object = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(intptr_t const) + 2 * count * sizeof(double const), 0);
    *(intptr_t * __nonnull const)&object->length = count;
    double * __nonnull const anchor = (double*__nonnull const)object->factor + 0 * object->length;
    double * __nonnull const weight = (double*__nonnull const)object->factor + 1 * object->length;
    switch (count) {
        case 1:
            anchor[0] = 0.0;
            weight[0] = 2.0;
            break;
        case 2:
            anchor[0] = -(anchor[1] = simd_precise_rsqrt(3.0));
            weight[0] =  (weight[1] = 1.0);
            break;
        case 3:
            anchor[1] = 0;
            weight[1] = 8/9.0;
            anchor[0] = -(anchor[2] = sqrt(0.6));
            weight[0] =  (weight[2] = 5/9.0);
            break;
        default:
            if ( count % 2 ) {
                register double const x = 0;
                register double const z = legendre(count, x).y;
                anchor[count / 2] = x;
                weight[count / 2] = 2 / z / z;
            }
            for ( register intptr_t k = 0, K = count / 2 ; k < K ; ++ k ) {
                register double x = cospi(fma(k, 4.0, 3.0) / fma(count, 4.0, 2.0));
                for ( register double y ; ulp(x) < fabs(y = dydx(legendre(count, x))) ; x -= y );
                register double const z = legendre(count, x).y;
                register double const w = -2 / fma(x, x, -1) / z / z;
                anchor[k] = -(anchor[count-k-1] = x);
                weight[k] =  (weight[count-k-1] = w);
            }
            break;
    }
    return object;
}
__attribute__((always_inline, __overloadable__))
double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const object,
                                     double const lower, double const upper,
                                     void(^__attribute__((noescape))__nonnull integrand)(double const*__nonnull const, double*__nonnull const, intptr_t const)) {
    double * __nonnull const memory = alloca(2 * object->length * sizeof(double const));
    __complex double result = NAN;
    double const alpha = 0.5 * ( upper - lower );
    __vsmsa__(object->factor, 1,
              alpha, alpha + lower,
              memory + object->length, 1,
              object->length);
    integrand(memory + object->length, memory, object->length);
    return alpha * ddot_(&object->length, memory, &1[_], object->factor + object->length, &1[_]);
}
__attribute__((always_inline, __overloadable__))
double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const object,
                                     double const lower, double const upper,
                                     double const(^__attribute__((noescape))__nonnull integrand)(double)) {
    return gl_quadrature_integrate(object, lower, upper, ^(double const*__nonnull x, double*__nonnull y, intptr_t const length) {
        for ( double const*__nonnull _ = x + length ; x < _ ; ++ x, ++ y )
            *y = integrand(*x);
    });
}
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const object,
                                               double const lower, double const upper,
                                               void(^__attribute__((noescape))__nonnull integrand)(double const*__nonnull const, __complex double*__nonnull const, intptr_t const)) {
    double * __nonnull const memory = alloca(3 * object->length * sizeof(double const));
    __complex double result = NAN;
    double const alpha = 0.5 * ( upper - lower );
    __vsmsa__(object->factor, 1,
              alpha, alpha + lower,
              memory + 2 * object->length, 1,
              object->length);
    integrand(memory + 2 * object->length, (__complex double*__nonnull const)memory, object->length);
    dgemv_("N",
           &2[_], &object->length,
           &alpha,
           memory, &2[_],
           object->factor + object->length, &1[_],
           (double const[]){0.0},
           (double*__nonnull const)&result, &1[_]);
    return result;
}
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const object,
                                               double const lower, double const upper,
                                               __complex double const(^__attribute__((noescape))__nonnull integrand)(double)) {
    return gl_quadrature_integrate(object, lower, upper, ^(double const*__nonnull x, __complex double*__nonnull y, intptr_t const length) {
        for ( double const*__nonnull _ = x + length ; x < _ ; ++ x, ++ y )
            *y = integrand(*x);
    });
}
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const object,
                                               simd_double2 const lower, simd_double2 const upper,
                                               void(^__attribute__((noescape))__nonnull const integrand)(simd_double2 const*__nonnull const, __complex double*__nonnull const, intptr_t const)) {
    __block __complex double result = 0;
    simd_double2 const j = 0.5 * ( upper - lower );
    __with_memory__(6 * object->length * sizeof(double const), ^(void*__nonnull const memory) {
        double * __nonnull const a = memory;
        double * __nonnull const u = memory + 2 * object->length * sizeof(double const);
        double * __nonnull const v = memory + 3 * object->length * sizeof(double const);
        double * __nonnull const p = memory + 4 * object->length * sizeof(double const);
        __vsmsa__(object->factor, 1, j.x, j.x + lower.x, u, 1, object->length);
        __vsmsa__(object->factor, 1, j.y, j.y + lower.y, v, 1, object->length);
        for ( register intptr_t k = 0, K = object->length ; k < K ; ++ k ) {
            __fill__(u[k], p, 2, object->length);
            __copy__(v, 1, p + 1, 2, object->length);
            integrand((simd_double2*__nonnull const)p, (__complex double*__nonnull const)a, object->length);
            dgemv_("N",
                   &2[_], &object->length,
                   object->factor + object->length + k,
                   a, &2[_],
                   object->factor + object->length, &1[_],
                   (double const[]) {1.0},
                   (double*__nonnull const)&result, &1[_]);
        }
    });
    return j.x * j.y * result;
}
__attribute__((always_inline, __overloadable__))
__complex double const gl_quadrature_integrate(gl_quadrature_t const*__nonnull const object,
                                               simd_double2 const lower, simd_double2 const upper,
                                               __complex double const(^__attribute__((noescape))__nonnull const integrand)(simd_double2 const)) {
    return gl_quadrature_integrate(object, lower, upper, ^(simd_double2 const*__nonnull const source, __complex double*__nonnull const target, const intptr_t length) {
        for ( register intptr_t k = 0, K = length ; k < K ; ++ k )
            target[k] = integrand(source[k]);
    });
}
__attribute__((always_inline))
void gl_quadrature_destroy(gl_quadrature_t const * __nonnull const object) {
    CFAllocatorDeallocate(kCFAllocatorDefault, (void*__nonnull const)object);
}
