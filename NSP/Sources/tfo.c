//
//  ftf_filter.c
//  MUTE
//
//  Created by Kota on 8/20/R7.
//
#include"module.h"
#include"tfo.h"
tfo_t * __nonnull const tfo_create(intptr_t const order) {
	void * __nonnull const p = __malloc__(sizeof(tfo_t const) + ( 4 * order + 1 ) * sizeof(double const)); // G requires [order + 1]
	tfo_t * __nonnull const object = (tfo_t*__nonnull const)p;
	*(intptr_t*const)&object->n = order;
	*(double**__nonnull const)&object->B = (double*__nonnull const)(p + sizeof(tfo_t const) + 0 * order * sizeof(double const));
	*(double**__nonnull const)&object->A = (double*__nonnull const)(p + sizeof(tfo_t const) + 1 * order * sizeof(double const));
	*(double**__nonnull const)&object->K = (double*__nonnull const)(p + sizeof(tfo_t const) + 2 * order * sizeof(double const));
	*(double**__nonnull const)&object->G = (double*__nonnull const)(p + sizeof(tfo_t const) + 3 * order * sizeof(double const));
	tfo_reset(object);
	return object;
}
void tfo_destroy(tfo_t * __nonnull const object) {
	__free__(object);
}
void tfo_reset(tfo_t * __nonnull const object) {
	object->theta = FLT_EPSILON;
	object->zeta = 0;
	object->eta = 0;
	__clr__(object->B, 1, object->n);
	__clr__(object->A, 1, object->n);
	__clr__(object->K, 1, object->n);
	__clr__(object->G, 1, object->n + 1);
}
double const tfo(tfo_t * __nonnull const object,
				 double const             y,
				 double const * __nonnull x, intptr_t const ldx,
				 double       * __nonnull w, intptr_t const ldw) {
	static intptr_t const inc = 1;
	intptr_t const N = object->n;
	register double const lambda = object->lambda;
	// F
	double const
		fr = *x - object->zeta,
		fp = fr * object->theta,
		F = fma(fr, fp, lambda);
	// A
	 daxpy_(&N, &fp, object->K, &inc, object->A, &inc);
//	__vsmsma__(object->K, 1, fp, object->A, 1, lambda, object->A, 1, N); // with forgetting factor to forget previous numerical error
	// G
	__vsma__(object->A, 1, *object->G = fr / F, object->K, 1, object->G + 1, 1, N);
	// U
	double const
		rr = object->eta - ddot_(&N, object->B, &inc, x, &ldx),
		rp = rr * (object->theta = lambda / fma(rr, rr, F / object->theta)),
		R = fma(fr, fp, lambda);
	// K
	__vsma__(object->B, 1, -object->G[N], object->G, 1, object->K, 1, N);
	// B
	 daxpy_(&N, &rp, object->K, &inc, object->B, &inc);
//	__vsmsma__(object->K, 1, rp, object->B, 1, lambda, object->B, 1, N); // with forgetting factor to forget previous numerical error
	// E
	double const
		er = y - ddot_(&N, w, &ldw, x, &ldx),
		ep = er * object->theta * lambda / F;
	// W
	daxpy_(&N, &ep, object->G, &inc, w, &ldw);
	// Rescaling
	object->theta *= simd_precise_rsqrt(F * R);
//	object->theta = pow(object->theta, lambda);
	// cache for next update
	object->eta = x[N-1];
	object->zeta = ddot_(&N, object->A, &inc, x, &ldx);
	return er;
//	// VER.1
//	// capture λ * current F
//	double const Q = lambda * object->F;
//	
//	// (6.10)
//	double const bf = *x + object->zeta;
//	
//	// (6.34)
//	double const f = bf / object->theta;
//
//	// (6.38)
//	object->F = simd_dot((simd_double2 const) { lambda, bf }, (simd_double2 const) { object->F, f });
//	
//	// GUARD
//	if ( !(epsilon < object->F) ) {
//		++object->recover;
//		tfo_reset(object);
//		return 0;
//	}
//	
//	// (6.39)
//	double const eta = object->F / Q * object->theta;
//	
//	// (6.51)
//	__vsma__(object->A, 1, *object->G = bf / Q, object->K, 1, object->G + 1, 1, N);
//	
//	// (6.54)
//	double const br = lambda * object->G[N] * object->R;
//	
//	// (6.49)
//	object->theta = fabs(eta - object->G[N] * br); //
//	assert(isnormal(object->theta));
//	
//	// (6.37)
//	double const r = br / object->theta;
//	
//	// (6.40)
//	object->R = simd_dot((simd_double2 const) { lambda, br }, (simd_double2 const) { object->R, r });
//	
//	// (6.47)
//	daxpy_(&N, (double const[]){-f}, object->K, &inc, object->A, &inc);
//	
//	// (6.53)
//	__vsma__(object->B, 1, -object->G[N], object->G, 1, object->K, 1, N);
//	
//	// (6.48)
//	daxpy_(&N, (double const[]){-r}, object->K, &inc, object->B, &inc);
//	
//	// (6.16)
//	double const e = y - ddot_(&N, w, &ldw, x, &ldx);
//	
//	// (6.22)
//	double const d = e / eta;
//	
//	// (6.46)
//	daxpy_(&N, &d, object->G, &inc, w, &ldw);
//	
//	// for next update
//	object->zeta = ddot_(&N, object->A, &inc, x, &ldx);
//	return e;
}
tfo_filter_t * __nonnull const tfo_filter_create(intptr_t const order) {
	void * __nonnull const p = __malloc__(sizeof(tfo_filter_t const) + 3 * ( order + 1 ) * sizeof(double const));
	tfo_filter_t * __nonnull const object = (tfo_filter_t*__nonnull const)p;
	*(tfo_t**__nonnull const)&object->core = tfo_create(order + 1);
	*(double**__nonnull const)&object->x = (double*__nonnull const)(p + sizeof(tfo_filter_t const) + 0 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->h = (double*__nonnull const)(p + sizeof(tfo_filter_t const) + 1 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->w = (double*__nonnull const)(p + sizeof(tfo_filter_t const) + 2 * object->core->n * sizeof(double const));
	tfo_filter_reset(object);
	return object;
}
void tfo_filter_destroy(tfo_filter_t * __nonnull const object) {
	tfo_destroy(object->core);
	__free__(object);
}
void tfo_filter_reset(tfo_filter_t * __nonnull const object) {
	tfo_reset(object->core);
	intptr_t const n = object->core->n;
	__clr__(object->h, 1, n);
	__clr__(object->w, 1, n);
	object->w[0] = 1;
	object->t = 0;
}
void tfo_filter_lambda(tfo_filter_t * __nonnull const object, double const lambda) {
	object->core->lambda = lambda;
}
void tfo_filter_kernel(tfo_filter_t * __nonnull const object,
					   double const * __nonnull y,
					   double const * __nonnull x,
					   double       * __nonnull w, intptr_t const ldw,
					   intptr_t const length) {
	tfo_t * __nonnull const core = object->core;
	intptr_t const N = core->n;
	register double * __nonnull const W = object->w;
	register double * __nonnull const H = object->h;
	register double * __nonnull const X = object->x;
	for ( register intptr_t t = object->t, T = t + length ; t < T ; ++ t, ++ y, ++ x, ++ w ) {
		register intptr_t
		tail = t % N + 1,
		head = N - tail;
		H[head] = *x;
		memcpy(X, H + head, tail * sizeof(double const));
		memcpy(X + tail, H, head * sizeof(double const));
		tfo(core, *y, X, 1, W, 1);
		daxpy_(&N, (double const[]){1}, W, (intptr_t const[]){1}, w, &ldw);
	}
	object->t = ( object->t + length ) % N;
}
void tfo_filter_error(tfo_filter_t * __nonnull const object,
					  double const * __nonnull y,
					  double const * __nonnull x,
					  double       * __nonnull e,
					  intptr_t const length) {
	tfo_t * __nonnull const core = object->core;
	intptr_t const N = core->n;
	register double * __nonnull const W = object->w;
	register double * __nonnull const H = object->h;
	register double * __nonnull const X = object->x;
	for ( register intptr_t t = object->t, T = t + length ; t < T ; ++ t, ++ y, ++ x, ++ e ) {
		register intptr_t
		tail = t % N + 1,
		head = N - tail;
		H[head] = *x;
		memcpy(X, H + head, tail * sizeof(double const));
		memcpy(X + tail, H, head * sizeof(double const));
		*e = tfo(core, *y, X, 1, W, 1);
	}
	object->t = ( object->t + length ) % N;
}
static double tfo_rls_reference(double const * __nonnull x,
                                double const * __nonnull y,
                                double       * __nonnull w,
                                intptr_t const T,
                                intptr_t const p,
                                double const lambda) {
    static double const delta = 1e6;
    static intptr_t const inc = 1;
    static double const zero = 0, one = 1, minus = -1;
    intptr_t const n = p + 1;
    double * __nonnull const P = alloca((intptr_t)(n * n) * sizeof(double));
    double * __nonnull const u = alloca((intptr_t)n * sizeof(double));
    double * __nonnull const k = alloca((intptr_t)n * sizeof(double));
    double * __nonnull const q = alloca((intptr_t)n * sizeof(double));
    double e = 0;

    __clr__(w, 1, n);
    for ( intptr_t c = 0 ; c < n ; ++ c ) {
        __clr__(P + c * n, 1, n);
        P[c * n + c] = delta;
    }

    for ( intptr_t t = p ; t < T ; ++ t ) {
        for ( intptr_t i = 0 ; i < n ; ++ i ) u[i] = x[t - i];
        dgemv_("N",
               &n, &n,
               &one,
               P, &n,
               u, &inc,
               &zero,
               q, &inc);
        double const denom = lambda + ddot_(&n, u, &inc, q, &inc);
        double const scale = simd_precise_recip(denom);
        dcopy_(&n, q, &inc, k, &inc);
        dscal_(&n, &scale, k, &inc);

        e = y[t] - ddot_(&n, w, &inc, u, &inc);
        daxpy_(&n, &e, k, &inc, w, &inc);

        // P <- (P - k * u^T * P) / lambda = (P - k * q^T) / lambda
        dger_(&n, &n,
              &minus,
              k, &inc,
              q, &inc,
              P, &n);
        intptr_t info = 0;
        dlascl_("G", &info, &info,
                &lambda, &one,
                &n, &n,
                P, &n,
                &info);
        assert(!info);
    }
    return e;
}
double tfo_ref(double const * __nonnull x, double const * __nonnull y, double * __nonnull w, intptr_t T, intptr_t p, double lambda) {
    return tfo_rls_reference(x, y, w, T, p, lambda);
}
double tfo_raw(double const * __nonnull x, double const * __nonnull y, double * __nonnull w, intptr_t T, intptr_t p, double lambda) {
    return tfo_rls_reference(x, y, w, T, p, lambda);
}
