//
//  sinosc_bundle.c
//  MUTE
//
//  Created by Kota on 10/18/R6.
//
#include"module.h"
#include"sinosc_bundle.h"
sinosc_bundle_t * __nonnull const sinosc_bundle_create(intptr_t const bundle) {
	void*__nonnull const p = __malloc__(sizeof(sinosc_bundle_t const) + sizeof(double const) * 4 * bundle);
	sinosc_bundle_t * const object = (sinosc_bundle_t*const)p;
	*(intptr_t*const)&object->bundle = bundle;
	*(double**const)(object->r + 0) = (double*const)(p + sizeof(sinosc_bundle_t const) + 0 * sizeof(double const) * bundle);
	*(double**const)(object->r + 1) = (double*const)(p + sizeof(sinosc_bundle_t const) + 1 * sizeof(double const) * bundle);
	*(double**const)(object->i + 0) = (double*const)(p + sizeof(sinosc_bundle_t const) + 2 * sizeof(double const) * bundle);
	*(double**const)(object->i + 1) = (double*const)(p + sizeof(sinosc_bundle_t const) + 3 * sizeof(double const) * bundle);
	return object;
}
void sinosc_bundle_destroy(sinosc_bundle_t * __nonnull const object) {
	__free__(object);
}
void sinosc_bundle_execute(sinosc_bundle_t const * __nonnull const object,
						   double const * __nonnull const X, intptr_t const ldX, // real weight
						   double const * __nonnull const Y, intptr_t const ldY, // imag weight
						   double const * __nonnull const Z, intptr_t const ldZ, // freq phasor/sample
						   double * __nonnull const W, intptr_t const ldW,
						   intptr_t const cursor, // offset from zero, elapsed time (sample)
						   intptr_t const length) {
	int const bundle = (int const)object->bundle;
	DSPDoubleSplitComplex const z[2] = {
		{.realp = object->r[0], .imagp = object->i[0]},
		{.realp = object->r[1], .imagp = object->i[1]}
	};
	vDSP_vsmulD(Z, ldZ, (double const[]){2}, z->realp, 1, bundle);
	vvsinpi(z[1].imagp, z[0].realp, &bundle);
	vvcospi(z[1].realp, z[0].realp, &bundle);
	vDSP_vsmulD(z->realp, 1, (double const[]){(double const)cursor}, z->realp, 1, bundle);
	vvsinpi(z[0].imagp, z[0].realp, &bundle);
	vvcospi(z[0].realp, z[0].realp, &bundle);
	for ( register double * __nonnull w = W, * __nonnull const _ = w + length ; w < _ ; ++ w ) {
		vDSP_vmmaD(z->realp, 1, X, ldX,
				   z->imagp, 1, Y, ldY,
				   w, ldW,
				   bundle);
		vDSP_zvmulD(z+0, 1, z+1, 1, z+0, 1, bundle, 0);
	}
}
