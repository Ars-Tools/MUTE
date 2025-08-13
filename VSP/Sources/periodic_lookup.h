//
//  lookup.h
//  MUTE
//
//  Created by Kota on 10/17/R6.
//
#include<stdint.h>
void periodic_lookup_with_static(double const * __nonnull const x,
								 double const * __nonnull y,
								 double       * __nonnull z,
								 intptr_t const period,
								 intptr_t const length);
void periodic_lookup_with_active(double const * __nonnull x, intptr_t const ldx,
								 double const * __nonnull const y,
								 double       * __nonnull z,
								 intptr_t const period,
								 intptr_t const length);
void periodic_lookup_with_offset(double const * __nonnull const x,
								 double const * __nonnull const y,
								 double       * __nonnull z,
								 double const factor,
								 intptr_t const cursor, intptr_t const ground,
								 intptr_t const period,
								 intptr_t const length);
