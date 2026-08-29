//
//  bem.h
//  MUTE
//
//  Created by Kota on 6/11/26.
//
#include<CoreFoundation/CoreFoundation.h>
#include<simd/simd.h>
#include"lu_solver.h"
#include"gl_quadrature.h"
typedef CF_ENUM(uint8_t const) {
    LU,
    GMRES
} bem_solver_t;
typedef CF_ENUM(uint8_t const) {
    SINGLE,
    DOUBLE
} bem_layer_t;
typedef struct {
    double const wavenumber;
    lu_solver_t * __nonnull const solver;
    gl_quadrature_t const * __nonnull const quadrature;
//    void(^__nonnull const sampler)(intptr_t const*__nonnull const, double const*__nonnull const intptr_t const);
} bem2_t;
typedef struct {
    simd_double2 const position;
    simd_double2 const gradient;
} bem2_sample_t;
typedef struct {
    
} bem3_t;
typedef struct {
    simd_double3 const position;
    simd_double3 const gradient;
} bem3_sample_t;
__attribute__((always_inline, __overloadable__))
bool const bem2(double const wavenumber,
                intptr_t const nr, simd_double2 const * __nonnull const receivers,
                intptr_t const ns, simd_double2 const * __nonnull const sources,
                __complex double * __nonnull const F, intptr_t const ldF,
                intptr_t const sampling,
                intptr_t const elements,
                bem2_sample_t(^__attribute__((noescape))__nonnull const sampler)(intptr_t const, double const));
bem2_t * __nonnull const bem2_create(double const wavenumber,
                                     intptr_t const elements,
                                     intptr_t const sampling,
                                     bem2_sample_t(^__attribute__((noescape))__nonnull sampler)(intptr_t const, double const));
void bem2_evaluate(bem2_t const*__nonnull const,
                   intptr_t const ns, simd_double2 const*__nonnull const sources,
                   intptr_t const nr, simd_double2 const*__nonnull const receivers,
                   __complex double * __nonnull const A, intptr_t const ldA);
void bem2_destroy(bem2_t const*__nonnull const);
