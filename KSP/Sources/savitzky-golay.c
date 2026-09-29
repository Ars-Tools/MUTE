//
//  savitzky-golay.c
//  MUTE
//
//  Created by Kota on 8/31/R7.
//
#include"module.h"
#include"savitzky-golay.h"
sg3_filter_t * __nonnull const sg3_filter_create(intptr_t const m);
void sg3_filter_destroy(sg3_filter_t * __nonnull const object);
void sg3_filter(sg3_filter_t * __nonnull const object,
				double const * const __nonnull x, intptr_t const ldx,
				double       * const __nonnull y, intptr_t const ldy,
				intptr_t const length) {
	
}
