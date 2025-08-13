//
//  random_number_generator.h
//  MUTE
//
//  Created by Kota on 11/8/R6.
//
#include<stdint.h>
void uniform_f64(double * __nonnull const r, intptr_t const ldr,
				 double const * __nonnull a, intptr_t const lda,
				 double const * __nonnull b, intptr_t const ldb,
				 intptr_t const number,
				 intptr_t const length);
