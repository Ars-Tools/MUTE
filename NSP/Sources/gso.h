//
//  gso.h
//  MUTE
//
//  Created by Kota on 8/21/R7.
//
// Gram-Schmidt orthonormalization filter with RLS O(p)
typedef struct {
	intptr_t const n;
	double lambda;
	double * __nonnull const D;
	double * __nonnull const A;
	double * __nonnull const U;
	double * __nonnull const S;
} gso_t;
gso_t * __nonnull const gso_create(intptr_t const count);
void gso_destroy(gso_t * __nonnull const);
void gso_reset(gso_t * __nonnull const, double const);
void gso_lambda(gso_t * __nonnull const, double const);
void gso_residual(gso_t * __nonnull const object,
				  register double const * __nonnull x, intptr_t const ldx,
				  register double       * __nonnull e, intptr_t const lde,
				  intptr_t const length);
void gso_weight(gso_t * __nonnull const object,
				register double const * __nonnull x, intptr_t const ldx,
				register double const * __nonnull s, intptr_t const lds,
				register double       * __nonnull t, intptr_t const ldt,
				intptr_t const length);
void gso_matrix(gso_t * __nonnull const object,
				register double const * __nonnull x, intptr_t const ldx,
				register double const * __nonnull s, intptr_t const lds,
				register double       * __nonnull t, intptr_t const ldt,
				intptr_t const length);
