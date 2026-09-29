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
void __free__(void const * __nonnull const memory) {
	CFAllocatorDeallocate(kCFAllocatorDefault, (void*const)memory);
}
__attribute__((always_inline)) static inline
bool __with_memory__(size_t const size, void(__attribute__((noescape))^__nonnull const body)(void*__nonnull const)) {
    void * __nullable memory = __malloc__(size);
    if ( memory ) {
        body(memory);
        __free__(memory);
    }
    return!memory;
//
//    void * __nullable memory = alloca(size);
//    if ( memory )
//        body(memory);
//    else if ( ( memory = __malloc__(size) ) ) {
//        body(memory);
//        __free__(memory);
//    }
//    return!memory;
}
// vecLib
__attribute__((always_inline, overloadable)) static inline // for each (0<=k<length), A[k*iA] = 0
void __clr__(double * __nonnull const A, intptr_t const iA, intptr_t const length) {
	vDSP_vclrD(A, iA, length);
}
__attribute__((always_inline, overloadable)) static inline // for each (0<=k<length), A[k*iA] = 0
void __clr__(__complex double * __nonnull const A, intptr_t const iA, intptr_t const length) {
    vDSP_vclrD(((double*__nonnull const)A)+0, 2*iA, length);
    vDSP_vclrD(((double*__nonnull const)A)+1, 2*iA, length);
}
__attribute__((always_inline, overloadable)) static inline // for each (0<=k<length), B[k*iB] = A
void __fill__(double const A, double * __nonnull const B, intptr_t const iB, intptr_t const length) {
	vDSP_vfillD(&A, B, iB, length);
}
__attribute__((always_inline, overloadable)) static inline // for each (0<=k<length), B[k*iB] = A
void __fill__(__complex double const A, __complex double * __nonnull const B, intptr_t const iB, intptr_t const length) {
    vDSP_vfillD(&__real(A), ((double*__nonnull const)B)+0, 2*iB, length);
    vDSP_vfillD(&__imag(A), ((double*__nonnull const)B)+1, 2*iB, length);
}
__attribute__((always_inline, overloadable)) static inline // for each (0<=k<length), B[k*iB] = A[k*iA]
void __copy__(double const * __nonnull const A, intptr_t const iA,
              double       * __nonnull const B, intptr_t const iB,
              intptr_t const length) {
    dcopy_(&length, A, &iA, B, &iB);
}
__attribute__((always_inline, overloadable)) static inline // for each (0<=k<length), B[k*iB] = A[k*iA]
void __copy__(__complex double const * __nonnull const A, intptr_t const iA,
              __complex double       * __nonnull const B, intptr_t const iB,
              intptr_t const length) {
    zcopy_(&length, A, &iA, B, &iB);
}
__attribute__((always_inline, overloadable)) static inline // for each (0<=k<length), B[k*iB] = A[k*iA]
void __conj__(__complex double const * __nonnull const A, intptr_t const iA,
              __complex double       * __nonnull const B, intptr_t const iB,
              intptr_t const length) {
    vDSP_zvconjD(&(DSPDoubleSplitComplex const) {
        .realp = &__real(*A),
        .imagp = &__imag(*A),
    }, 2 * iA, &(DSPDoubleSplitComplex const) {
        .realp = &__real(*B),
        .imagp = &__imag(*B),
    }, 2 * iB, length);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), B[k*iB] = A
void __sort__(double const * __nonnull const A, double       * __nonnull const B, intptr_t const length) {
	memcpy(B, A, length * sizeof(double const));
	vDSP_vsortD(B, length, 1);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), B[k*iA] = A
void __ramp__(double const A, double const B, double * __nonnull const C, intptr_t const iC, intptr_t const length) {
	vDSP_vrampD(&A, &B, C, iC, length);
}
__attribute__((always_inline, overloadable)) static inline // formaly matrix copy (row-major), copy [length] elements, [count] times
void __mcopy__(double const * __nonnull const A, intptr_t const ldA,
			   double       * __nonnull const B, intptr_t const ldB,
			   intptr_t const times, intptr_t const length) {
	vDSP_mmovD(A, B, length, times, ldA, ldB);
}
__attribute__((always_inline, overloadable)) static inline // formaly matrix copy (row-major), copy [length] elements, [count] times
void __mcopy__(__complex double const * __nonnull const A, intptr_t const ldA,
               __complex double       * __nonnull const B, intptr_t const ldB,
               intptr_t const times, intptr_t const length) {
    vDSP_mmovD(A, B, 2 * length, times, 2 * ldA, 2 * ldB);
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
__attribute__((always_inline)) static inline // for each (0<=k<length), D[k*iD] = A[k*iA] * B + C
void __vsmsa__(double const * __nonnull const A, intptr_t const iA,
               double const B,
               double const C,
               double       * __nonnull const D, intptr_t const iD,
               intptr_t const length) {
    vDSP_vsmsaD(A, iA, &B, &C, D, iD, length);
}
__attribute__((always_inline)) static inline // for each (0<=k<length), E[k*iE] = A[k*iA] * B + C[k*iC] * D
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
// simd
__attribute__((always_inline, __overloadable__)) static inline
simd_double2x2 simd_outer(simd_double2 const x, simd_double2 const y) {
    return (simd_double2x2 const) {
        .columns = {
            y.x * x,
            y.y * x
        }
    };
}
__attribute__((always_inline, __overloadable__)) static inline
simd_double3x3 simd_outer(simd_double3 const x, simd_double3 const y) {
    return (simd_double3x3 const) {
        .columns = {
            y.x * x,
            y.y * x,
            y.z * x
        }
    };
}
__attribute__((always_inline, __overloadable__)) static inline
simd_double4x4 simd_outer(simd_double4 const x, simd_double4 const y) {
    return (simd_double4x4 const) {
        .columns = {
            y.x * x,
            y.y * x,
            y.z * x,
            y.w * x
        }
    };
}
__attribute__((always_inline, __overloadable__)) static inline
simd_double2x2 simd_div(simd_double2x2 const x, double const y) {
    return (simd_double2x2 const) {
        .columns = {
            x.columns[0] / y,
            x.columns[1] / y,
        }
    };
}
__attribute__((always_inline, __overloadable__)) static inline
simd_double3x3 simd_div(simd_double3x3 const x, double const y) {
    return (simd_double3x3 const) {
        .columns = {
            x.columns[0] / y,
            x.columns[1] / y,
            x.columns[2] / y,
        }
    };
}
__attribute__((always_inline, __overloadable__)) static inline
simd_double4x4 simd_div(simd_double4x4 const x, double const y) {
    return (simd_double4x4 const) {
        .columns = {
            x.columns[0] / y,
            x.columns[1] / y,
            x.columns[2] / y,
            x.columns[3] / y,
        }
    };
}
