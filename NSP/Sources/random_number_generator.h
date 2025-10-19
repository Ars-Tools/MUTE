//
//  random_number_generator.h
//  MUTE
//
//  Created by Kota on 11/8/R6.
//
#include<stdint.h>
void uniform_rng(double * __nonnull const r, intptr_t const ldr,
				 double const * __nonnull a, intptr_t const lda,
				 double const * __nonnull b, intptr_t const ldb,
				 intptr_t const number,
				 intptr_t const length);
void cauchy_rng(double * __nonnull const r, intptr_t const ldr,
				double const * __nonnull x, intptr_t const ldx,
				double const * __nonnull g, intptr_t const ldg,
				intptr_t const number,
				intptr_t const length);
void gauss_rng(double * __nonnull const r, intptr_t const ldr,
			   double const * __nonnull u, intptr_t const ldu,
			   double const * __nonnull s, intptr_t const lds,
			   intptr_t const number,
			   intptr_t const length);
