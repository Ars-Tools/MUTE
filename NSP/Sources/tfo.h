//
//  ftf_filter.h
//  MUTE
//
//  Created by Kota on 8/20/R7.
//
// transversal filter operator based optimiser for continuous time series IO
typedef struct {
	intptr_t const n;
	intptr_t padding;
	double * __nonnull const G; // = G^{p}
	double * __nonnull const K; // = G^{p+1}
	double * __nonnull const A; // forward prediction alpha
	double * __nonnull const B; // backward prediction beta
	double lambda; // forget factor
	double theta;  // likelihood
	double zeta;   // previous dot(x, A)
	double eta;    // previous capture x[N]
} tfo_t;
tfo_t * __nonnull const tfo_create(intptr_t const order);
void tfo_destroy(tfo_t * __nonnull const object);
void tfo_reset(tfo_t * __nonnull const object);
double const tfo(tfo_t * __nonnull const object,
				 double const             y,
				 double const * __nonnull x, intptr_t const ldx,
				 double       * __nonnull w, intptr_t const ldw);
// TFO based O(p) RLS filter
typedef struct {
	tfo_t * __nonnull const core;
	double * __nonnull const w; // kernel
	double * __nonnull const h; // ring buffer
	double * __nonnull const x; // shuffled vector
	intptr_t t;
} tfo_filter_t;
tfo_filter_t * __nonnull const tfo_filter_create(intptr_t const order);
void tfo_filter_destroy(tfo_filter_t * __nonnull const object);
void tfo_filter_reset(tfo_filter_t * __nonnull const object);
void tfo_filter_lambda(tfo_filter_t * __nonnull const object, double const lambda);
void tfo_filter_kernel(tfo_filter_t * __nonnull const object,
					   double const * __nonnull y,
					   double const * __nonnull x,
					   double       * __nonnull w, intptr_t const ldw,
					   intptr_t const length);
void tfo_filter_error(tfo_filter_t * __nonnull const object,
					  double const * __nonnull y,
					  double const * __nonnull x,
					  double       * __nonnull e,
					  intptr_t const length);
