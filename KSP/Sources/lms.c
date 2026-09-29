//
//  lms.c
//  MUTE
//
//  Created by Kota on 8/19/R7.
//
#include"module.h"
#include"lms.h"
// Basic LMS
lms_t * __nonnull const lms_create(intptr_t const order) {
	void * __nonnull const p = __malloc__(sizeof(lms_t const));
	lms_t * __nonnull const object = (lms_t*__nonnull const)p;
	*(intptr_t*const)&object->n = order;
	return object;
}
void lms_destroy(lms_t * __nonnull const object) {
	__free__(object);
}
double lms(lms_t * __nonnull const object,
		   double const y,
		   double const * __nonnull const x, intptr_t const ldx,
		   double       * __nonnull const w, intptr_t const ldw) {
	intptr_t const n = object->n;
	double const e = y - ddot_(&n, x, &ldx, w, &ldw);
	double const d = object->mu * e;
	daxpy_(&n, &d, x, &ldx, w, &ldw);
	return e;
}
// filter
lms_filter_t * __nonnull const lms_filter_create(intptr_t const order) {
	void*__nonnull const p = __malloc__(sizeof(lms_filter_t const) + 3 * (order + 1) * sizeof(double const));
	lms_filter_t*__nonnull const object = (lms_filter_t*__nonnull const)p;
	*(lms_t**__nonnull const)&object->core = lms_create(order + 1);
	*(double**__nonnull const)&object->w = (double*__nonnull const)(p + sizeof(lms_filter_t const) + 0 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->h = (double*__nonnull const)(p + sizeof(lms_filter_t const) + 1 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->x = (double*__nonnull const)(p + sizeof(lms_filter_t const) + 2 * object->core->n * sizeof(double const));
	lms_filter_reset(object);
	return object;
}
void lms_filter_reset(lms_filter_t * __nonnull const object) {
	intptr_t const n = object->core->n;
	__clr__(object->h, 1, n);
	__clr__(object->w, 1, n);
	object->t = 0;
}
void lms_filter_destroy(lms_filter_t * __nonnull const object) {
	lms_destroy(object->core);
	__free__(object);
}
void lms_filter_mu(lms_filter_t * __nonnull const object, double const mu) {
	object->core->mu = mu;
}
void lms_filter_kernel(lms_filter_t * __nonnull const object,
					   double const * __nonnull y,
					   double const * __nonnull x,
					   double       * __nonnull w, intptr_t const ldw,
					   intptr_t const length) {
	lms_t * __nonnull const core = object->core;
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
		lms(core, *y, X, 1, W, 1);
		dcopy_(&N, W, (__LAPACK_int const[]) {1}, w, &ldw);
	}
	object->t = ( object->t + length ) % N;
}
void lms_filter_error(lms_filter_t * __nonnull const object,
					  double const * __nonnull y,
					  double const * __nonnull x,
					  double       * __nonnull e,
					  intptr_t const length) {
	lms_t * __nonnull const core = object->core;
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
		*e = lms(core, *y, X, 1, W, 1);
	}
	object->t = ( object->t + length ) % N;
}
