//
//  universal_filter.c
//  MUTE
//
//  Created by Kota on 10/31/R6.
//
#include"module.h"
#include"universal_filter.h"
// dynamic iir filter, the coefficient will be change along with the time
universal_filter_t * __nonnull const universal_filter_create(intptr_t const b, intptr_t const a, intptr_t const c) {
	void * const p = __malloc__(sizeof(universal_filter_t const) + c * ( b + a ) * sizeof(double const));
	universal_filter_t * const object = (universal_filter_t * const)p;
	*(intptr_t*const)&object->a = a;
	*(intptr_t*const)&object->b = b;
	*(intptr_t*const)&object->c = c;
	*(intptr_t*const)&object->d = 0;
	*(double const**const)&object->x = (double*const)(p + sizeof(universal_filter_t const) + sizeof(double const) * 0 * b * c);
	*(double const**const)&object->y = (double*const)(p + sizeof(universal_filter_t const) + sizeof(double const) * 1 * b * c);
	object->z = 0;
	object->w = 0;
	universal_filter_reset(object);
	return object;
}
void universal_filter_destroy(universal_filter_t * __nonnull const object) {
	__free__(object);
}
void universal_filter_reset(universal_filter_t * __nonnull const object) {
	__clr__(object->x, 1, object->b);
	__clr__(object->y, 1, object->a);
}
void universal_filter_static(universal_filter_t * __nonnull const object,
							 double const * __nonnull B, intptr_t const ldB,
							 double const * __nonnull A, intptr_t const ldA,
							 double const * __nonnull X, intptr_t const ldX,
							 double       * __nonnull Y, intptr_t const ldY,
							 intptr_t const length) {
	static intptr_t const _[] = {-1, 1};
	register intptr_t const M = object->a;
	register intptr_t const N = object->b;
	for ( register intptr_t c = object->c ; 0 < c -- ; ) {
		register double const * __nonnull b = B + ldB * c;
		register double const * __nonnull a = A + ldA * c;
		register double const * __nonnull x = X + ldX * c;
		register double       * __nonnull y = Y + ldY * c;
		register double * __nonnull const n = object->x + N * c;
		register double * __nonnull const m = object->y + M * c;
		register intptr_t z = object->z;
		register intptr_t w = object->w;
		for ( register intptr_t t = length ; 0 < t -- ; ++ x, ++ y, z = ( z + 1 ) % M, w = ( w + 1 ) % N ) {
			n[w] = *x;
			m[z] = *y = simd_reduce_add((simd_double4 const) {
				+ddot_((intptr_t const[]){w+1}, n, &0[_], b  , &1[_]),
				+ddot_((intptr_t const[]){N-w-1}, n+w+1, &0[_], b+w+1, &1[_]),
				-ddot_((intptr_t const[]){z+0}, m, &0[_], a+1, &1[_]),
				-ddot_((intptr_t const[]){M-z-1}, m+z+1, &0[_], a+z+1, &1[_])
			}) / *a;
		}
	}
	object->z = ( object->z + length ) % M;
	object->w = ( object->w + length ) % N;
}
void universal_filter_active(universal_filter_t * __nonnull const object,
							 double const * __nonnull B, intptr_t const ldB,
							 double const * __nonnull A, intptr_t const ldA,
							 double const * __nonnull X, intptr_t const ldX,
							 double       * __nonnull Y, intptr_t const ldY,
							 intptr_t const length) {
	static intptr_t const _ = - 1;
	register intptr_t const M = object->a;
	register intptr_t const N = object->b;
	for ( register intptr_t c = object->c ; 0 < c -- ; ) {
		register double const * __nonnull b = B;
		register double const * __nonnull a = A;
		register double const * __nonnull x = X + ldX * c;
		register double       * __nonnull y = Y + ldY * c;
		register double * __nonnull const n = object->x + N * c;
		register double * __nonnull const m = object->y + M * c;
		register intptr_t z = object->z;
		register intptr_t w = object->w;
		for ( register intptr_t t = length ; 0 < t -- ; ++ b, ++ a, ++ x, ++ y, z = ( z + 1 ) % M, w = ( w + 1 ) % N ) {
			n[w] = *x;
			m[z] = *y = simd_reduce_add((simd_double4 const) {
				+ddot_((intptr_t const[]){w+1}, n, &_, b    , &ldB),
				+ddot_((intptr_t const[]){N-w-1}, n+w+1, &_, b+ldB*(w+1), &ldB),
				-ddot_((intptr_t const[]){z+0}, m, &_, a+ldA, &ldA),
				-ddot_((intptr_t const[]){M-z-1}, m+z+1, &_, a+ldA*(z+1), &ldA)
			}) / *a;
		}
	}
	object->z = ( object->z + length ) % M;
	object->w = ( object->w + length ) % N;
}
void universal_filter_matrix(universal_filter_t * __nonnull const object, // share filter kernel for all channel
							 double const * __nonnull B, intptr_t const ldb,
							 double const * __nonnull A, intptr_t const lda,
							 double const * __nonnull X, intptr_t const ldX,
							 double       * __nonnull Y, intptr_t const ldY,
							 intptr_t const length) {
	register double * __nonnull const m = object->y;
	register double * __nonnull const n = object->x;
	register intptr_t w = object->w;
	register intptr_t z = object->z;
	intptr_t const M = object->a;
	intptr_t const N = object->b;
	intptr_t const K = object->c;
	for ( register intptr_t t = length ; 0 < t -- ; ++ X, ++ Y, z = ( z + 1 ) % M, w = ( w + 1 ) % N ) {
		vDSP_mmovD(X, n + w, 1, K, ldX, N); // n[w%N] = *x for all channel
		dgemv_("T",
			   (intptr_t const[]){w+1}, &K,
			   (double const[]){1/+*A},
			   n + 0, &N,
			   B + 0, (intptr_t const[]){-1},
			   (double const[]){(double const)0},
			   Y, &ldY);
		dgemv_("T",
			   (intptr_t const[]){N-w-1}, &K,
			   (double const[]){1/+*A},
			   n + w + 1, &N,
			   B + w + 1, (intptr_t const[]){-1},
			   (double const[]){(double const)1},
			   Y, &ldY);
		dgemv_("T",
			   (intptr_t const[]){z+0}, &K,
			   (double const[]){1/-*A},
			   m + 0, &M,
			   A + 1, (intptr_t const[]){-1},
			   (double const[]){(double const)1},
			   Y, &ldY);
		dgemv_("T",
			   (intptr_t const[]){M-z-1}, &K,
			   (double const[]){1/-*A},
			   m + z + 1, &M,
			   A + z + 1, (intptr_t const[]){-1},
			   (double const[]){(double const)1},
			   Y, &ldY);
		vDSP_mmovD(Y, m + z, 1, K, ldY, M); // m[z%M] = *y for all channel
	}
	object->z = ( object->z + length ) % M;
	object->w = ( object->w + length ) % N;
}
// high density operation without any instance but fixed layout extra memory is required to manage previous input/output
// effect for massive multichannel filtering
void universal_convolution_static(register double const * __nonnull B, intptr_t const ldB,
								  register double const * __nonnull A, intptr_t const ldA,
								  register double const * __nonnull X, intptr_t const ldX,
								  register double       * __nonnull Y, intptr_t const ldY,
								  register intptr_t const b, register intptr_t const a,
								  intptr_t const m, intptr_t const n) {
	for ( register intptr_t t = n ; 0 < t -- ; ++ X, ++ Y ) {
		dgemv_("T",
			   (intptr_t const[]){b-0}, &m,
			   (double const[]){1/+*A},
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
void universal_convolution_active(register double const * __nonnull B, intptr_t const ldB,
								  register double const * __nonnull A, intptr_t const ldA,
								  register double const * __nonnull X, intptr_t const ldX,
								  register double       * __nonnull Y, intptr_t const ldY,
								  register intptr_t const b, register intptr_t const a,
								  intptr_t const m, intptr_t const n) {
	for ( register intptr_t t = n ; 0 < t -- ; ++ X, ++ Y, ++ B, ++ A ) {
		dgemv_("T",
			   (intptr_t const[]){b-0}, &m,
			   (double const[]){1/+*A},
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
