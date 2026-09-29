//
//  median_filter.c
//  MUTE
//
//  Created by Kota on 7/24/R7.
//
#include"module.h"
#include"median_filter.h"
median_filter_t * __nonnull const median_filter_create(intptr_t const m, intptr_t const n) {
	void * const memory = __malloc__(sizeof(median_filter_t const) + sizeof(double const) * ( m + 1 ) * n);
	median_filter_t*const object = (median_filter_t*const)memory;
	*(double const**const)&object->x = (double*const)(memory + sizeof(median_filter_t const) + 0 * m * n * sizeof(double const));
	*(double const**const)&object->w = (double*const)(memory + sizeof(median_filter_t const) + 1 * m * n * sizeof(double const));
	*(intptr_t*const)&object->m = m;
	*(intptr_t*const)&object->n = n;
	return object;
}
void median_filter_destroy(median_filter_t * __nonnull const object) {
	__free__(object);
}
void median_filter(median_filter_t * __nonnull const object,
				   double const * const __nonnull X, intptr_t const ldX,
				   double       * const __nonnull Y, intptr_t const ldY,
				   intptr_t const length) {
	register intptr_t const M = object->m;
	register intptr_t const N = object->n;
	register double * const W = object->w;
	for ( register intptr_t m = 0 ; m < M ; ++ m ) {
		register double const * __nonnull       x = X + m * ldX;
		register double       * __nonnull       y = Y + m * ldY;
		register double       * __nonnull const h = object->x + m * N;
		for ( register intptr_t t = object->k, T = t + length ; t < T ; ++ t, ++ x, ++ y ) {
			h[t%N] = *x;
			__sort__(h, W, N);
//			qsort_b(W, N, sizeof(double const), ^int(const void * x, const void * y) {
//				return*(double const*)x-*(double const*)y;
//			});
			*y = W[N/2];
		}
	}
	object->k = ( object->k + length ) % N;
}
