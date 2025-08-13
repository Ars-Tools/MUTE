//
//  lookup.c
//  MUTE
//
//  Created by Kota on 10/17/R6.
//
#include<Accelerate/Accelerate.h>
#include<simd/simd.h>
#include"periodic_lookup.h"
// static table
void periodic_lookup_with_static(register double const * __nonnull const x,
								 register double const * __nonnull y,
								 register double       * __nonnull z,
								 register intptr_t const period,
								 register intptr_t const length) {
//	vDSP_vsmulD(y, 1, (double const[]){(double const)period}, z, 1, length);
	for ( register double const * const _ = z + length ; z < _ ; ++ z, ++ y ) {
		register double const r = modf(*y, z);
		register simd_long2 const q = ((((simd_long2 const){0, 1} + (long const)*z) % period + period) % period);
		*z = simd_mix(x[q.x], x[q.y], r);
	}
}
// active table provided via stream
void periodic_lookup_with_active(register double const * __nonnull x, intptr_t const ldx,
								 register double const * __nonnull const y,
								 register double       * __nonnull z,
								 register intptr_t const period,
								 register intptr_t const length) {
	vDSP_vsmulD(y, 1, (double const[]){(double const)period}, z, 1, length);
	for ( register double const * const _ = z + length ; z < _ ; ++ z, ++ x ) {
		register double const r = modf(*z, z);
		register simd_long2 const q = ((((simd_long2 const){0, 1} + (long const)*z) % period + period) % period) * ldx;
		*z = simd_mix(x[q.x], x[q.y], r);
	}
}
// like a delay
void periodic_lookup_with_offset(register double const * __nonnull const x,
								 register double const * __nonnull const y,
								 register double       * __nonnull z,
								 double const factor,
								 intptr_t const cursor, intptr_t const ground,
								 intptr_t const period,
								 intptr_t const length) {
	register simd_long2 const a = cursor + ground;
	register simd_long2 const b = cursor + ground + period;
	vDSP_vsmulD(y, 1, &factor, z, 1, length);
	for ( register long t = period + cursor, T = t + length ; t < T ; ++ t, ++ z ) {
		register double const r = modf(*z, z);
		register simd_long2 const q = simd_clamp((simd_long2 const){0, 1} + (t+(long const)*z), a, b) % period;
		*z = simd_mix(x[q.x], x[q.y], r);
	}
}
//void periodic_lookup_with_offset(double const * __nonnull const X, intptr_t const ldX, // table
//								 double const * __nonnull const Y, intptr_t const ldY, // index
//								 double       * __nonnull const Z, intptr_t const ldZ, // result
//								 double const factor, intptr_t const ground,
//								 register intptr_t const cursor,
//								 register intptr_t const period,
//								 register intptr_t const stream,
//								 register intptr_t const length) {
//	simd_long2 const a = cursor + ground;
//	simd_long2 const b = cursor + ground + period;
//	for ( register intptr_t c = stream ; 0 < c -- ; ) {
//		register double const * __nonnull const x = X + ldX * c;
//		register double const * __nonnull const y = Y + ldY * c;
//		register double       * __nonnull       z = Z + ldZ * c;
//		vDSP_vsmulD(y, 1, &factor, z, 1, length);
//		for ( register long t = period + cursor, T = t + length ; t < T ; ++ t, ++ z ) {
//			register double const r = modf(*z, z);
//			register simd_long2 const q = simd_clamp(simd_make_long2(0, 1) + (t+(long const)*z), a, b) % period;
//			*z = simd_mix(x[q.x], x[q.y], r);
//		}
//	}
//}
