//
//  mix.c
//  MUTE
//
//  Created by Kota on 10/15/25.
//
#include<simd/simd.h>
#include"mix.h"
void mix_linear(register double const * __nonnull x,
                register double const * __nonnull y,
                register double const * __nonnull z,
                register double       * __nonnull w,
                intptr_t const length) {
    for ( register double * __nonnull W = w + length ; w < W ; ++ x, ++ y, ++ z, ++ w )
        *w = simd_mix(*x, *y, *z);
}
