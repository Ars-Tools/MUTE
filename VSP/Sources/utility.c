//
//  utility.c
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
#include<Accelerate/Accelerate.h>
void utility_clear(intptr_t const n, intptr_t const c, double * __nullable y, intptr_t const s) {
	for ( double const * __nullable const _ = y + n * s ; y < _ ; y += s )
		vDSP_vclrD(y, 1, c);
}
