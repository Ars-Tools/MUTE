//
//  median_filter.c
//  MUTE
//
//  Created by Kota on 7/24/R7.
//
#include<float.h>
#include"CoreFoundation/CoreFoundation.h"
#include"median_filter.h"
median_filter_t * __nonnull const median_filter_create(intptr_t const m, intptr_t const n) {
	void * const memory = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(median_filter_t const) + sizeof(double const) * ( m + 1 ) * n, 0);
	median_filter_t*const object = (median_filter_t*const)memory;
	*(double const**const)&object->x = (double*const)(memory + sizeof(median_filter_t const) + 0 * m * n * sizeof(double const));
	*(double const**const)&object->w = (double*const)(memory + sizeof(median_filter_t const) + 1 * m * n * sizeof(double const));
	*(intptr_t*const)&object->m = m;
	*(intptr_t*const)&object->n = n;
	return object;
}
void median_filter_destroy(median_filter_t * __nonnull const object) {
	CFAllocatorDeallocate(kCFAllocatorDefault, object);
}
void median_filter_execute(median_filter_t * __nonnull const object, double * const __nonnull X, intptr_t const ldX, intptr_t const length) {
	register intptr_t const M = object->m;
	register intptr_t const N = object->n;
	register double * const W = object->w;
	for ( register intptr_t m = 0 ; m < M ; ++ m ) {
		register intptr_t i = object->k;
		register double * h = object->x + m * N;
		for ( double * x = X + m * ldX, * const _ = x + length ; x < _ ; ++ x ) {
			h[++i%N] = *x;
			memcpy(W, h, N * sizeof(double const));
			qsort_b(W, N, sizeof(double const), ^int(const void * x, const void * y) {
				return*(double const*)x-*(double const*)y;
			});
			*x = W[N/2];
		}
	}
	object->k = ( object->k + length ) % N;
}
