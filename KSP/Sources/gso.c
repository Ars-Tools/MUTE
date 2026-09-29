//
//  gso.c
//  MUTE
//
//  Created by Kota on 8/21/R7.
//
#include"module.h"
#include"gso.h"
gso_t * __nonnull const gso_create(intptr_t const count) {
	void * __nonnull const p = __malloc__(sizeof(gso_t const) + (3 * count + 1) * count * sizeof(double const));
	gso_t * __nonnull const object = (gso_t*__nonnull const)p;
	*(intptr_t*__nonnull const)&object->n = count;
	*(double**const)&object->D = (double*const)(p + sizeof(gso_t const) + 0 * count * count * sizeof(double const));
	*(double**const)&object->U = (double*const)(p + sizeof(gso_t const) + 1 * count * count * sizeof(double const));
	*(double**const)&object->A = (double*const)(p + sizeof(gso_t const) + 2 * count * count * sizeof(double const));
	*(double**const)&object->S = (double*const)(p + sizeof(gso_t const) + 3 * count * count * sizeof(double const));
	gso_reset(object, 1);
	return object;
}
void gso_destroy(gso_t * __nonnull const object) {
	__free__(object);
}
void gso_reset(gso_t * __nonnull const object, double const theta) {
	register intptr_t const N = object->n;
	__fill__(theta, object->S, 1, N);
	__clr__(object->D, 1, N * N);
	__clr__(object->A, 1, N * N);
	__clr__(object->U, 1, N * N);
}
void gso_lambda(gso_t * __nonnull const object, double const lambda) {
	object->lambda = lambda;
}
void gso_residual(gso_t * __nonnull const object,
				  register double const * __nonnull x, intptr_t const ldx,
				  register double       * __nonnull e, intptr_t const lde,
				  intptr_t const length) {
	static intptr_t const inc = 1;
	intptr_t const N = object->n;
	register double const lambda = object->lambda;
	register double * const D = object->D, * const A = object->A, * const U = object->U, * const S = object->S;
	for ( register double const * __nonnull const _ = x + length ; x < _ ; ++ x, ++ e ) {
		dcopy_(&N, x, &ldx, object->U, &inc);
		register double theta = 1;
		for ( register double * s = S, * const t = s + N - 1, * u = U, * d = D, * a = A ; s < t ; ++ s, d += N, u += N, a += N ) {
			register intptr_t const q = t - s;
			register double const
			eta = u[q],
			zeta = eta * theta,
			delta = -eta * (*s /= fma(*s, eta * zeta, lambda));
			__vsmsma__(d, 1, lambda,
					   u, 1, zeta,
					   d, 1,
					   q);
			__vsma__(d, 1, delta, u, 1, u + N, 1, q);
			theta /= fma(delta, zeta, 1);
			assert(0 < *s);
			assert(0 < theta);
		}
		dcopy_(&N, U+N-1, (intptr_t const[]){1-N}, e, &lde);
	}
}

void gso_weight(gso_t * __nonnull const object,
				register double const * __nonnull x, intptr_t const ldx,
				register double const * __nonnull s, intptr_t const lds,
				register double       * __nonnull t, intptr_t const ldt,
				intptr_t const length) {
	static intptr_t const inc = 1;
	intptr_t const N = object->n;
	register double const lambda = object->lambda;
	register double * const D = object->D, * const A = object->A, * const U = object->U, * const S = object->S;
	if ( s != t || lds != ldt )
		__mcopy__(s, lds, t, ldt, N, length);
	for ( register double const * __nonnull const _ = x + length ; x < _ ; ++ x, ++ t ) {
		dcopy_(&N, x, &ldx, object->U, &inc);
		register double theta = 1;
		for ( register double * s = S, * const t = s + N - 1, * u = U, * d = D, * a = A + N * N - N; s < t ; ++ s, d += N, u += N, a -= N ) {
			register intptr_t const q = t - s;
			register double const
			eta = u[q],
			zeta = eta * theta,
			delta = eta * zeta;
			__vsmsma__(d, 1, lambda,
					   u, 1, zeta,
					   d, 1, q);
			__vsm__(d, 1, *s /= fma(*s, delta, lambda), a, 1, q);
			__vsma__(a, 1,
					 -eta,
					 u, 1,
					 u + N, 1,
					 q);
			theta /= fma(-*s, delta, 1);
			assert(0 <= *s);
			assert(0 <= theta);
		}
		dtrsv_("U", "T", "U",
			   &N,
			   A, &N,
			   t, &ldt);
	}
}
void gso_matrix(gso_t * __nonnull const object,
				register double const * __nonnull x, intptr_t const ldx,
				register double const * __nonnull s, intptr_t const lds,
				register double       * __nonnull t, intptr_t const ldt,
				intptr_t const length) {
	static intptr_t const inc = 1;
	intptr_t const N = object->n;
	register double const lambda = object->lambda;
	register double * const D = object->D, * const A = object->A, * const U = object->U, * const S = object->S;
	if ( s != t || lds != ldt )
		__mcopy__(s, lds, t, ldt, N, length);
	for ( register double const * __nonnull const _ = x + length ; x < _ ; ++ x, ++ t ) {
		dcopy_(&N, x, &ldx, object->U, &inc);
		register double theta = 1;
		for ( register double * s = S, * const t = s + N - 1, * u = U, * d = D, * a = A + N * N - N; s < t ; ++ s, d += N, u += N, a -= N ) {
			register intptr_t const q = t - s;
			register double const
			eta = u[q],
			zeta = eta * theta,
			delta = eta * zeta;
			__vsmsma__(d, 1, lambda,
					   u, 1, zeta,
					   d, 1, q);
			__vsm__(d, 1, *s /= fma(*s, delta, lambda), a, 1, q);
			__vsma__(a, 1,
					 -eta,
					 u, 1,
					 u + N, 1,
					 q);
			theta /= fma(-*s, delta, 1);
			assert(0 <= *s);
			assert(0 <= theta);
		}
		dtrmv_("U", "T", "U",
			   &N,
			   A, &N,
			   t, &ldt);
	}
}
