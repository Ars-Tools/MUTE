//
//  variable_filter.c
//  MUTE
//
//  Created by Kota on 10/21/R6.
//
#include<Accelerate/Accelerate.h>
#include<simd/simd.h>
#include"variable_conv.h"
variable_filter_t * __nonnull const variable_filter_create(intptr_t const a, intptr_t const b, intptr_t const c) {
	void * const p = CFAllocatorAllocateBytes(kCFAllocatorDefault, sizeof(variable_filter_t const) + c * ( a + b ) * sizeof(double const), 0);
	variable_filter_t * const object = (variable_filter_t * const)p;
	*(intptr_t*const)&object->a = a;
	*(intptr_t*const)&object->b = b;
	*(intptr_t*const)&object->c = c;
	*(intptr_t*const)&object->d = 0;
	*(double const**const)&object->x = (double*const)(p + sizeof(variable_filter_t const) + sizeof(double const) * 0 * a * c);
	*(double const**const)&object->y = (double*const)(p + sizeof(variable_filter_t const) + sizeof(double const) * 1 * a * c);
	object->z = 0;
	object->w = 0;
	return object;
}
void variable_filter_destroy(variable_filter_t * __nonnull const object) {
	CFAllocatorDeallocate(kCFAllocatorDefault, object);
}
void variable_filter_execute(variable_filter_t * __nonnull const history,
							 double const * __nonnull A, intptr_t const ldA, intptr_t const lda,
							 double const * __nonnull B, intptr_t const ldB, intptr_t const ldb,
							 double const * __nonnull X, intptr_t const ldX, intptr_t const ldx,
							 double       * __nonnull Y, intptr_t const ldY, intptr_t const ldy,
							 intptr_t const length) {
	static intptr_t const _ = - 1;
	register intptr_t const M = history->a;
	register intptr_t const N = history->b;
	for ( register intptr_t c = history->c ; 0 < c -- ; ) {
		register double const * __nonnull a = A + ldA * c;
		register double const * __nonnull b = B + ldB * c;
		register double * const y = history->y + M * c;
		register double * const x = history->x + N * c;
		register intptr_t z = history->z;
		register intptr_t w = history->w;
		for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ a, ++ b, z = ( z + 1 ) % M, w = ( w + 1 ) % N ) {
			x[w%N] = X[t+ldx*c];
			y[z%M] = Y[t+ldy*c] = simd_reduce_add((simd_double4 const){
				 ddot_((intptr_t const[]){w+1}, x, &_, b    , &ldb),
				 ddot_((intptr_t const[]){N-w-1}, x+w+1, &_, b+ldb*(w+1), &ldb),
				-ddot_((intptr_t const[]){z+0}, y, &_, a+lda, &lda),
				-ddot_((intptr_t const[]){M-z-1}, y+z+1, &_, a+lda*(z+1), &lda)
			}) / *a;
//			simd_dot((simd_double4 const){1, 1, -1, -1},
//										   simd_make_double4(ddot_((intptr_t const[]){w+1}, x, &_, b    , &ldb),
//															 ddot_((intptr_t const[]){N-w-1}, x+w+1, &_, b+ldb*(w+1), &ldb),
//															 ddot_((intptr_t const[]){z+0}, y, &_, a+lda, &lda),
//															 ddot_((intptr_t const[]){M-z-1}, y+z+1, &_, a+lda*(z+1), &lda))) / *a;
		}
	}
	history->z = ( history->z + length ) % M;
	history->w = ( history->w + length ) % N;
}
// high efficient but require extra memory and previous signal
void variable_conv(register double const * __nonnull B, intptr_t const ldB,
				   register double const * __nonnull A, intptr_t const ldA,
				   register double const * __nonnull X, intptr_t const ldX,
				   register double * __nonnull Y, intptr_t const ldY,
				   register intptr_t const b, register intptr_t const a,
				   intptr_t const m, intptr_t const n) {
	for ( register intptr_t t = n ; 0 < t -- ; ++ B, ++ A, ++ X, ++ Y ) {
		dgemv_("T",
			   (intptr_t const[]){b-0}, &m,
			   (double const[]){1/ *A},
			   X, &ldX,
			   B,     (intptr_t const[]){-ldB},
			   (double const[]){(double const)0},
			   Y+a-1, &ldY);
		dgemv_("T",
			   (intptr_t const[]){a-1}, &m,
			   (double const[]){1/-*A},
			   Y, &ldY,
			   A+ldA, (intptr_t const[]){-ldA},
			   (double const[]){(double const)1},
			   Y+a-1, &ldY);
	}
}
