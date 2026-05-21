//
//  ssm.c
//  MUTE
//
//  Created by Kota on 5/11/26.
//
#include"ssm.h"
#include"module.h"
__attribute__((visibility("hidden")))
static intptr_t const one = 1;
ssm_filter_t * __nonnull const ssm_filter_create(intptr_t const X, intptr_t const Y, intptr_t const Z) {
    void * __nonnull const memory = __malloc__(sizeof(ssm_filter_t const) + sizeof(double const) * (Z * Z + Z * X + Y * Z + Y * X + Z * 2));
    ssm_filter_t * __nonnull const object = (ssm_filter_t*__nonnull const)memory;
    *(intptr_t*__nonnull const)&object->X = X;
    *(intptr_t*__nonnull const)&object->Y = Y;
    *(intptr_t*__nonnull const)&object->Z = Z;
    *(double const*__nonnull*)&object->A = (double*__nonnull const)(memory + sizeof(ssm_filter_t const));
    *(double const*__nonnull*)&object->B = object->A + object->Z * object->Z;
    *(double const*__nonnull*)&object->C = object->B + object->Z * object->X;
    *(double const*__nonnull*)&object->D = object->C + object->Y * object->Z;
    *(double const*__nonnull*)&object->W = object->D + object->Y * object->X;
    return object;
}
void ssm_filter_destroy(ssm_filter_t * __nonnull const object) {
    __free__(object);
}
void ssm_filter(ssm_filter_t * __nonnull const object,
                double const * __nonnull const X, intptr_t const ldX,
                double       * __nonnull const Y, intptr_t const ldY,
                intptr_t const length) {
    /*
     y ← C • z + D • x
     z ← A • z + B • x
     */
    ssm_static(X, ldX,
               Y, ldY,
               object->W, object->W + object->Z,
               object->A, object->Z,
               object->B, object->Z,
               object->C, object->Y,
               object->D, object->Y,
               object->X,
               object->Y,
               object->Z,
               length);
}
/*
void ssm_filter_a(ssm_filter_t * __nonnull const object, double const * __nonnull const a, intptr_t const lda, ssm_major_t const major) {
    switch (major) {
        case COL:
            for ( register double * __nonnull X = a, * __nonnull Y = object->A, * __nonnull _ = Y + object->Z * object->Z ; Y < _ ; X += lda, Y += object->Z )
                dcopy_(&object->Z, X, &one, Y, &one);
            break;
        case ROW:
            for ( register double * __nonnull X = a, * __nonnull Y = object->A, * __nonnull _ = Y + object->Z * object->Z ; Y < _ ; ++ X, Y += object->Z )
                dcopy_(&object->Z, X, &lda, Y, &one);
            break;
    }
}
void ssm_filter_b(ssm_filter_t * __nonnull const object, double const * __nonnull const b, intptr_t const ldb, ssm_major_t const major) {
    switch (major) {
        case COL:
            for ( register double * __nonnull X = b, * __nonnull Y = object->B, * __nonnull _ = Y + object->Z * object->X ; Y < _ ; X += ldb, Y += object->Z )
                dcopy_(&object->Z, X, &one, Y, &one);
            break;
        case ROW:
            for ( register double * __nonnull X = b, * __nonnull Y = object->B, * __nonnull _ = Y + object->Z * object->X ; Y < _ ; ++ X, Y += object->Z )
                dcopy_(&object->Z, X, &ldb, Y, &one);
            break;
    }
}
void ssm_filter_c(ssm_filter_t * __nonnull const object, double const * __nonnull const c, intptr_t const ldc, ssm_major_t const major) {
    switch (major) {
        case COL:
            for ( register double * __nonnull X = c, * __nonnull Y = object->C, * __nonnull _ = Y + object->Y * object->Z ; Y < _ ; X += ldc, Y += object->Y )
                dcopy_(&object->Y, X, &one, Y, &one);
            break;
        case ROW:
            for ( register double * __nonnull X = c, * __nonnull Y = object->C, * __nonnull _ = Y + object->Y * object->Z ; Y < _ ; ++ X, Y += object->Y )
                dcopy_(&object->Y, X, &ldc, Y, &one);
            break;
    }
}
void ssm_filter_d(ssm_filter_t * __nonnull const object, double const * __nonnull const d, intptr_t const ldd, ssm_major_t const major) {
    switch (major) {
        case COL:
            for ( register double * __nonnull X = d, * __nonnull Y = object->D, * __nonnull _ = Y + object->Y * object->X ; Y < _ ; X += ldd, Y += object->Y )
                dcopy_(&object->Y, X, &one, Y, &one);
            break;
        case ROW:
            for ( register double * __nonnull X = d, * __nonnull Y = object->D, * __nonnull _ = Y + object->Y * object->X ; Y < _ ; ++ X, Y += object->Y )
                dcopy_(&object->Y, X, &ldd, Y, &one);
            break;
    }
}
 */
