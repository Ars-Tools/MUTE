//
//  module.h
//  MUTE
//  BASICAL OPERATIONS, excepting BLAS/LAPACK
//  Created by Kota on 10/11/R6.
//
#include<Accelerate/Accelerate.h>
#include<simd/simd.h>
// memory management
__attribute__((always_inline)) static inline // allocate memory
void * __nonnull const __malloc__(size_t const size) {
	return CFAllocatorAllocate(kCFAllocatorDefault, size, 0);
}
__attribute__((always_inline)) static inline // free allocated memory
void __free__(void * __nonnull const memory) {
	CFAllocatorDeallocate(kCFAllocatorDefault, memory);
}
// vecLib
__attribute__((always_inline)) static inline // for each (0<=k<length), A[k*iA] = 0
void __clr__(double * __nonnull const A, intptr_t const iA, intptr_t const length) {
	vDSP_vclrD(A, iA, length);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), B[k*iA] = A
void __fill__(double const A, double * __nonnull const B, intptr_t const iB, intptr_t const length) {
	vDSP_vfillD(&A, B, iB, length);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), B[k*iA] = A
void __sort__(double const * __nonnull const A, double       * __nonnull const B, intptr_t const length) {
	memcpy(B, A, length * sizeof(double const));
	vDSP_vsortD(B, length, 1);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), B[k*iA] = A
void __ramp__(double const A, double const B, double * __nonnull const C, intptr_t const iC, intptr_t const length) {
	vDSP_vrampD(&A, &B, C, iC, length);
}
__attribute__((always_inline)) static inline // formaly matrix copy (row-major), copy [length] elements, [count] times
void __mcopy__(double const * __nonnull const A, intptr_t const ldA,
			   double *       __nonnull const B, intptr_t const ldB,
			   intptr_t const times, intptr_t const length) {
	vDSP_mmovD(A, B, length, times, ldA, ldB);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), D[k*iD] = A[k*iE] * B + C[k*iC]
void __vsm__(double const * __nonnull const A, intptr_t const iA,
			 double const B,
			 double       * __nonnull const C, intptr_t const iC,
			 intptr_t const length) {
	vDSP_vsmulD(A, iA, &B, C, iC, length);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), D[k*iD] = A[k*iE] * B + C[k*iC]
void __vsma__(double const * __nonnull const A, intptr_t const iA,
			  double const B,
			  double const * __nonnull const C, intptr_t const iC,
			  double       * __nonnull const D, intptr_t const iD,
			  intptr_t const length) {
	vDSP_vsmaD(A, iA, &B, C, iC, D, iD, length);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), C[k*iC] = A[k*iE] / B
void __vsdiv__(double const * __nonnull const A,
			   intptr_t const iA,
			   double const B,
			   double       * __nonnull const C,
			   intptr_t const iC,
			   intptr_t const length) {
	vDSP_vsdivD(A, iA, &B, C, iC, length);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), E[k*iE] = A[k*iE] * B + C[k*iC] * D
void __vsmsma__(double const * __nonnull const A, intptr_t const iA,
				double const B,
				double const * __nonnull const C, intptr_t const iC,
				double const D,
				double       * __nonnull const E, intptr_t const iE,
				intptr_t const length) {
	vDSP_vsmsmaD(A, iA, &B, C, iC, &D, E, iE, length);
}
__attribute__((always_inline)) static inline
double __sum__(double const * __nonnull const A,
			   intptr_t const iA,
			   intptr_t const length) {
	double r = 0;
	vDSP_sveD(A, iA, &r, length);
	return r;
}
// vForce
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = 1 / X[k]
void __rec__(double const * __nonnull const x,
			 double       * __nonnull const y,
			 intptr_t const length) {
	vvrec(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = log(X[k])
void __log__(double const * __nonnull const x,
			 double       * __nonnull const y,
			 intptr_t const length) {
	vvlog(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = exp(X[k])
void __exp__(double const * __nonnull const x,
			 double       * __nonnull const y,
			 intptr_t const length) {
	vvexp(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = cos(πX[k])
void __cospi__(double const * __nonnull const x,
			   double       * __nonnull const y,
			   intptr_t const length) {
	vvcospi(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = sin(πX[k])
void __sinpi__(double const * __nonnull const x,
			   double       * __nonnull const y,
			   intptr_t const length) {
	vvsinpi(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = tan(πX[k])
void __tanpi__(double const * __nonnull const x,
			   double       * __nonnull const y,
			   intptr_t const length) {
	vvtanpi(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = rsqrt(πX[k])
void __rsqrt__(double const * __nonnull const x,
			  double       * __nonnull const y,
			  intptr_t const length) {
	vvrsqrt(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = sqrt(πX[k])
void __sqrt__(double const * __nonnull const x,
			  double       * __nonnull const y,
			  intptr_t const length) {
	vvsqrt(y, x, (int const[]){(int const)length});
}
__attribute__((always_inline)) static inline // for each (0<=k<length), Y[k] = cbrt(πX[k])
void __cbrt__(double const * __nonnull const x,
			  double       * __nonnull const y,
			  intptr_t const length) {
	vvcbrt(y, x, (int const[]){(int const)length});
}
