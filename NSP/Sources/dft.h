//
//  dft.h
//  MUTE
//
//  Created by Kota on 8/28/R7.
//
#include<Accelerate/Accelerate.h>
//#ifdef DEBUG
intptr_t const pf(intptr_t value, intptr_t * __nonnull const prime);
intptr_t const pd(intptr_t value, intptr_t * __nonnull const prime);
//#endif
// MARK: DFS, fast setup, fair compute
typedef struct {
	__complex double * __nonnull const table;
	void * __nullable const prime;
	intptr_t const rows;
	intptr_t const cols;
} ddft_t;
__attribute__((overloadable))
ddft_t * __nonnull const ddft_create(intptr_t const count);
__attribute__((overloadable))
ddft_t * __nonnull const ddft_create(intptr_t const * __nonnull const count); // end with 1
void ddft_destroy(ddft_t * __nonnull const);
__attribute__((overloadable))
void ddft_forward(ddft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
__attribute__((overloadable))
void ddft_inverse(ddft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
// MARK: BFS, slow setup, fast compute
typedef struct {
    intptr_t const count;
    sparse_matrix_double_complex __nonnull prime[1];
} bdft_t;
__attribute__((overloadable))
bdft_t * __nonnull const bdft_create(intptr_t const count);
__attribute__((overloadable))
bdft_t * __nonnull const bdft_create(intptr_t const * __nonnull const count); // end with 1
void bdft_dump(bdft_t const * __nonnull const);
void bdft_destroy(bdft_t * __nonnull const);
__attribute__((overloadable))
void bdft_forward(bdft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
__attribute__((overloadable))
void bdft_inverse(bdft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
__attribute__((overloadable))
void bdft_forward(bdft_t const * __nonnull const object, intptr_t const n,
                  __complex double const * __nonnull const x, intptr_t const ldx,
                  __complex double       * __nonnull const y, intptr_t const ldy);
__attribute__((overloadable))
void bdft_inverse(bdft_t const * __nonnull const object, intptr_t const n,
                  __complex double const * __nonnull const x, intptr_t const ldx,
                  __complex double       * __nonnull const y, intptr_t const ldy);
// MARK: XFS
//typedef struct {
//    intptr_t const count;
//    sparse_matrix_double_complex __nonnull * __nonnull const prime;
//} xdft_t;
//__attribute__((overloadable))
//xdft_t * __nonnull const xdft_create(intptr_t const count);
//__attribute__((overloadable))
//xdft_t * __nonnull const xdft_create(intptr_t const * __nonnull const count);
//void xdft_dump(xdft_t const * __nonnull const object);
//void xdft_destroy(xdft_t * __nonnull const);
//void xdft_forward(xdft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
//void xdft_inverse(xdft_t const * __nonnull const, __complex double const * __nonnull const, __complex double * __nonnull const);