void ssm_filter_z(ssm_filter_t * __nonnull const object, double const* __nonnull const z, intptr_t const inc) {
    dcopy_(&object->Z, z, inc, object->W, (intptr_t const[]){1});
}
void ssm_filter_z_clear(ssm_filter_t * __nonnull const object) {
    __clr__(object->W, 1, object->Z);
}
intptr_t const ssm_filter_input(ssm_filter_t const * __nonnull const object) {
    return object->X;
}
intptr_t const ssm_filter_state(ssm_filter_t const * __nonnull const object) {
    return object->Z;
}
intptr_t const ssm_filter_output(ssm_filter_t const * __nonnull const object) {
    return object->Y;
}
bool const ssm_filter_set(ssm_filter_t * __nonnull const object, ssm_matrix_t const matrix, intptr_t const row, intptr_t const col, double const val) {
    simd_long2 const pos = {row, col};
    switch (matrix) {
        case ssm_matrix_A:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Z, object->Z}) ? object->A[row + col * object->Z] = val, TRUE : FALSE;
        case ssm_matrix_B:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Z, object->X}) ? object->B[row + col * object->Z] = val, TRUE : FALSE;
        case ssm_matrix_C:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Y, object->Z}) ? object->C[row + col * object->Y] = val, TRUE : FALSE;
        case ssm_matrix_D:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Y, object->X}) ? object->D[row + col * object->Y] = val, TRUE : FALSE;
        default:
            return FALSE;
    }
}
double const ssm_filter_get(ssm_filter_t * __nonnull const object, ssm_matrix_t const matrix, intptr_t const row, intptr_t const col) {
    simd_long2 const pos = {row, col};
    switch (matrix) {
        case ssm_matrix_A:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Z, object->Z}) ? object->A[row + col * object->Z] : NAN;
        case ssm_matrix_B:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Z, object->X}) ? object->B[row + col * object->Z] : NAN;
        case ssm_matrix_C:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Y, object->Z}) ? object->C[row + col * object->Y] : NAN;
        case ssm_matrix_D:
            return simd_all(simd_make_long2(0) <= pos && pos < (simd_long2 const) {object->Y, object->X}) ? object->D[row + col * object->Y] : NAN;
        default:
            return NAN;
    }
}
__attribute__((always_inline))
void ssm_static(register double const * __nonnull X, intptr_t const ldX,
                register double       * __nonnull Y, intptr_t const ldY,
                register double       * __nonnull Z,
                register double       * __nullable W,
                double const * __nonnull const A, intptr_t const ldA,
                double const * __nonnull const B, intptr_t const ldB,
                double const * __nonnull const C, intptr_t const ldC,
                double const * __nonnull const D, intptr_t const ldD,
                intptr_t const mX,
                intptr_t const mY,
                intptr_t const mZ,
                intptr_t const NC) {
    if (!W)
        W = (double*__nonnull const)alloca(sizeof(double const) * mZ);
    for ( double const * __nonnull const _ = X + NC ; X < _ ; ++ X, ++ Y ) {
        /*
         z_next ← A • z + B • x
         y ← C • z + D • x
         z ← z_next
         
         =
         
         y <= C • z
         z <= A • z
         y += D • x
         z += B • x
         
         */
        memcpy(W, Z, sizeof(double const) * mZ);
        dgemv_("N", &mZ, &mZ, (double const[]){1}, A, &ldA, W, &one, (double const[]){0}, Z, &one);
        dgemv_("N", &mZ, &mX, (double const[]){1}, B, &ldB, X, &ldX, (double const[]){1}, Z, &one);
        dgemv_("N", &mY, &mZ, (double const[]){1}, C, &ldC, W, &one, (double const[]){0}, Y, &ldY);
        dgemv_("N", &mY, &mX, (double const[]){1}, D, &ldD, X, &ldX, (double const[]){1}, Y, &ldY);
    }
}
