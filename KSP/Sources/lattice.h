//
//  lattice.h
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
#include<stdint.h>
// Wiener
__attribute__((always_inline, overloadable))
intptr_t const wiener(double const * __nonnull const,
                      double const * __nonnull const,
                      double       * __nonnull const,
                      double       * __nonnull const,
                      intptr_t const);
// Forward
typedef struct {
	double * __nonnull const w;
	void * __nullable const r; // reserved
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
void lattice_filter_jp_static(lattice_filter_t * __nonnull const object,
							  double const * __nonnull const P, intptr_t const ldP,
							  double const * __nonnull const K, intptr_t const ldK,
							  double const * __nonnull const X, intptr_t const ldX,
							  double       * __nonnull const Y, intptr_t const ldY,
							  intptr_t const length);
void lattice_filter_jp_active(lattice_filter_t * __nonnull const object,
							  double const * __nonnull const P, intptr_t const ldP,
							  double const * __nonnull const K, intptr_t const ldK,
							  double const * __nonnull const X, intptr_t const ldX,
							  double       * __nonnull const Y, intptr_t const ldY,
							  intptr_t const length);
// MARK: GAL
typedef struct {
	intptr_t const n;
	double * __nonnull const p;
	double * __nonnull const c;
	double * __nonnull const h;
	double mu;
} gal_t;
gal_t * __nonnull const gal_create(intptr_t const order);
void gal_destroy(gal_t * __nonnull const object);
void gal_reset(gal_t * __nonnull const object);
void gal_mu(gal_t * __nonnull const object, double const mu);
void gal_p(gal_t * __nonnull const object,
		   double const * __nonnull const y,
		   double       * __nonnull const p, intptr_t const ldp,
		   intptr_t const length);
void gal_r(gal_t * __nonnull const object,
		   double const * __nonnull const y,
		   double       * __nonnull const r,
		   intptr_t const length);
void gal_e(gal_t * __nonnull const object,
		   double const * __nonnull const y,
		   double const * __nonnull const d,
		   double       * __nonnull const e,
		   intptr_t const length);
// MARK: LSL
typedef struct {
	intptr_t const n;
	double * __nonnull const h;
	double * __nonnull const H;
	double * __nonnull const U;
	double * __nonnull const V;
	double lambda;
} lsl_t;
lsl_t * __nonnull const lsl_create(intptr_t const order);
void lsl_destroy(lsl_t*__nonnull const object);
void lsl_reset(lsl_t*__nonnull const object);
void lsl_lambda(lsl_t*__nonnull const object, double const lambda);
void lsl_p(lsl_t * __nonnull const object,
		   double const * __nonnull const y,
		   double       * __nonnull const p, intptr_t const ldp,
		   intptr_t const length);
void lsl_r(lsl_t * __nonnull const object,
		   double const * __nonnull const y,
		   double       * __nonnull const r,
		   intptr_t const length);
void lsl_e(lsl_t * __nonnull const object,
		   double const * __nonnull const y,
		   double const * __nonnull const d,
		   double       * __nonnull const e,
		   intptr_t const length);
