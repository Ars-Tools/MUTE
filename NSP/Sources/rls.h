//
//  rls.h
//  MUTE
//
//  Created by Kota on 8/19/R7.
//
#include<stdint.h>
// optimiser
typedef struct {
	intptr_t const n;
	double lambda;
	double * __nonnull const p; // p-cov matrix
	double * __nonnull const k; // memory
} rls_t;
rls_t*__nonnull const rls_create(intptr_t const);
void rls_destroy(rls_t*__nonnull const object);
void rls_reset(rls_t*__nonnull const object, double const eta);
double const rls_logdet(rls_t*__nonnull const object);
double const rls(rls_t * __nonnull const object,
				 double const y,
				 double const * __nonnull const x, intptr_t const ldx,
				 double       * __nonnull const w, intptr_t const ldw);
double const udf(rls_t * __nonnull const object,
				 double const y,
				 double       * __nonnull const x, intptr_t const ldx,
				 double       * __nonnull const w, intptr_t const ldw);
// filter
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
