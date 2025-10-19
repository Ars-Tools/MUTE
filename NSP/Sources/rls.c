//
//  rls.c
//  MUTE
//
//  Created by Kota on 8/19/R7.
//
#include"module.h"
#include"rls.h"
// Basic RLS
rls_t * __nonnull const rls_create(intptr_t const order) {
	void * __nonnull const p = __malloc__(sizeof(rls_t const) + ( order + 1 ) * order * sizeof(double const));
	rls_t * __nonnull const object = (rls_t*__nonnull const)p;
	*(intptr_t*const)&object->n = order;
	*(double**const)&object->k = (double*const)(p + sizeof(rls_t const) + 0 * order * sizeof(double const));
	*(double**const)&object->p = (double*const)(p + sizeof(rls_t const) + 1 * order * sizeof(double const));
	rls_reset(object, 1);
	return object;
}
void rls_destroy(rls_t*__nonnull const object) {
	__free__(object);
}
void rls_reset(rls_t*__nonnull const object, double const eta) {
	intptr_t const n = object->n;
	__clr__(object->p, 1, n * n);
	__fill__(eta, object->p, n + 1, n);
}
double const rls_logdet(rls_t*__nonnull const object) {
	__LAPACK_int info = 0;
	intptr_t const N = object->n;
	double * __nonnull const R = __malloc__(N * N * sizeof(double const));
	dpotrf_("U", &N, memcpy(R, object->p, N * N * sizeof(double const)), &N, &info);
	if ( info ) {
		__free__(R);
		return FP_NAN;
	} else {
		register double r = 0;
		for ( register intptr_t n = 0 ; n < N ; ++ n )
			r += log2(R[n*n+n]);
		__free__(R);
		return M_LN2 * r;
	}
}
__attribute__((always_inline)) inline
double const rls(rls_t * __nonnull const object,
				 double const y,
				 double const * __nonnull const x, intptr_t const ldx,
				 double       * __nonnull const w, intptr_t const ldw) {
	static intptr_t const inc = 1;
	intptr_t const N = object->n;
	register double * __nonnull const p = object->p;
	register double * __nonnull const k = object->k;
	register double const lambda = object->lambda;
	dsymv_("U", &N,
		   (double const[]){1.0},
		   p, &N,
		   x, &ldx,
		   (double const[]){0.0},
		   k, &inc);
	double const gamma = -simd_precise_recip(lambda + ddot_(&N, x, &ldx, k, &inc));
	dsyr_("U", &N,
		  &gamma,
		  k, &inc,
		  p, &N);
	double const sigma = simd_precise_recip(lambda);
	for ( register intptr_t n = 0 ; n < N ; ++ n )
		dscal_((intptr_t const[]){n+1}, &sigma, p + n * N, &inc);
//		__vsdiv__(p + n * N, 1, lambda, p + n * N, 1, 1 + n);
	double const error = y - ddot_(&N, w, &ldw, x, &ldx);
	double const delta = error * -gamma;
	daxpy_(&N, &delta, k, &inc, w, &ldw);
	return error;
}
// Basic UDF, compute with UD decomposition, NOTE: slower than vanilla RLS powered by BLAS
__attribute__((always_inline)) inline
double const udf(rls_t * __nonnull const object,
				 double const y,
				 double       * __nonnull const x, intptr_t const ldx,
				 double       * __nonnull const w, intptr_t const ldw) {
	static intptr_t const inc = 1;
	intptr_t const N = object->n;
	register double * __nonnull const p = object->p;
	register double * __nonnull const k = object->k;
	register double const lambda = object->lambda;
	dtrmv_("U", "T", "U",
		   &N,
		   p, &N,
		   x, &ldx);
	register double a = lambda;
	double const error = y - ddot_(&N, w, &ldw, x, &ldx);
	for ( register intptr_t j = 0 ; j < N ; ++ j ) {
		register double * __nonnull const P = p + j * N,
		f = x[ldx*j],
		g = f * P[j],
		d = fma(f, g, a);
		P[j] *= a / d / lambda;
		k[j] = g;
		//
		register double u = -f / a; // u[j]
		for ( register intptr_t i = 0 ; i < j ; ++ i ) {
			register double const U = P[i];
			P[i] = fma(k[i], u, U); // U[i,j] += k[i] * u[j]
			k[i] = fma(k[j], U, k[i]);
		}
		a = d; // a[j] <= a[j]
	}
	__vsdiv__(k, 1, a, k, 1, N);
	daxpy_(&N, &error, k, &inc, w, &ldw);
	return error;
}
// filter
rls_filter_t * __nonnull const rls_filter_create(intptr_t const order) {
	void*__nonnull const p = __malloc__(sizeof(rls_filter_t const) + 3 * (order + 1) * sizeof(double const));
	rls_filter_t*__nonnull const object = (rls_filter_t*__nonnull const)p;
	*(rls_t**__nonnull const)&object->core = rls_create(order + 1);
	*(double**__nonnull const)&object->x = (double*__nonnull const)(p + sizeof(rls_filter_t const) + 0 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->h = (double*__nonnull const)(p + sizeof(rls_filter_t const) + 1 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->w = (double*__nonnull const)(p + sizeof(rls_filter_t const) + 2 * object->core->n * sizeof(double const));
	rls_filter_reset(object, 1);
	return object;
}
void rls_filter_destroy(rls_filter_t * __nonnull const object) {
	rls_destroy(object->core);
	__free__(object);
}
void rls_filter_reset(rls_filter_t * __nonnull const object, double const eta) {
	rls_reset(object->core, eta);
	intptr_t const n = object->core->n;
	__clr__(object->h, 1, n);
	__clr__(object->w, 1, n);
	object->t = 0;
}
void rls_filter_lambda(rls_filter_t * __nonnull const object, double const lambda) {
	object->core->lambda = lambda;
}
void rls_filter_kernel(rls_filter_t * __nonnull const object,
					   double const * __nonnull y,
					   double const * __nonnull x,
					   double       * __nonnull w, intptr_t const ldw,
					   intptr_t const length) {
	rls_t * __nonnull const core = object->core;
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
		rls(core, *y, X, 1, W, 1);
		dcopy_(&N, W, (__LAPACK_int const[]) {1}, w, &ldw);
	}
	object->t = ( object->t + length ) % N;
}
void rls_filter_error(rls_filter_t * __nonnull const object,
					  double const * __nonnull y,
					  double const * __nonnull x,
					  double       * __nonnull e,
					  intptr_t const length) {
	rls_t * __nonnull const core = object->core;
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
		*e = rls(core, *y, X, 1, W, 1);
	}
	object->t = ( object->t + length ) % N;
}
