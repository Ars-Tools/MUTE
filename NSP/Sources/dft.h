//
//  dft.h
//  MUTE
//
//  Created by Kota on 8/28/R7.
//
#include<Accelerate/Accelerate.h>
#ifdef DEBUG
intptr_t const pf(intptr_t value, intptr_t * __nonnull const prime);
intptr_t const pd(intptr_t value, intptr_t * __nonnull const prime);
#endif
// MARK: Common
typedef vDSP_ENUM(uint8_t const) {
    DFT_SCALE_ONE,
    DFT_SCALE_ONE_OVER_N,
    DFT_SCALE_ONE_OVER_SQRT_N
} dft_scale_t;
// MARK: JIT, stateless
// prev version
//__attribute__((overloadable))
//void dft_forward(__complex double const * __nonnull const, intptr_t const,
//                 __complex double       * __nonnull const, intptr_t const,
//                 intptr_t const);
//__attribute__((overloadable))
//void dft_inverse(__complex double const * __nonnull const, intptr_t const,
//                 __complex double       * __nonnull const, intptr_t const,
//                 intptr_t const);
//__attribute__((overloadable))
//void dft_forward(__complex double const * __nonnull const, intptr_t const,
//                 __complex double       * __nonnull const, intptr_t const,
//                 intptr_t const, intptr_t const);
//__attribute__((overloadable))
//void dft_inverse(__complex double const * __nonnull const, intptr_t const,
//                 __complex double       * __nonnull const, intptr_t const,
//                 intptr_t const, intptr_t const);
__attribute__((overloadable))
void dft_forward(intptr_t const,
                 __complex double const * __nonnull const,
                 __complex double       * __nonnull const,
                 __complex double       * __nullable const);
__attribute__((overloadable))
void dft_inverse(intptr_t const,
                 __complex double const * __nonnull const,
                 __complex double       * __nonnull const,
                 __complex double       * __nullable const);
__attribute__((overloadable))
void dft_forward(intptr_t const,
                 __complex double const * __nonnull const, intptr_t const,
                 __complex double       * __nonnull const, intptr_t const,
                 __complex double       * __nullable const);
__attribute__((overloadable))
void dft_inverse(intptr_t const,
                 __complex double const * __nonnull const, intptr_t const,
                 __complex double       * __nonnull const, intptr_t const,
                 __complex double       * __nullable const);
__attribute__((overloadable))
void dft_forward(intptr_t const, intptr_t const,
                 __complex double const * __nonnull const, intptr_t const,
                 __complex double       * __nonnull const, intptr_t const,
                 __complex double       * __nullable const);
__attribute__((overloadable))
void dft_inverse(intptr_t const, intptr_t const,
                 __complex double const * __nonnull const, intptr_t const,
                 __complex double       * __nonnull const, intptr_t const,
                 __complex double       * __nullable const);
