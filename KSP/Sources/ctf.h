//
//  ctf.h
//  MUTE
//
//  Created by Kota on 9/10/26.
//
#pragma once

#include <complex.h>
#include <stdint.h>

typedef enum {
    CTF_ESTIMATOR_RLS = 0,
} ctf_estimator_t;

/*
 * Public estimator state for Swift-side inspection.
 * Pointer values are lifetime-fixed; the storage they address is mutable.
 *
 *   history    [bin][input][lag]
 *   weight     [bin][output][input * order + lag]
 *   covariance [bin][dimension][dimension], column-major, upper triangle valid
 *
 * covariance is the inverse input normal matrix (precision-domain state),
 * not an estimated output variance.
 */
typedef struct {
    intptr_t const i;         // inputs
    intptr_t const o;         // outputs
    intptr_t const b;         // frequency bins
    intptr_t const order;     // CTF frames per input
    intptr_t const dimension; // inputs * order
    ctf_estimator_t const estimator;

    __complex double * __nonnull const history;
    __complex double * __nonnull const weight;
    __complex double * __nonnull const covariance;
    __complex double * __nonnull const regressor;
    __complex double * __nonnull const gain;
    __complex double * __nonnull const error;

    union {
        struct {
            double lambda; // forgetting factor, stored directly
        } rls;
    };
} ctf_t;

ctf_t * __nonnull const ctf_create_rls(intptr_t const inputs,
                                        intptr_t const outputs,
                                        intptr_t const bins,
                                        intptr_t const order);
void ctf_destroy(ctf_t * __nonnull const object);

void ctf_rls_reset(ctf_t * __nonnull const object, double const eta);
void ctf_rls_lambda(ctf_t * __nonnull const object, double const lambda);

/*
 * Process one DFT frame.  The caller owns the time progression and supplies
 * slot = frameIndex % order:
 * X[input * ldX + bin], Y[output * ldY + bin], E[output * ldE + bin].
 * E may be NULL when residual output is unnecessary.
 */
void ctf_rls_update(ctf_t * __nonnull const object,
                    intptr_t const slot,
                    __complex double const * __nonnull const X,
                    intptr_t const ldX,
                    __complex double const * __nonnull const Y,
                    intptr_t const ldY,
                    __complex double * __nullable const E,
                    intptr_t const ldE);
