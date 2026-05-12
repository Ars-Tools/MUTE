//
//  ssm.h
//  MUTE
//
//  Created by Kota on 5/11/26.
//
#include<stdint.h>
#include<CoreFoundation/CoreFoundation.h>
typedef struct {
    double * __nonnull const A;
    double * __nonnull const B;
    double * __nonnull const C;
    double * __nonnull const D;
    double * __nonnull const W;
    intptr_t const X;
    intptr_t const Y;
    intptr_t const Z;
} ssm_filter_t;
typedef CF_ENUM(uint8_t) {
    ssm_matrix_A,
    ssm_matrix_B,
    ssm_matrix_C,
    ssm_matrix_D,
} ssm_matrix_t;
ssm_filter_t * __nonnull const ssm_filter_create(intptr_t const x, intptr_t const y, intptr_t const z);
void ssm_filter_destroy(ssm_filter_t * __nonnull const object);
bool const ssm_filter_set(ssm_filter_t * __nonnull const object, ssm_matrix_t const matrix, intptr_t const row, intptr_t const col, double const val);
double const ssm_filter_get(ssm_filter_t * __nonnull const object, ssm_matrix_t const matrix, intptr_t const row, intptr_t const col);
void ssm_filter_z(ssm_filter_t * __nonnull const object, double const * __nonnull const z, intptr_t const inc);
void ssm_filter_z_clear(ssm_filter_t * __nonnull const object);
void ssm_filter(ssm_filter_t * __nonnull const object,
                double const * __nonnull const X, intptr_t const ldX,
                double       * __nonnull const Y, intptr_t const ldY,
                intptr_t const length);
__attribute__((always_inline))
void ssm_static(double const * __nonnull const X, intptr_t const ldX,
                double       * __nonnull const Y, intptr_t const ldY,
                double       * __nonnull const Z,
                double       * __nullable const W,
                double const * __nonnull const A, intptr_t const ldA,
                double const * __nonnull const B, intptr_t const ldB,
                double const * __nonnull const C, intptr_t const ldC,
                double const * __nonnull const D, intptr_t const ldD,
                intptr_t const mX,
                intptr_t const mY,
                intptr_t const mZ,
                intptr_t const NL);

