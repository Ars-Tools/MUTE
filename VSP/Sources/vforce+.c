//
//  vforce+.c
//  MUTE
//
//  Created by Kota on 11/30/R6.
//
#include<simd/simd.h>
#include<Accelerate/Accelerate.h>
#include"vforce+.h"
__attribute__((always_inline))
void vvexp10(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = exp10(*x);
}
__attribute__((always_inline))
void vverf(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = erf(*x);
}
__attribute__((always_inline))
void vverfc(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = erfc(*x);
}
__attribute__((always_inline))
void vvlgamma(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = lgamma(*x);
}
__attribute__((always_inline))
void vvtgamma(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = tgamma(*x);
}
__attribute__((always_inline))
void vvj0(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = j0(*x);
}
__attribute__((always_inline))
void vvj1(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = j1(*x);
}
__attribute__((always_inline))
void vvjn(register double * __nonnull y, register double const * __nonnull x, register intptr_t * __nonnull n, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y, ++ n )
		*y = jn((int const)*n, *x);
}
__attribute__((always_inline))
void vsjn(register double * __nonnull y, register double const * __nonnull x, register intptr_t const n, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = jn((int const) n, *x);
}
__attribute__((always_inline))
void vvy0(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = y0(*x);
}
__attribute__((always_inline))
void vvy1(register double * __nonnull y, register double const * __nonnull x, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = y1(*x);
}
__attribute__((always_inline))
void vvyn(register double * __nonnull y, register double const * __nonnull x, register intptr_t * __nonnull n, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y, ++ n )
		*y = yn((int const)*n, *x);
}
__attribute__((always_inline))
void vsyn(register double * __nonnull y, register double const * __nonnull x, register intptr_t const n, intptr_t const length) {
	for ( register double * const __nonnull _ = y + length ; y < _ ; ++ x, ++ y )
		*y = yn((int const) n, *x);
}
__attribute__((always_inline))
double const i0(double const x) {
	register double const xh = 0.5 * x, xh2 = xh * xh;
	register double a = 1, t = 1;
	for ( register intptr_t m = 1 ; isnormal(t) ; ++ m )
		a += t *= xh2 / ( m * m );
	return a;
}
__attribute__((always_inline))
double const i1(double const x) {
	register double const xh = 0.5 * x, xh2 = xh * xh;
	register double a = xh, t = xh;
	for ( register intptr_t m = 1 ; isnormal(t) ; ++ m )
		a += t *= xh2 / ( m * m + m );
	return a;
}
// mod bessel func for integer α
double const in(register intptr_t const d, register double const x) {
	register double const xh = 0.5 * x, xh2 = xh * xh;
	register double t = 1;
	register intptr_t n = d < 0 ? ~d + 1 : d;
	for ( register intptr_t m = 1, k = m + n ; m < k ; ++ m )
		t *= xh / m;
	register double a = t;
	for ( register intptr_t m = 1, k = m + n ; isnormal(t) ; ++ m, ++ k )
		a += t *= xh2 / ( m * k );
	return a;
}
__attribute__((always_inline))
void vvi0(register double * __nonnull const y, register double const * __nonnull const x, intptr_t const length) {
	double * const p = (double*const)CFAllocatorAllocate(kCFAllocatorDefault, 2 * length * sizeof(double const), 0);
	double * const q = p + length, r;
	vDSP_vsmulD(x, 1, (double const[]){0.5}, q, 1, length);
	vDSP_vsqD(q, 1, q, 1, length);
	vDSP_vfillD((double const[]){1.0}, p, 1, length);
	vDSP_vfillD((double const[]){1.0}, y, 1, length);
	for ( register intptr_t m = 1 ; vDSP_maxvD(p, 1, &r, length), isnormal(r) ; ++ m ) {
		vDSP_vmulD(q, 1, p, 1, p, 1, length);
		vDSP_vsdivD(p, 1, (double const[]){m*m}, p, 1, length);
		vDSP_vaddD(p, 1, y, 1, y, 1, length);
	}
	CFAllocatorDeallocate(kCFAllocatorDefault, p);
}
__attribute__((always_inline))
void vvi1(register double * __nonnull const y, register double const * __nonnull const x, intptr_t const length) {
	double * const p = (double*const)CFAllocatorAllocate(kCFAllocatorDefault, 2 * length * sizeof(double const), 0);
	double * const q = p + length, r;
	vDSP_vsmulD(x, 1, (double const[]){0.5}, p, 1, length);
	vDSP_vsqD(p, 1, q, 1, length);
	memcpy(y, p, length * sizeof(double const));
	for ( register intptr_t m = 1 ; vDSP_maxvD(p, 1, &r, length), isnormal(r) ; ++ m ) {
		vDSP_vmulD(q, 1, p, 1, p, 1, length);
		vDSP_vsdivD(p, 1, (double const[]){fma(m, m, 1)}, p, 1, length);
		vDSP_vaddD(p, 1, y, 1, y, 1, length);
	}
	CFAllocatorDeallocate(kCFAllocatorDefault, p);
}
