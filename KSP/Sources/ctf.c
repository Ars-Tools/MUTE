//
//  ctf.c
//  MUTE
//
//  Created by Kota on 9/10/26.
//
#include"ctf.h"
#include"module.h"
__attribute__((__visibility__("hidden"))) static
intptr_t const inc = 1;
// MARK: RLS

ctf_t * __nonnull const ctf_create_rls(
    intptr_t const inputs,
    intptr_t const outputs,
    intptr_t const bins,
    intptr_t const order
) {
    assert(0 < inputs);
    assert(0 < outputs);
    assert(0 < bins);
    assert(0 < order);

    intptr_t const dimension = inputs * order;
    size_t const history_count = (size_t)bins * inputs * order;
    size_t const weight_count = (size_t)bins * outputs * dimension;
    size_t const covariance_count = (size_t)bins * dimension * dimension;
    size_t const regressor_count = (size_t)dimension;
    size_t const gain_count = (size_t)dimension;
    size_t const error_count = (size_t)outputs;
    size_t const complex_count = history_count + weight_count
                               + covariance_count + regressor_count
                               + gain_count + error_count;

    void * __nonnull const allocation = __malloc__(
        sizeof(ctf_t)
        + complex_count * sizeof(__complex double)
    );
    ctf_t * __nonnull const object = (ctf_t * __nonnull const)allocation;
    __complex double *memory = (__complex double *)(object + 1);

    *(intptr_t *)&object->i = inputs;
    *(intptr_t *)&object->o = outputs;
    *(intptr_t *)&object->b = bins;
    *(intptr_t *)&object->order = order;
    *(intptr_t *)&object->dimension = dimension;
    *(ctf_estimator_t *)&object->estimator = CTF_ESTIMATOR_RLS;
    *(__complex double **)&object->history = memory;
    memory += history_count;
    *(__complex double **)&object->weight = memory;
    memory += weight_count;
    *(__complex double **)&object->covariance = memory;
    memory += covariance_count;
    *(__complex double **)&object->regressor = memory;
    memory += regressor_count;
    *(__complex double **)&object->gain = memory;
    memory += gain_count;
    *(__complex double **)&object->error = memory;

    object->rls.lambda = 1.0;
    ctf_rls_reset(object, 1.0);
    return object;
}

void ctf_destroy(ctf_t * __nonnull const object) {
    __free__(object);
}

void ctf_rls_reset(ctf_t * __nonnull const object, double const eta) {
    assert(object->estimator == CTF_ESTIMATOR_RLS);
    assert(isfinite(eta) && 0.0 < eta);

    intptr_t const B = object->b;
    intptr_t const inputs = object->i;
    intptr_t const O = object->o;
    intptr_t const N = object->dimension;

    __clr__(object->history, 1, B * inputs * object->order);
    __clr__(object->weight, 1, B * O * N);
    __clr__(object->covariance, 1, B * N * N);
    __clr__(object->regressor, 1, N);
    __clr__(object->gain, 1, N);
    __clr__(object->error, 1, O);

    for ( intptr_t bin = 0 ; bin < B ; ++ bin )
        __fill__(eta, object->covariance + bin * N * N, N + 1, N);
        
}

void ctf_rls_lambda(ctf_t * __nonnull const object,
                    double const lambda) {
    assert(object->estimator == CTF_ESTIMATOR_RLS);
    assert(isfinite(lambda) && 0.0 < lambda && lambda <= 1.0);
    object->rls.lambda = lambda;
}

void ctf_rls_update(ctf_t * __nonnull const object,
                    intptr_t const slot,
                    __complex double const *  __nonnull const X, intptr_t const ldX,
                    __complex double const *  __nonnull const Y, intptr_t const ldY,
                    __complex double       * __nullable const E, intptr_t const ldE) {
    assert(object->estimator == CTF_ESTIMATOR_RLS);
    assert(0 < ldX);
    assert(0 < ldY);
    assert(!E || 0 < ldE);

    intptr_t const b = object->b;
    intptr_t const i = object->i;
    intptr_t const o = object->o;
    intptr_t const c = object->order;
    intptr_t const n = object->dimension;
    double const lambda = object->rls.lambda;

    __complex double * __nonnull const x = object->regressor;
    __complex double * __nonnull const v = object->gain;
    __complex double * __nonnull const error = object->error;

    for ( intptr_t bin = 0 ; bin < b ; ++ bin ) {
        __complex double * __nonnull const w = object->weight + bin * o * n;
        __complex double * __nonnull const p = object->covariance + bin * n * n;
        
        // Insert this frame, then gather [input][newest ... oldest].
        {
            intptr_t const tail = slot % c + 1;
            intptr_t const head = c - tail;
            __complex double * const history =
                object->history + bin * i * c;

            // 最新フレームをhistory[:, head]へ格納
            zcopy_(
                &i,
                X + bin, &ldX,
                history + head, &c
            );
            zlacpy_(
                "A",
                &tail, &i,
                history + head, &c,
                x, &c
            );

            zlacpy_(
                "A",
                &head, &i,
                history, &c,
                x + tail, &c
            );
        }
//        zcopy_(&i,
//               X + bin, &ldX,
//               object->history + bin * i * c + (slot % c + c) % c, &c);
//        for ( intptr_t lag = 0 ; lag < c ; ++ lag )
//            zcopy_(&i,
//                   object->history + bin * i * c + (slot % c + c - lag) % c, &c,
//                   x + lag, &c);
        
        // Physical CTF convention: y = W^T x (no conjugation of x).
        zcopy_(&o,
               Y + bin, &ldY,
               error, &inc);
        zgemv_("T",
               &n, &o,
               (__complex double const[]){ -1.0 },
               w, &n,
               x, &inc,
               (__complex double const[]){ 1.0 },
               error, &inc);
        if (E)
            zcopy_(&o, error, &inc, E + bin, &ldE);
        
        /*
         * v = sqrt(precision) P conj(x), where
         * precision = 1 / (lambda + x^T P conj(x)).
         * zdotc(conj(x), v) evaluates x^T v.  zdotc_ is the
         * double-complex counterpart of cdotc_.
         */
        zlacgv_(&n, x, &inc);
        zhemv_("U", &n,
               (__complex double const[]) {1.0},
               p, &n,
               x, &inc,
               (__complex double const[]) {0.0},
               v, &inc);
        
        __complex double quadratic = 0.0;
        zdotc_(&quadratic, &n, x, &inc, v, &inc);
        double const denominator = lambda + __real(quadratic);
        assert(isfinite(denominator) && 0.0 < denominator);
        
        double const square_root_precision = simd_precise_rsqrt(denominator);
        zdscal_(&n, &square_root_precision, v, &inc);
        
        // P <- (P - v v^H) / lambda; only the upper triangle is valid.
        zher_("U", &n,
              (double const[]){-1.0},
              v, &inc,
              p, &n);
        intptr_t info = 0; // kl = 0, ku = 0
        zlascl_("U", &info, &info,
                &lambda,
                (double const[]){ 1.0},
                &n, &n,
                p, &n,
                &info);
        assert(!info);
        // W <- W + v (sqrt(precision) e).
        zgeru_(&n, &o,
               (__complex double const[]){ square_root_precision },
               v, &inc,
               error, &inc,
               w, &n);
    }
}
