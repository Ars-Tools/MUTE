//
//  lu.c
//  MUTE
//
//  Created by Kota on 6/16/26.
//
#include"module.h"
#include"lu_solver.h"
lu_solver_t const * __nullable const lu_solver_create(intptr_t const m, intptr_t const n,
                                                      void(^__attribute__((noescape))__nonnull const dense)(__complex double * __nonnull const, intptr_t const)) {
    void * __nonnull const memory = __malloc__(sizeof(lu_solver_t const) + m * n * sizeof(__complex double const) + MAX(m, n) * sizeof(intptr_t const));
    lu_solver_t const * __nonnull const object = memory;
    *(intptr_t*__nonnull const)&object->m = m;
    *(intptr_t*__nonnull const)&object->n = n;
    *(intptr_t*__nonnull*__nonnull const)&object->ipivot = memory + sizeof(lu_solver_t const);
    *(__complex double*__nonnull*__nonnull const)&object->matrix = memory + sizeof(lu_solver_t const) + MAX(object->m, object->n) * sizeof(intptr_t const);
    dense((__complex double*__nonnull const)object->matrix, object->m);
    intptr_t info = 0;
    zgetrf_(&object->m, &object->n,
            (__complex double*__nonnull)object->matrix, &object->n,
            (intptr_t*__nonnull)object->ipivot,
            &info);
    switch ( info ) {
        case 0:
            return object;
        default:
            __free__(memory);
            return NULL;
    }
}
intptr_t const lu_solver_solve(lu_solver_t const * __nonnull const object, intptr_t const nrhs,
                               __complex double const * __nonnull const b, intptr_t const ldb,
                               __complex double       * __nonnull const x, intptr_t const ldx) {
    intptr_t const static one = 1;
    intptr_t info = 0;
    switch (nrhs) {
        case 1:
            if ( b != x )
                zcopy_(&object->m, b, &ldb, x, &ldx);
            zgetrs_("N",
                    &object->n, &nrhs,
                    object->matrix, &object->m,
                    object->ipivot,
                    x, &object->n,
                    &info);
            break;
        default:
            if ( b != x ) for ( register intptr_t k = 0 ; k < nrhs ; ++ k )
                zcopy_(&object->m, b + k * ldb, &one, x + k * ldx, &one);
            zgetrs_("N",
                    &object->n, &nrhs,
                    object->matrix, &object->m,
                    object->ipivot,
                    x, &ldx,
                    &info);
            break;
    }
    return info;
}
void lu_solver_multiply(lu_solver_t const * __nonnull const object,
                        intptr_t const nrhs,
                        __complex double const * __nonnull const x, intptr_t const ldx,
                        __complex double       * __nonnull const y, intptr_t const ldy) {
    intptr_t const static _[] = {-1, 1};
    intptr_t const k = MIN(object->m, object->n);
    switch (nrhs) {
        case 1:
            if ( x != y )
                zcopy_((intptr_t const[]){MAX(object->m, object->n)}, x, &ldx, y, &ldy);
            ztrmv_("U", "N", "N",
                   &k,
                   object->matrix, &object->m,
                   y, _ + 1);
            ztrmv_("L", "N", "N",
                   &k,
                   object->matrix, &object->m,
                   y, _ + 1);
            zlaswp_(_ + 1,
                    y, _ + 1,
                    _ + 1,
                    &k,
                    object->ipivot, _);
            break;
        default:
            if ( x != y ) for ( register intptr_t k = 0 ; k < nrhs ; ++ k )
                zcopy_((intptr_t const[]){MAX(object->m, object->n)},
                       x + k * ldx, _ + 1,
                       y + k * ldy, _ + 1);
            ztrmm_("L", "U", "N", "N",
                   &object->m, &object->n,
                   (__complex double[]){1.0},
                   object->matrix, &object->m,
                   y, &ldy);
            ztrmm_("L", "L", "N", "U",
                   &object->m, &object->n,
                   (__complex double[]){1.0},
                   object->matrix, &object->m,
                   y, &ldy);
            zlaswp_(&nrhs,
                    y, &ldy,
                    _ + 1,
                    &k,
                    object->ipivot, _);
            break;
    }
}
void lu_solver_destroy(lu_solver_t const*__nonnull const object) {
    __free__((void*__nonnull const)object);
}
