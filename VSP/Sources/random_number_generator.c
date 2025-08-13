//
//  random_number_generator.c
//  MUTE
//
//  Created by Kota on 11/8/R6.
//
#include<Accelerate/Accelerate.h>
#include<Security/Security.h>
#include"random_number_generator.h"
void uniform_f64(double * __nonnull const r, intptr_t const ldr,
				 double const * __nonnull a, intptr_t const lda, // lo
				 double const * __nonnull b, intptr_t const ldb, // hi
				 intptr_t const number,
				 intptr_t const length) {
	assert(sizeof(double const) == sizeof(uint64_t const));
	for ( register uint64_t * __nonnull s = (uint64_t * __nonnull const)r, * __nonnull const t = s + number * ldr ; s < t ; s += ldr, a += lda, b += ldb ) {
//		SecRandomCopyBytes(kSecRandomDefault, length * sizeof(double const), s);
		arc4random_buf(s, length * sizeof(double const));
//		double const d = *a - *b;
//		double const c = fma(2, *b, -*a);
		for ( register uint64_t * __nonnull u = s, * __nonnull const v = u + length ; u < v ; ++ u ) {
			*u &= 0x000FFFFFFFFFFFFF;
			*u |= 0x3FF0000000000000;
		}
//			*(double*__nonnull const)u = fma(*(double*__nonnull const)u, d, c);
		vDSP_vsmsaD((double*__nonnull const)s, 1, (double const[]){*a-*b}, (double const[]){fma(2,*b,-*a)}, (double*__nonnull const)s, 1, length);
	}
}
