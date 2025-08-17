//
//  lattice.h
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
#include<stdint.h>
// Forward
typedef struct {
	double * __nonnull const w;
	void * __nullable const r;
	intptr_t const c;
	intptr_t const n;
} lattice_filter_t;
lattice_filter_t * __nonnull const lattice_filter_create(intptr_t const order, intptr_t const count);
void lattice_filter_destroy(lattice_filter_t * __nonnull const object);
void lattice_filter_static(lattice_filter_t * __nonnull const object,
						   double const * __nonnull const P, intptr_t const ldP,
						   double const * __nonnull const X, intptr_t const ldX,
						   double       * __nonnull const Y, intptr_t const ldY,
						   intptr_t const length);
void lattice_filter_active(lattice_filter_t * __nonnull const object,
						   double const * __nonnull const P, intptr_t const ldP,
						   double const * __nonnull const X, intptr_t const ldX,
						   double       * __nonnull const Y, intptr_t const ldY,
						   intptr_t const length);
// MARK: LMS
typedef struct {
	double * __nonnull const p;
	intptr_t const n;
	// for working
	double * __nonnull const h;
	
} lattice_sgd_t;
lattice_sgd_t * __nonnull const lattice_sgd_create(intptr_t const order);
void lattice_sgd_destroy(lattice_sgd_t * __nonnull const object);
void lattice_sgd_reset(lattice_sgd_t * __nonnull const object);
void lattice_sgd_p(lattice_sgd_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull P, intptr_t const ldP,
				   double const mu,
				   intptr_t const length);
void lattice_sgd_e(lattice_sgd_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull E,
				   double const mu,
				   intptr_t const length);
// MARK: RLS
typedef struct {
	double * __nonnull const p;
	intptr_t const n;
	// for working
	double * __nonnull const _;
	double * __nonnull const h;
	double * __nonnull const s;
} lattice_rls_t;
lattice_rls_t * __nonnull const lattice_rls_create(intptr_t const order);
void lattice_rls_destroy(lattice_rls_t * __nonnull const object);
void lattice_rls_reset(lattice_rls_t * __nonnull const object);
void lattice_rls_p(lattice_rls_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull P, intptr_t const ldP,
				   double const lambda,
				   intptr_t const length);
void lattice_rls_e(lattice_rls_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull E,
				   double const lambda,
				   intptr_t const length);
