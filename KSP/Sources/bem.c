//
//  bem.c
//  MUTE
//
//  Created by Kota on 6/11/26.
//
#include"module.h"
#include"bem.h"
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
simd_double2 const bem2_sample_position(bem2_sample_t const sample) {
    return sample.position;
}
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
simd_double2 const bem2_sample_normal(bem2_sample_t const sample) {
    return simd_normalize(simd_make_double2(sample.gradient.y, -sample.gradient.x));
}
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
double const bem2_sample_jacobian(bem2_sample_t const sample) {
    return simd_length(sample.gradient);
}
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
double const bem2_sample_length(gl_quadrature_t const*__nonnull const quadrature, intptr_t const element, bem2_sample_t(^__attribute__((noescape))__nonnull const sampler)(intptr_t const, double const)) {
    return gl_quadrature_integrate(quadrature, 0, 1, ^(double const*__nonnull const x, double*__nonnull const y, intptr_t const length) {
        for ( register intptr_t k = 0 ; k < length ; ++ k )
            y[k] = bem2_sample_jacobian(sampler(element, x[k]));
    });
}
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
__complex double kernel0(double const wavenumber,
                         simd_double2 const t, simd_double2 const s) {
    simd_double2 const d = t - s;
    double const r = simd_length(d);
    double const z = wavenumber * r;
    return 0.25 * (I * j0(z) - y0(z));
}
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
__complex double kernel1(double const wavenumber,
                         simd_double2 const t, simd_double2 const s, simd_double2 const n) {
    simd_double2 const d = t - s;
    double const r = simd_length(d);
    double const z = wavenumber * r;
    return 0.25 * (I * j1(z) - y1(z)) * wavenumber * simd_dot(d, n) / r;
}
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
__complex double layer1(double const wavenumber,
                        simd_double2 const receiver,
                        gl_quadrature_t const * __nonnull const quadrature,
                        intptr_t const element,
                        bem2_sample_t const(^__attribute__((noescape))__nonnull const sampler)(intptr_t const, double const)) {
    return gl_quadrature_integrate(quadrature, 0, 1, ^(double const*__nonnull const x, __complex double*__nonnull const y, intptr_t const length) {
        for ( register intptr_t k = 0 ; k < length ; ++ k ) {
            bem2_sample_t const source = sampler(element, x[k]);
            y[k] = bem2_sample_jacobian(source) * kernel0(wavenumber, receiver, bem2_sample_position(source));
        }
    });
}
__attribute__((always_inline, __overloadable__, visibility("hidden"))) inline static
__complex double layer2(double const wavenumber,
                        simd_double2 const receiver,
                        gl_quadrature_t const * __nonnull const quadrature,
                        intptr_t const element,
                        bem2_sample_t const(^__attribute__((noescape))__nonnull const sampler)(intptr_t const, double const)) {
    return gl_quadrature_integrate(quadrature, 0, 1, ^(double const*__nonnull const x, __complex double*__nonnull const y, intptr_t const length) {
        for ( register intptr_t k = 0 ; k < length ; ++ k ) {
            bem2_sample_t const source = sampler(element, x[k]);
            y[k] = bem2_sample_jacobian(source) * kernel1(wavenumber, receiver, bem2_sample_position(source), bem2_sample_normal(source));
        }
    });
}
// solve Ax = b, x: intensity
// evaluate F = Cx + Db
__attribute__((always_inline, __overloadable__))
bool const bem2(double const wavenumber,
                intptr_t const nr, simd_double2 const * __nonnull const receivers,
                intptr_t const ns, simd_double2 const * __nonnull const sources,
                __complex double * __nonnull const F, intptr_t const ldF,
                intptr_t const sampling,
                intptr_t const elements,
                bem2_sample_t(^__attribute__((noescape))__nonnull const sampler)(intptr_t const, double const)) {
    dispatch_queue_t const queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    gl_quadrature_t const * __nonnull const quadrature = gl_quadrature_create(sampling);
    lu_solver_t const * __nullable const solver = lu_solver_create(elements, elements, ^(__complex double *__nonnull const A, intptr_t const ldA) {
        dispatch_apply(elements, queue, ^(size_t const i) {
            double const L = bem2_sample_length(quadrature, i, sampler);
            for ( register intptr_t j = 0 ; j < elements ; ++ j )
                A[i + j * ldA] = i == j ? -0.5 :
                gl_quadrature_integrate(quadrature, 0, 1, ^(double const*__nonnull const x, __complex double*__nonnull const y, intptr_t const length) {
                    for ( register intptr_t k = 0 ; k < length ; ++ k ) {
                        bem2_sample_t const e = sampler(i, x[k]);
                        y[k] = bem2_sample_jacobian(e) * layer2(wavenumber, bem2_sample_position(e), quadrature, j, sampler);
                    }
                }) / L;
        });
    });
    intptr_t const ldB = elements;
    intptr_t const ldC = nr;
    if ( solver ) __with_memory__((ns * ldB + elements * ldC) * sizeof(__complex double const), ^(void*__nonnull const memory) {
        __complex double * __nonnull const B = memory;
        __complex double * __nonnull const C = B + ns * ldB;
        dispatch_apply(elements, queue, ^(size_t const _) {
            double const L = bem2_sample_length(quadrature, _, sampler);
            for ( register intptr_t i = _, j = 0 ; j < ns ; ++ j ) {
                register simd_double2 const source = sources[j];
                B[i + j * ldB] = gl_quadrature_integrate(quadrature, 0, 1, ^(double const*__nonnull const x, __complex double*__nonnull const y, intptr_t const length) {
                    for ( register intptr_t k = 0 ; k < length ; ++ k ) {
                        bem2_sample_t const e = sampler(i, x[k]);
                        y[k] = bem2_sample_jacobian(e) * kernel0(wavenumber, bem2_sample_position(e), source);
                    }
                }) / L;
            }
            for ( register intptr_t i = 0, j = _ ; i < nr ; ++ i )
                C[i + j * ldC] = layer2(wavenumber, receivers[i], quadrature, j, sampler);
        });
        dispatch_apply(nr * ns, queue, ^(size_t const _) {
            intptr_t const i = _ % nr;
            intptr_t const j = _ / nr;
            F[i + j * ldF] = kernel0(wavenumber, receivers[i], sources[j]);
        });
        lu_solver_solve(solver, ns, B, ldB, B, ldB);
        zgemm_("N", "N",
               &nr, &ns, &elements,
               (__complex double[]){-1.0},
               C, &ldC,
               B, &ldB,
               (__complex double[]){ 1.0},
               F, &ldF);
    });
    if ( solver )
        lu_solver_destroy(solver);
    gl_quadrature_destroy(quadrature);
    return!solver;
}
__attribute__((always_inline))
bem2_t * __nonnull const bem2_create(double const wavenumber,
                                     intptr_t const elements,
                                     intptr_t const sampling,
                                     bem2_sample_t(^__attribute__((noescape))__nonnull sampler)(intptr_t const, double const)) {
    bem2_t * __nonnull const object = __malloc__(sizeof(bem2_t const));
    *(double *__nonnull const)&object->wavenumber = wavenumber;
    *(gl_quadrature_t const*__nonnull*__nonnull const)&object->quadrature = gl_quadrature_create(sampling);
    *(lu_solver_t const*__nonnull*__nonnull const)&object->solver = lu_solver_create(elements, elements, ^(__complex double*const __nonnull A, const intptr_t ldA) {
        
    });
    return object;
}
__attribute__((always_inline))
void bem2_evaluate(bem2_t const*__nonnull const object,
                   intptr_t const ns, simd_double2 const*__nonnull const sources,
                   intptr_t const nr, simd_double2 const*__nonnull const receivers,
                   __complex double * __nonnull const A, intptr_t const ldA) {
    __with_memory__((ns * nr + ns * object->solver->n) * sizeof(__complex double const), ^(void*__nonnull const memory) {
        // Ax = b
        __complex double * __nonnull const x = memory + 0 * nr * ns * sizeof(__complex double const);
        __complex double * __nonnull const b = memory + 1 * nr * ns * sizeof(__complex double const);
    });
}
__attribute__((always_inline))
void bem2_destroy(bem2_t const * __nonnull const object) {
    __free__((void*__nonnull const)object);
}
