//
//  biquad_filter.c
//  MUTE
//
//  Created by Kota on 8/11/R7.
//
#include<Accelerate/Accelerate.h>
#include<simd/simd.h>
#include"biquad_filter.h"
__attribute__((always_inline))
biquad_filter_t * __nonnull const biquad_filter_create(intptr_t const c) {
	void * const p = CFAllocatorAllocateBytes(kCFAllocatorDefault, sizeof(biquad_filter_t const) + c * sizeof(simd_double4 const), 0);
	biquad_filter_t * const object = (biquad_filter_t * const)p;
	*(simd_double4**const)&object->s = (simd_double4*const)(p + sizeof(biquad_filter_t const));
	*(intptr_t*const)&object->z = c;
	biquad_filter_reset(object);
	return object;
}
__attribute__((always_inline))
void biquad_filter_destroy(biquad_filter_t * __nonnull const object) {
	CFAllocatorDeallocate(kCFAllocatorDefault, object);
}
__attribute__((always_inline))
void biquad_filter_reset(biquad_filter_t * __nonnull const object) {
	for ( register intptr_t k = 0, K = *(intptr_t*const)&object->z = object->z ; k < K ; ++ k )
		object->s[k] = simd_make_double4(0);
}
__attribute__((always_inline))
void biquad_filter_active(biquad_filter_t * __nonnull const object,
						  double const * __nonnull B, intptr_t const ldB,
						  double const * __nonnull A, intptr_t const ldA,
						  double const * __nonnull X, intptr_t const ldX,
						  double       * __nonnull Y, intptr_t const ldY,
						  intptr_t const length) {
	for ( register intptr_t c = object->z ; 0 < c -- ; )
		biquad_filter_convolve_active(B, ldB,
									  A, ldA,
									  X + ldX * c,
									  Y + ldY * c,
									  object->s + c,
									  length);
}
__attribute__((always_inline))
void biquad_filter_convolve_active(register double const * __nonnull b, register intptr_t const ldb,
								   register double const * __nonnull a, register intptr_t const lda,
								   register double const * __nonnull x,
								   register double       * __nonnull y,
								   simd_double4 * __nonnull s,
								   intptr_t const length) {
	register simd_double3 z = (simd_double3 const) {s->x, s->y, 0};
	register simd_double2 w = (simd_double2 const) {s->z, s->w};
	for ( register intptr_t k = 0, K = length ; k < K ; ++ k, ++ x, ++ y, ++ b, ++ a )
		w = (simd_double2 const) {
			*y = (simd_dot(z = (simd_double3 const) {*x, z.x, z.y}, (simd_double3 const) {*b, b[ldb], b[2*ldb]}) - simd_dot(w, (simd_double2 const) {a[lda], a[2*lda]})) / *a,
			w.x
		};
	*s = (simd_double4 const) {z.x, z.y, w.x, w.y};
}
__attribute__((always_inline))
void biquad_filter_convolve_static(register simd_double3 const b,
								   register simd_double3 const a,
								   register double const * __nonnull x,
								   register double       * __nonnull y,
								   simd_double4 * __nonnull s,
								   intptr_t const length) {
	register simd_double3 z = (simd_double3 const) {s->x, s->y, 0};
	register simd_double2 w = (simd_double2 const) {s->z, s->w};
	register simd_double2 const _ = (simd_double2 const) {a.y, a.z};
	for ( register intptr_t k = 0, K = length ; k < K ; ++ k, ++ x, ++ y )
		w = (simd_double2 const) {
			*y = (simd_dot(z = (simd_double3 const) {*x, z.x, z.y}, b) - simd_dot(w, _)) / a.x,
			w.x,
		};
	*s = (simd_double4 const) {z.x, z.y, w.x, w.y};
}
