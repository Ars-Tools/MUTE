//
//  slerp.h
//  MUTE
//
//  Created by Kota on 9/2/R7.
//
#include<simd/simd.h>
__attribute__((overloadable))
void slerp_shortest(simd_quatd const q0, simd_quatd const q1,
					double const*__nonnull const x,
					double      *__nonnull const Y, intptr_t const ldY,
					intptr_t const length);
__attribute__((overloadable))
void slerp_longest(simd_quatd const q0, simd_quatd const q1,
				   double const*__nonnull const x,
				   double      *__nonnull const Y, intptr_t const ldY,
				   intptr_t const length);
