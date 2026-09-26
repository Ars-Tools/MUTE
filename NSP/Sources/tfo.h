//
//  ftf_filter.h
//  MUTE
//
//  Created by Kota on 8/20/R7.
//
// transversal filter operator based optimiser for continuous time series IO
// stabilized FTF (Slock & Kailath 1991), gamma held as reciprocal gi = 1/γ:
//   gi₊  = fma(η, c, gi)     (c = η/(λF), shared with the gain head)
//   gi(n) = fma(-ψ₃, κ, gi₊) (gi = 1 + u·k̃ >= 1, one-sided rescue monitor)
// psi computed twice (fast/direct), difference injected with K = (1.5, 2.5, 1)
typedef struct {
	intptr_t const n;
	intptr_t rescue; // rescue count (roundoff divergence detected via gi < 1)
	double * __nonnull const G; // gain, order n+1
	double * __nonnull const K; // gain, order n
	double * __nonnull const A; // forward prediction (= w_f)
	double * __nonnull const B; // backward prediction (= w_b)
	double lambda; // forget factor
	double gamma;  // conversion factor (likelihood) = 1/gi, in (0, 1]
	double gi;     // 1/gamma = 1 + u·k̃, >= 1, fma-additive propagation
	double F;      // forward prediction error energy
	double Be;     // backward prediction error energy
	double zeta;   // previous dot(A, x)
	double eta;    // previous capture x[N-1]
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
