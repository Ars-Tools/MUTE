//
//  sample_holder.h
//  MUTE
//
//  Created by Kota on 10/18/R6.
//
#include<stdint.h>
typedef struct {
	double * __nonnull const latest;
	intptr_t const stream;
} sample_holder_t;
sample_holder_t * __nonnull const sample_holder_create(intptr_t const stream);
void sample_holder_destroy(sample_holder_t * __nonnull const object);
void sample_holder_execute(sample_holder_t * __nonnull const object,
						   double const * __nonnull const X, intptr_t const ldX, // source
						   double const * __nonnull const Y, intptr_t const ldY, // holder
						   double * __nonnull const Z, intptr_t const ldZ,
						   intptr_t const length);
