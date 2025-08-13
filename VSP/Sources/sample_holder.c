//
//  sample_holder.c
//  MUTE
//
//  Created by Kota on 10/18/R6.
//
#include<CoreFoundation/CoreFoundation.h>
#include<CoreMedia/CoreMedia.h>
#include"sample_holder.h"
sample_holder_t * const __nonnull sample_holder_create(intptr_t const stream) {
	void * const p = CFAllocatorAllocateBytes(kCFAllocatorDefault, stream * sizeof(double const) + sizeof(sample_holder_t const), 0);
	sample_holder_t*const object = (sample_holder_t*const)p;
	*(double**const)&object->latest = (double*const)(p + sizeof(sample_holder_t const));
	*(intptr_t*const)&object->stream = stream;
	return object;
}
void sample_holder_destroy(sample_holder_t * __nonnull const object) {
	CFAllocatorDeallocate(kCFAllocatorDefault, object);
}
void sample_holder_execute(sample_holder_t * __nonnull const object,
						   double const * __nonnull const X, intptr_t const ldX,
						   double const * __nonnull const Y, intptr_t const ldY,
						   double * __nonnull const Z, intptr_t const ldZ,
						   intptr_t const length) {
	for ( register intptr_t c = object->stream ; 0 < c -- ; ) {
		register double state = object->latest[c];
		register double const * x = X + ldX * c;
		register double const * y = Y + ldY * c;
		for ( register double * z = Z + ldZ * c, * const w = z + length ; z < w ; ++ x, ++ y, ++ z )
			*z = *y ? (state = *x) : state;
		object->latest[c] = state;
	}
}

void sample_holder_detect(sample_holder_t * __nonnull const object,
						  double const * __nonnull const X, intptr_t const ldX,
						  CMTime const moment,
						  CMTime const degree,
						  dispatch_source_type_t const source,
						  intptr_t const length) {
	for ( register intptr_t c = object->stream ; 0 < c -- ; ) {
		register double state = object->latest[c];
		register double const * x = X + ldX * c;
		
	}
}
