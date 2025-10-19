//
//  duffing.c
//  MUTE
//
//  Created by Kota on 8/17/R7.
//
#include"module.h"
#include"duffing.h"
__attribute__((always_inline, visibility("hidden"))) static inline
double const newton_raphson_solver(double const x, double const a, double const b) { // solve α*y^3 + β*y = x, faster?
	static const double EPS = FLT_EPSILON; // 1e-3
	static const intptr_t MAX_ITER = 1000;
	register double y = x;
	for ( register intptr_t k = MAX_ITER ; -- k ; ) {
		register double const
			y2 = y * y,
			dy = fma(3 * a, y2, b),
			fy = fma(a, y * y2, fma(b, y, -x)),
			yn = y - fy / dy;
		if ( fabs ( y - yn ) < EPS ) break;
		else y = yn;
	}
	return y;
}
__attribute__((always_inline, visibility("hidden"))) static inline
double const cardano_solver(double const x, double const a, double const b) { // solve α*y^3 + β*y = x, precise
	if ( fabs(a) < FLT_EPSILON ) {
		return x / b;
	} else {
		register double const
			Q = b / ( 3.0 * a ),
			R = x / ( 2.0 * a ),
			P = Q * Q * Q,
			D = fma(R, R, P);
		return D < 0 ?
			2 * sqrt(-Q) * cos(acos(R * simd_rsqrt(-P)) / 3) :
			simd_reduce_add(_simd_cbrt_d2(fma(((simd_double2 const) {-1, 1}), sqrt(D), R)));
	}
}
__attribute__((always_inline))
duffing_filter_t * __nonnull const duffing_filter_create(intptr_t const c) {
	void * const p = __malloc__(sizeof(duffing_filter_t const) + c * sizeof(simd_double4 const));
	duffing_filter_t * const object = (duffing_filter_t * const)p;
	*(simd_double4**const)&object->s = (simd_double4*const)(p + sizeof(duffing_filter_t const));
	*(intptr_t*const)&object->z = c;
	duffing_filter_reset(object);
	return object;
}
__attribute__((always_inline))
void duffing_filter_destroy(duffing_filter_t * __nonnull const object) {
	__free__(object);
}
__attribute__((always_inline))
void duffing_filter_reset(duffing_filter_t * __nonnull const object) {
	for ( register intptr_t k = 0, K = *(intptr_t*const)&object->z = object->z ; k < K ; ++ k )
		object->s[k] = simd_make_double4(0);
}
__attribute__((always_inline))
void duffing_filter_active(duffing_filter_t * __nonnull const object,
						   double const * __nonnull B, intptr_t const ldB,
						   double const * __nonnull A, intptr_t const ldA,
						   double const * __nonnull X, intptr_t const ldX,
						   double       * __nonnull Y, intptr_t const ldY,
						   intptr_t const length) {
	for ( register intptr_t c = object->z ; 0 < c -- ; ) {
		register simd_double4 s = object->s[c];
		register simd_double3 z = (simd_double3 const) {s.x, s.y, 0};
		register simd_double2 w = (simd_double2 const) {s.z, s.w};
		register double const * __nonnull b = B;
		register double const * __nonnull a = A;
		register double const * __nonnull x = X + c * ldX;
		register double       * __nonnull y = Y + c * ldY;
		for ( register intptr_t k = 0, K = length ; k < K ; ++ k, ++ x, ++ y, ++ b, ++ a )
			w = (simd_double2 const) {
				*y = cardano_solver((simd_dot(z = (simd_double3 const) {*x, z.x, z.y}, (simd_double3 const) {b[0], b[ldB], b[2*ldB]}) - simd_dot(w, (simd_double2 const) {a[ldA], a[2*ldA]})), a[3*ldA], *a),
				w.x
			};
		object->s[c] = (simd_double4 const) {z.x, z.y, w.x, w.y};
	}
}
__attribute__((always_inline))
void duffing_filter_static(duffing_filter_t * __nonnull const object,
						   double const * __nonnull B, intptr_t const ldB,
						   double const * __nonnull A, intptr_t const ldA,
						   double const * __nonnull X, intptr_t const ldX,
						   double       * __nonnull Y, intptr_t const ldY,
						   intptr_t const length) {
	for ( register intptr_t c = object->z ; 0 < c -- ; ) {
		register simd_double4 s = object->s[c];
		register simd_double3 z = (simd_double3 const) {s.x, s.y, 0};
		register simd_double2 w = (simd_double2 const) {s.z, s.w};
		register double const * __nonnull b = B + c * ldB;
		register double const * __nonnull a = A + c * ldA;
		register double const * __nonnull x = X + c * ldX;
		register double       * __nonnull y = Y + c * ldY;
		for ( register intptr_t k = 0, K = length ; k < K ; ++ k, ++ x, ++ y )
			w = (simd_double2 const) {
				*y = cardano_solver((simd_dot(z = (simd_double3 const) {*x, z.x, z.y}, (simd_double3 const) {b[0], b[1], b[2]}) - simd_dot(w, (simd_double2 const) {a[1], a[2]})), a[3], a[0]),
				w.x
			};
		object->s[c] = (simd_double4 const) {z.x, z.y, w.x, w.y};
	}
}
