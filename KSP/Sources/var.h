//
//  var.h
//  MUTE
//
//  Created by Kota on 11/13/25.
//
#include<simd/simd.h>
// MARK: 1
typedef struct {
    intptr_t const m;
    double c;
    double const lambda;
    struct {
        double d;
        double Q;
        double q;
    } stage[1];
} var1_t;
__attribute__((overloadable))
void var1(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          double const * __nonnull const,
          double const * __nonnull const,
          double * __nonnull const, // require stage
          intptr_t const, intptr_t const);
__attribute__((overloadable))
void var1(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          double * __nonnull const, // require stage
          intptr_t const, intptr_t const);
var1_t * __nonnull const var1_create(intptr_t const);
void var1_destroy(var1_t * __nonnull const);
void var1_reset(var1_t * __nonnull const, double const);
void var1_lambda(var1_t * __nonnull const, double const);
void var1_r(var1_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
void var1_p(var1_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
// MARK: 2
typedef struct {
    intptr_t const m;
    simd_double2x2 c;
    double const lambda;
    struct {
        simd_double2x2 d;
        simd_double2x2 Q;
        simd_double2 q;
    } stage[1];
} var2_t;
__attribute__((overloadable))
void var2(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          simd_double2x2 const * __nonnull const,
          simd_double2x2 const * __nonnull const,
          simd_double2 * __nonnull const,
          intptr_t const, intptr_t const);
__attribute__((overloadable))
void var2(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          simd_double2 * __nonnull const,
          intptr_t const, intptr_t const);
var2_t * __nonnull const var2_create(intptr_t const);
void var2_destroy(var2_t * __nonnull const);
void var2_reset(var2_t * __nonnull const, double const);
void var2_lambda(var2_t * __nonnull const, double const);
void var2_r(var2_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
void var2_p(var2_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
// MARK: 3
typedef struct {
    intptr_t const m;
    simd_double3x3 c;
    double const lambda;
    struct {
        simd_double3x3 d;
        simd_double3x3 Q;
        simd_double3 q;
    } stage[1];
} var3_t;
__attribute__((overloadable))
void var3(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          simd_double3x3 const * __nonnull const,
          simd_double3x3 const * __nonnull const,
          simd_double3 * __nonnull const, // require stage
          intptr_t const, intptr_t const);
__attribute__((overloadable))
void var3(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          simd_double3 * __nonnull const, // require stage
          intptr_t const, intptr_t const);
var3_t * __nonnull const var3_create(intptr_t const);
void var3_destroy(var3_t * __nonnull const);
void var3_reset(var3_t * __nonnull const, double const);
void var3_lambda(var3_t * __nonnull const, double const);
void var3_r(var3_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
void var3_p(var3_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
// MARK: 4
typedef struct {
    intptr_t const m;
    simd_double4x4 c;
    double const lambda;
    struct {
        simd_double4x4 d;
        simd_double4x4 Q;
        simd_double4 q;
    } stage[1];
} var4_t;
__attribute__((overloadable))
void var4(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          simd_double4x4 const * __nonnull const,
          simd_double4x4 const * __nonnull const,
          simd_double4 * __nonnull const, // require stage
          intptr_t const, intptr_t const);
__attribute__((overloadable))
void var4(double const * __nonnull const, intptr_t const,
          double       * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          double const * __nonnull const, intptr_t const,
          simd_double4 * __nonnull const, // require stage
          intptr_t const, intptr_t const);
var4_t * __nonnull const var4_create(intptr_t const);
void var4_destroy(var4_t * __nonnull const);
void var4_reset(var4_t * __nonnull const, double const);
void var4_lambda(var4_t * __nonnull const, double const);
void var4_r(var4_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
void var4_p(var4_t * __nonnull const,
            double const * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            double       * __nonnull const, intptr_t const,
            intptr_t const);
// MARK: N
typedef struct {
    intptr_t const n;
    intptr_t const m;
    // keep
    double * __nonnull const C; // cov[n][n]
    double * __nonnull const D; // Δ[m][n][n]
    double * __nonnull const z; // z[m][n]
    double * __nonnull const Z; // Z[m][n][n]
    // work
    double * __nonnull const F; // F[n][n]
    double * __nonnull const R; // R[n][n]
    double * __nonnull const Q; // Q[n][n]
    double * __nonnull const f; // f[n]
    double * __nonnull const r; // r[n]
    double * __nonnull const q; // q[n]
    // temp
    double * __nonnull const P; // P[n][n]
    intptr_t * __nonnull const p; // pivot[n]
    // param
    double const lambda;
} var_t;
__attribute__((overloadable))
void var(double const * __nonnull const, intptr_t const,
         double       * __nonnull const, intptr_t const,
         double const * __nonnull const, intptr_t const, intptr_t const,
         double const * __nonnull const, intptr_t const, intptr_t const,
         double       * __nonnull const, // require size * stage
         intptr_t const, intptr_t const, intptr_t const); // size, stage, length
__attribute__((overloadable))
void var(double const * __nonnull const, intptr_t const,
         double       * __nonnull const, intptr_t const,
         double const * __nonnull const, intptr_t const,
         double const * __nonnull const, intptr_t const,
         double       * __nonnull const, // require size * stage
         double       * __nullable const,
         intptr_t const, intptr_t const, intptr_t const); // size, stage, length
var_t * __nonnull const var_create(intptr_t const, intptr_t const);
void var_destroy(var_t * __nonnull const);
void var_reset(var_t * __nonnull const, double const);
void var_lambda(var_t * __nonnull const, double const);
void var_r(var_t * __nonnull const,
           double const * __nonnull const, intptr_t const,
           double       * __nonnull const, intptr_t const,
           intptr_t const);
void var_p(var_t * __nonnull const,
           double const * __nonnull const, intptr_t const,
           double       * __nonnull const, intptr_t const,
           double       * __nonnull const, intptr_t const,
           intptr_t const);
