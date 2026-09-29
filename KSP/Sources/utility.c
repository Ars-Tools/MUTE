//
//  utility.c
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
#include"module.h"
#include"utility.h"
void utility_clear(intptr_t const n, intptr_t const c, double * __nullable y, intptr_t const s) {
	for ( double const * __nullable const _ = y + n * s ; y < _ ; y += s )
		__clr__(y, 1, c);
}
