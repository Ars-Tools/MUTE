//
//  rls.h
//  MUTE
//
//  Created by Kota on 8/19/R7.
//
#include<stdint.h>
// optimiser
// MARK: Real
typedef struct {
	intptr_t const n;
	double lambda;
	double * __nonnull const p; // p-cov matrix
	double * __nonnull const k; // memory
} rls_t;
__attribute__((overloadable))
rls_t*__nonnull const rls_create(intptr_t const);
__attribute__((overloadable))
void rls_destroy(rls_t*__nonnull const object);
__attribute__((overloadable))
void rls_reset(rls_t*__nonnull const object, double const eta);
__attribute__((overloadable))
double const rls_logdet(rls_t*__nonnull const object);
__attribute__((overloadable))
double const rls(rls_t * __nonnull const object,
				 double const y,
				 double const * __nonnull const x, intptr_t const ldx,
				 double       * __nonnull const w, intptr_t const ldw);
double const udf(rls_t * __nonnull const object,
				 double const y,
				 double       * __nonnull const x, intptr_t const ldx,
				 double       * __nonnull const w, intptr_t const ldw);
// MARK: Complex
typedef struct {
    intptr_t const n;
    double lambda;
    __complex double * __nonnull const p;
    __complex double * __nonnull const k;
} rls_complex_t;
__attribute__((overloadable))
rls_complex_t*__nonnull const rls_complex_create(intptr_t const);
__attribute__((overloadable, always_inline))
void rls_destroy(rls_complex_t*__nonnull const);
__attribute__((overloadable))
void rls_reset(rls_complex_t*__nonnull const, __complex double);
__attribute__((overloadable))
void rls_lambda(rls_complex_t*__nonnull const, double const);
// Complex RLS stores the conjugated coefficient estimate:
//     y = w^H x,  w = conj(w_physical).
// Conjugate w when copying the estimated physical coefficients out.
__attribute__((overloadable, always_inline))
__complex double const rls(rls_complex_t * __nonnull const object,
                           __complex double const y,
                           __complex double const * __nonnull const x, intptr_t const ldx,
                           __complex double       * __nonnull const w, intptr_t const ldw);

// MARK: RLS Filter
typedef struct {
	rls_t * __nonnull const core;
	double * __nonnull const w; // kernel
	double * __nonnull const h; // ring buffer
	double * __nonnull const x; // shuffled vector
	intptr_t t;
} rls_filter_t;
rls_filter_t * __nonnull const rls_filter_create(intptr_t const order);
void rls_filter_destroy(rls_filter_t * __nonnull const object);
void rls_filter_reset(rls_filter_t * __nonnull const object, double const eta);
void rls_filter_lambda(rls_filter_t * __nonnull const object, double const lambda);
void rls_filter_kernel(rls_filter_t * __nonnull const object,
					   double const * __nonnull y, // target
					   double const * __nonnull x, // source (time series)
					   double       * __nonnull w, intptr_t const ldw, // estimated kernel
					   intptr_t const length);
void rls_filter_error(rls_filter_t * __nonnull const object,
					  double const * __nonnull y, // target
					  double const * __nonnull x, // source (time series)
					  double       * __nonnull e, // residual
					  intptr_t const length);
double const rls_filter_det(rls_filter_t const * __nonnull const object);
// MARK: RLS Complex Filter
typedef struct {
    intptr_t t;
    __complex double * __nonnull const x; // [T] workspace
    __complex double * __nonnull const w; // [T] conj(kernel)
    __complex double * __nonnull const h; // [T] ringbuffer for x
    rls_complex_t rls;
} rls_filter_complex_t;
__attribute__((overloadable))
rls_filter_complex_t * __nonnull const rls_complex_filter_create(intptr_t const order);
__attribute__((overloadable))
void rls_filter_destroy(rls_filter_complex_t*__nonnull const);
// MARK: RLS Complex Filter Bank
typedef struct {
    intptr_t const count; // channel
    intptr_t const order; // filter length
    __complex double * __nonnull const w; // [count, order], channel-major, conj(kernel)
    __complex double * __nonnull const h; // [order, count], channel-minor, 0-started buffer for history
    rls_complex_t rls[];
} rls_complex_filterbank_t;
__attribute__((overloadable))
rls_complex_filterbank_t * __nonnull const rls_complex_filter_create(intptr_t const order, intptr_t const channel);
__attribute__((overloadable))
void rls_filter_destroy(rls_complex_filterbank_t*__nonnull const);
__attribute__((overloadable))
void rls_filter_lambda(rls_complex_filterbank_t*__nonnull const, double const);
__attribute__((overloadable))
void rls_filter_reset(rls_complex_filterbank_t*__nonnull const);
__attribute__((overloadable))
void rls_filter_coefficients(rls_complex_filterbank_t*__nonnull const,
                             __complex double * __nonnull, intptr_t const,
                             __complex double * __nonnull, intptr_t const,
                             __complex double * _Nullable, intptr_t const,
                             intptr_t const);
__attribute__((overloadable))
void rls_filter_error(rls_complex_filterbank_t*__nonnull const,
                      __complex double * __nonnull, intptr_t const);
