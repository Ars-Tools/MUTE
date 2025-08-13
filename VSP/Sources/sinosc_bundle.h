//
//  sinosc_bundle.h
//  MUTE
//
//  Created by Kota on 10/18/R6.
//
#include<stdint.h>
typedef struct {
	intptr_t const bundle;
	double * __nonnull const r[2];
	double * __nonnull const i[2];
} sinosc_bundle_t;
sinosc_bundle_t * __nonnull const sinosc_bundle_create(intptr_t const bundle);
void sinosc_bundle_destroy(sinosc_bundle_t * __nonnull const object);
void sinosc_bundle_execute(sinosc_bundle_t const * __nonnull const object,
						   double const * __nonnull const X, intptr_t const ldX, // real weight
						   double const * __nonnull const Y, intptr_t const ldY, // imag weight
						   double const * __nonnull const Z, intptr_t const ldZ, // freq phasor/sample
						   double * __nonnull const W, intptr_t const ldW,
						   intptr_t const cursor, // offset from zero
						   intptr_t const length);
