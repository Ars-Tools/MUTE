//
//  median_filter.h
//  MUTE
//
//  Created by Kota on 7/24/R7.
//
#include<stdint.h>
typedef struct {
	double * __nonnull const x;
	double * __nonnull const w;
	intptr_t const m;
	intptr_t const n;
	intptr_t k;
} median_filter_t;
median_filter_t * __nonnull const median_filter_create(intptr_t const m, intptr_t const n);
void median_filter_destroy(median_filter_t * __nonnull const object);
void median_filter_execute(median_filter_t * __nonnull const object, double * const __nonnull x, intptr_t const ldx, intptr_t const length);
