//
//  universal_filter.h
//  MUTE
//
//  Created by Kota on 10/31/R6.
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
} universal_filter_t;
universal_filter_t * __nonnull const universal_filter_create(intptr_t const b, intptr_t const a, intptr_t const c);
void universal_filter_destroy(universal_filter_t * __nonnull const object);
void universal_filter_static(universal_filter_t * __nonnull const object,
							 double const * __nonnull B, intptr_t const ldB, intptr_t const ldb,
							 double const * __nonnull A, intptr_t const ldA, intptr_t const lda,
							 double const * __nonnull X, intptr_t const ldX,
							 double       * __nonnull Y, intptr_t const ldY,
							 intptr_t const length);
void universal_filter_active(universal_filter_t * __nonnull const object,
							 double const * __nonnull B, intptr_t const ldB, intptr_t const ldb,
							 double const * __nonnull A, intptr_t const ldA, intptr_t const lda,
							 double const * __nonnull X, intptr_t const ldX,
							 double       * __nonnull Y, intptr_t const ldY,
							 intptr_t const length);
void universal_filter_matrix(universal_filter_t * __nonnull const object,
							 double const * __nonnull B, intptr_t const ldb,
							 double const * __nonnull A, intptr_t const lda,
							 double const * __nonnull X, intptr_t const ldX,
							 double       * __nonnull Y, intptr_t const ldY,
							 intptr_t const length);
void universal_convolution_static(double const * __nonnull B, intptr_t const ldB,
								  double const * __nonnull A, intptr_t const ldA,
								  double const * __nonnull X, intptr_t const ldX,
								  double       * __nonnull Y, intptr_t const ldY,
								  intptr_t const b, intptr_t const a,
								  intptr_t const m, intptr_t const n);
void universal_convolution_active(double const * __nonnull B, intptr_t const ldB,
								  double const * __nonnull A, intptr_t const ldA,
								  double const * __nonnull X, intptr_t const ldX,
								  double       * __nonnull Y, intptr_t const ldY,
								  intptr_t const b, intptr_t const a,
								  intptr_t const m, intptr_t const n);