#if 0 // prev ddft_t
typedef __attribute__((__swift_attr__("BitwiseCopyable"), __swift_attr__("Sendable"))) struct {
	intptr_t const rows;
	intptr_t const cols;
    void * __nullable const prime;
    __complex double * __nonnull const table;
} ddft_t;
__attribute__((overloadable))
ddft_t * __nonnull const ddft_create(intptr_t const count);
__attribute__((overloadable))
ddft_t * __nonnull const ddft_create(intptr_t const * __nonnull const count); // end with 1
void ddft_destroy(ddft_t const * __nonnull const);
__attribute__((overloadable))
void dft_destroy(ddft_t const * __nonnull const);
__attribute__((overloadable))
void dft_forward(ddft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const workspace);
__attribute__((overloadable))
void ddft_forward(ddft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
__attribute__((overloadable))
void ddft_inverse(ddft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
#endif
// MARK: DFS - higher performance when the length can be devided by large 2ⁿ
typedef __attribute__((__swift_attr__("BitwiseCopyable"), __swift_attr__("Sendable"))) struct {
    intptr_t count;
    intptr_t log2n;
    union { // core dft
        FFTSetupD __nullable setup;
        __complex double * __nullable dense;
    };
    intptr_t prime[1];
} ddft_t;
__attribute__((overloadable))
ddft_t const * __nonnull const ddft_create(intptr_t const * __nonnull const);
__attribute__((overloadable))
ddft_t const * __nonnull const ddft_create(intptr_t const);
__attribute__((overloadable))
void dft_destroy(ddft_t const * __nonnull const);
__attribute__((always_inline, overloadable)) static inline
intptr_t const dft_count(ddft_t const * __nonnull const object) {
    return object->prime[0];
}
__attribute__((overloadable))
void dft_dump(ddft_t const * __nonnull const);
__attribute__((always_inline, overloadable))
void dft_forward(ddft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const,
                 __complex double       * __nonnull const,
                 __complex double       * __nullable);
__attribute__((always_inline, overloadable))
void dft_inverse(ddft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable);
__attribute__((always_inline, overloadable))
void dft_forward(ddft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const, intptr_t const,
                 __complex double       * __nonnull const, intptr_t const,
                 __complex double       * __nullable);
__attribute__((always_inline, overloadable))
void dft_inverse(ddft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x, intptr_t const,
                 __complex double       * __nonnull const y, intptr_t const,
                 __complex double       * __nullable);
__attribute__((always_inline, overloadable))
void dft_forward(ddft_t const * __nonnull const, dft_scale_t const, intptr_t const,
                 __complex double const * __nonnull const, intptr_t const,
                 __complex double       * __nonnull const, intptr_t const,
                 __complex double       * __nullable);
__attribute__((always_inline, overloadable))
void dft_inverse(ddft_t const * __nonnull const, dft_scale_t const, intptr_t const,
                 __complex double const * __nonnull const x, intptr_t const,
                 __complex double       * __nonnull const y, intptr_t const,
                 __complex double       * __nullable);
// MARK: BFS, better performance for non 2ⁿ length, slow setup to optimize (sparse_commit) larger N
typedef __attribute__((__swift_attr__("BitwiseCopyable"), __swift_attr__("Sendable"))) struct {
    intptr_t const count;
    sparse_matrix_double_complex __nonnull const prime[1];
} bdft_t;
__attribute__((always_inline, overloadable))
bdft_t const * __nonnull const bdft_create(intptr_t const count);
__attribute__((always_inline, overloadable))
bdft_t const * __nonnull const bdft_create(intptr_t const * __nonnull const count); // end with 1
__attribute__((always_inline, overloadable)) static inline
intptr_t const dft_count(bdft_t const * __nonnull const object) {
    return sparse_get_matrix_number_of_rows(object->prime[0]);
}
__attribute__((always_inline, overloadable))
void dft_dump(bdft_t const * __nonnull const);
__attribute__((always_inline, overloadable))
void dft_destroy(bdft_t const * __nonnull const);
__attribute__((always_inline, overloadable))
void dft_forward(bdft_t const * __nonnull const, dft_scale_t const,
                  __complex double const * __nonnull const x,
                  __complex double       * __nonnull const y,
                  __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_inverse(bdft_t const * __nonnull const, dft_scale_t const,
                  __complex double const * __nonnull const x,
                  __complex double       * __nonnull const y,
                  __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_forward(bdft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_inverse(bdft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_forward(bdft_t const * __nonnull const, dft_scale_t const, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_inverse(bdft_t const * __nonnull const, dft_scale_t const, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const workspace);
// MARK: PWT
typedef __attribute__((__swift_attr__("BitwiseCopyable"), __swift_attr__("Sendable"))) struct {
    FFTSetupD __nonnull setup;
    intptr_t log2n;
} pdft_t;
pdft_t const * __nullable const pdft_create(intptr_t const log2n);
__attribute__((always_inline, overloadable))
intptr_t const dft_count(pdft_t const * __nonnull const);
__attribute__((always_inline, overloadable))
void dft_destroy(pdft_t const * __nonnull const);
__attribute__((always_inline, overloadable))
void dft_forward(pdft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_inverse(pdft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_forward(pdft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_inverse(pdft_t const * __nonnull const, dft_scale_t const,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_forward(pdft_t const * __nonnull const, dft_scale_t const, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const workspace);
__attribute__((always_inline, overloadable))
void dft_inverse(pdft_t const * __nonnull const, dft_scale_t const, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const workspace);
