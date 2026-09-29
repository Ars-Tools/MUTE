//
//  state_variable_filter.c
//  MUTE
//
//  Created by Kota on 11/23/R6.
//
#include"module.h"
#include"state_variable_filter.h"
void state_variable_filter(register double const * __nonnull x,
						   register double       * __nonnull y, intptr_t const ldy,
						   register double const u, // 2sin(omega)
						   register double const v, // 1/quality
						   simd_double3 * __nonnull const s, // state
						   intptr_t const length) {
	register simd_double3 z = *s; // {lpf, bpf, hpf}
	register double * __nonnull l = y + 0 * ldy;
	register double * __nonnull b = y + 1 * ldy;
	register double * __nonnull h = y + 2 * ldy;
	for ( register double const * __nonnull const _ = x + length ; x < _ ; ++ x, ++ l, ++ b, ++ h )
		z.x = *l = fma(u, z.y = *b = fma(u, z.z = *h = *x - fma(v, z.y, z.x), z.y), z.x);
	*s = z;
}
void state_variable_filter_static2(register double const * __nonnull x,
								  register double * const __nonnull y, intptr_t const ldy,
								  double const p, // phase
								  double const q, // quality
								  simd_double2 * __nonnull const s, // state
								  intptr_t const length) {
	register simd_double3 z;
	register double * __nonnull lpf = y + 0 * ldy;
	register double * __nonnull bpf = y + 1 * ldy;
	register double * __nonnull hpf = y + 2 * ldy;
	double const w = 2 * tanpi(p);
	double const a = w / q;
	double const b = w * q;
	double const c1 = ( a + b ) / (1 + a / 2 + b / 4);
	double const c2 = 1 / fma(q, q, 1);
	simd_double3 const dl = {1 - c1 / 2 + c1 * c2 / 4, 0, 0};
	simd_double3 const db = {( 1 - c2 ) * c1 / 2, 1 - c2, 0};
	simd_double3 const dh = {c1 * c2 / 4, c2, 1};
	for ( register double const * __nonnull const _ = x + length ; x < _ ; ++ x, ++ lpf, ++ bpf, ++ hpf ) {
		z.x = *x - z.y - z.z;
		*hpf = simd_dot(dh, z);
		*bpf = simd_dot(db, z);
		z.z = fma(c2, z.y, z.z);
		*lpf = simd_dot(dl, z);
		z.y = fma(c1, z.x, z.y);
	}
}
void state_variable_filter_static(register double const * __nonnull x,
								  register double * const __nonnull y, intptr_t const ldy,
								  double const p, // normalized angular freq, [0, 0.5)
								  double const q, // quality
								  simd_double2 * __nonnull const s, // state
								  intptr_t const length) {
	register simd_double2 z = *s;
	register double * __nonnull l = y + 0 * ldy;
	register double * __nonnull b = y + 1 * ldy;
	register double * __nonnull h = y + 2 * ldy;
	register double const u = tanpi(p);
	register double const v = 1 / q + u;
	register double const w = fma(u, v, 1);
	for ( register double const * __nonnull const _ = x + length ; x < _ ; ++ x, ++ l, ++ b, ++ h ) {
		*h = fma(v, - z.y, *x - z.x) / w;
		z.y = fma(u, *h, *b = fma(u, *h, z.y));
		z.x = fma(u, *b, *l = fma(u, *b, z.x));
	}
	__vsdiv__(y + ldy, 1, q, y + ldy, 1, length); // udp
	*s = z;
}
void state_variable_filter_active(register double const * __nonnull x,
								  register double * const __nonnull y, intptr_t const ldy,
								  register double const * __nonnull p, // normalized angular freq, [0, 0.5)
								  register double const * __nonnull q, // quality
								  simd_double2 * __nonnull const s, // state
								  intptr_t const length) {
	register simd_double2 z = *s;
	register double * __nonnull l = y + 0 * ldy;
	register double * __nonnull b = y + 1 * ldy;
	register double * __nonnull h = y + 2 * ldy;
	__tanpi__(p, b, length);
	__rec__(q, h, length);
	for ( register double const * __nonnull const _ = x + length ; x < _ ; ++ x, ++ l, ++ b, ++ h ) {
		register double const u = *b;
		register double const w = *h;
		register double const v = w + u;
		*h = fma(v, - z.y, *x - z.x) / fma(u, v, 1);
		z.y = fma(u, *h, *b = fma(u, *h, z.y));
		z.x = fma(u, *b, *l = fma(u, *b, z.x));
		*b *= w;
	}
	*s = z;
}

