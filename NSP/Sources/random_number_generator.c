//
//  random_number_generator.c
//  MUTE
//
//  Created by Kota on 11/8/R6.
//
#include<Accelerate/Accelerate.h>
#include<Security/Security.h>
#include<simd/simd.h>
#include"random_number_generator.h"
__attribute__((visibility("hidden")))
__attribute__((always_inline))
static inline void uniform_f64_in_1_2(double * __nonnull const y, intptr_t const length) { // generate uniform [1, 2)
	assert(sizeof(double const) == sizeof(uint64_t const));
	arc4random_buf(y, length * sizeof(double const));
	for ( register uint64_t * __nonnull u = (uint64_t*__nonnull)y, * __nonnull const U = u + length ; u < U ; ++ u )
		*u &= 0x000FFFFFFFFFFFFF, *u |= 0x3FF0000000000000;
}
// MARK: Uniform Distribution
void uniform_rng(double * __nonnull const r, intptr_t const ldr,
				 double const * __nonnull a, intptr_t const lda,
				 double const * __nonnull b, intptr_t const ldb,
				 intptr_t const number,
				 intptr_t const length) {
	for ( register double * __nonnull y = r, * __nonnull const Y = y + number * ldr ; y < Y ; y += ldr, a += lda, b += ldb ) {
		uniform_f64_in_1_2(y, length);
		vDSP_vsmsaD(y, 1, (double const[]){*a-*b}, (double const[]){fma(2,*b,-*a)}, y, 1, length);
	}
}
// MARK: Cauchy Distribution
void cauchy_rng(double * __nonnull const r, intptr_t const ldr,
				double const * __nonnull x, intptr_t const ldx,
				double const * __nonnull g, intptr_t const ldg,
				intptr_t const number,
				intptr_t const length) {
	for ( register double * __nonnull y = r, * __nonnull const Y = y + number * ldr ; y < Y ; y += ldr, x += ldx, g += ldg ) {
		uniform_f64_in_1_2(y, length);
		vDSP_vsaddD(y, 1, (double const[]){-1.5}, y, 1, length);
		vvtanpi(y, y, (int const[]){(int const)length});
		vDSP_vsmsaD(y, 1, g, x, y, 1, length);
	}
}
// MARK: Normal Distribution
__attribute__((visibility("hidden")))
__attribute__((always_inline))
static inline void erfinv_approx(double * __nonnull const y, double const * __nonnull const x, double * __nonnull const w, int const count) {
	static double const a = 8 * ( M_PI - 3 ) / ( 3 * M_PI ) / ( 4 - M_PI );
	register double * __nonnull const edx = w;
	register double * __nonnull const edy = w + count;
	assert(edx && edy);
	vDSP_vsqD(y, 1, edx, 1, count);
	vDSP_vsmsaD(edx, 1, (double const[]){-1.0}, (double const[]){ 1.0}, edx, 1, count);
	vvlog(edx, edx, &count);
	vDSP_vsdivD(edx, 1, &a, edy, 1, count);
	vDSP_vsmsaD(edx, 1, (double const[]){ 0.5}, (double const[]){ 2.0*M_1_PI/a}, edx, 1, count);
	vDSP_vmsbD(edx, 1, edx, 1, edy, 1, edy, 1, count);
	vvsqrt(edy, edy, &count);
	vDSP_vsubD(edx, 1, edy, 1, edx, 1, count);
	vvsqrt(edx, edx, &count);
	vvcopysign(y, edx, y, &count);
}
void gauss_rng(double * __nonnull const r, intptr_t const ldr,
			   double const * __nonnull u, intptr_t const ldu,
			   double const * __nonnull s, intptr_t const lds,
			   intptr_t const number,
			   intptr_t const length) {
	// erfinv requires twice of lenghth
//	register double * __nonnull const w = z ? z : alloca(2 * length * sizeof(double const));
	int const polar = (int const)(length / 2); // radius/radian border for polar -> cartesian conversion
	for ( register double * __nonnull y = r, * __nonnull const Y = y + number * ldr ; y < Y ; y += ldr, u += ldu, s += lds ) {
		uniform_f64_in_1_2(y, length);
		// erfinv, consumes extra memory
//		vDSP_vsmsaD(y, 1, (double const[]){ 2.0}, (double const[]){-3.0}, y, 1, length);
//		erfinv_approx(y, y, w, (int const)length);
		
		// for box-muller U[1, 2) -> U(0, 1]
		vDSP_vsmsaD(y, 1, (double const[]){-1.0}, (double const[]){ 2.0}, y, 1, length);
		// R
		vvlog(y, y, &polar);
		vDSP_vsmulD(y, 1, (double const[]){-2.0}, y, 1, polar);
		vvsqrt(y, y, &polar);
		// θ
		vDSP_vsmulD(y + polar, 1, (double const[]) { 2.0*M_PI}, y + polar, 1, polar);
		vDSP_vswapD(y + 1, 2, y + 2 * polar - 2, -2, polar / 2);
		// cartesian
		vDSP_rectD(y, 2, y, 2, polar);
		
		if (length&1) // odds
			y[length-1] = sqrt(-2*log(y[length-1]))*
				(((intptr_t const)y)&1?__cospi:__sinpi)(arc4random()**(double*const)(intptr_t const[]){0x3DE0000000000000});
		// scaling
		vDSP_vsmsaD(y, 1, s, u, y, 1, length);
	}
}
