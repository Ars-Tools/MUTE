//
//  variable_filter.h
//  MUTE
//
//  Created by Kota on 10/21/R6.
//
#include<stdint.h>
#include<dispatch/dispatch.h>
typedef struct {
	double * __nonnull const x;
	double * __nonnull const y;
	intptr_t z;
	intptr_t w;
	intptr_t const a;
	intptr_t const b;
	intptr_t const c;
	dispatch_group_t __nullable const d;
} variable_filter_t;
variable_filter_t * __nonnull const variable_filter_create(intptr_t const a, intptr_t const b, intptr_t const c);
void variable_filter_destroy(variable_filter_t * __nonnull const object);
void variable_filter_execute(variable_filter_t * __nonnull const history,
							 double const * __nonnull A, intptr_t const ldA, intptr_t const lda,
							 double const * __nonnull B, intptr_t const ldB, intptr_t const ldb,
							 double const * __nonnull X, intptr_t const ldX, intptr_t const ldx,
							 double * __nonnull Y, intptr_t const ldY, intptr_t const ldy,
							 intptr_t const length);
void variable_conv(double const * __nonnull B, intptr_t const ldB,
				   double const * __nonnull A, intptr_t const ldA,
				   double const * __nonnull X, intptr_t const ldX,
				   double * __nonnull Y, intptr_t const ldY,
				   intptr_t const b, intptr_t const a,
				   intptr_t const m, intptr_t const n);
