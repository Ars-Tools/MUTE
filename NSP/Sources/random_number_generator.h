//
//  random_number_generator.h
//  MUTE
//
//  Created by Kota on 11/8/R6.
//
#include<stdint.h>
__attribute__((overloadable))
void uniform_rng(double * __nonnull const r, intptr_t const ldr,
				 double const * __nonnull a, intptr_t const lda,
				 double const * __nonnull b, intptr_t const ldb,
				 intptr_t const number,
				 intptr_t const length);
__attribute__((overloadable)) static inline
void uniform_rng(double * __nonnull const r, intptr_t const ldr,
                 double const a,
                 double const b,
                 intptr_t const number,
                 intptr_t const length) {
    uniform_rng(r, ldr, &a, 0, &b, 0, number, length);
}
__attribute__((overloadable))
void cauchy_rng(double * __nonnull const r, intptr_t const ldr,
				double const * __nonnull x, intptr_t const ldx,
				double const * __nonnull g, intptr_t const ldg,
				intptr_t const number,
				intptr_t const length);
__attribute__((overloadable)) static inline
void rng_cauchy(double * __nonnull const r, intptr_t const ldr,
                double const x,
                double const g,
                intptr_t const number,
                intptr_t const length) {
    cauchy_rng(r, ldr, &x, 0, &g, 0, number, length);
}
void gauss_rng(double * __nonnull const r, intptr_t const ldr,
			   double const * __nonnull u, intptr_t const ldu,
			   double const * __nonnull s, intptr_t const lds,
			   intptr_t const number,
			   intptr_t const length);
__attribute__((overloadable))
void rng_gauss(double * __nonnull const r, intptr_t const ldr,
               double const * __nonnull u, intptr_t const ldu,
               double const * __nonnull s, intptr_t const lds,
               intptr_t const number,
               intptr_t const length);
__attribute__((overloadable)) static inline
void rng_gauss(double * __nonnull const r, intptr_t const ldr,
               double const u,
               double const s,
               intptr_t const number,
               intptr_t const length) {
    rng_gauss(r, ldr, &u, 0, &s, 0, number, length);
}
