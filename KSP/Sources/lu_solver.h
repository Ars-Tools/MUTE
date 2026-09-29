//
//  lu.h
//  MUTE
//
//  Created by Kota on 6/16/26.
//
#include<stdint.h>
typedef struct {
    intptr_t const m;
    intptr_t const n;
    intptr_t const * __nonnull const ipivot;
    __complex double const * __nonnull const matrix;
} lu_solver_t;
lu_solver_t const * __nullable const lu_solver_create(intptr_t const m, intptr_t const n,
                                                      void(^__attribute__((noescape))__nonnull const)(__complex double * __nonnull const, intptr_t const));
intptr_t const lu_solver_solve(lu_solver_t const * __nonnull const object, intptr_t const nrhs,
                               __complex double const * __nonnull const b, intptr_t const ldx,
                               __complex double       * __nonnull const x, intptr_t const ldb);
void lu_solver_multiply(lu_solver_t const * __nonnull const object,
                        intptr_t const nrhs,
                        __complex double const * __nonnull const x, intptr_t const ldx,
                        __complex double       * __nonnull const y, intptr_t const ldy);
void lu_solver_destroy(lu_solver_t const * __nonnull const object);
