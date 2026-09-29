//
//  edge.h
//  MUTE
//
//  Created by Kota on 11/14/R6.
//
#include<stdint.h>
#include<dispatch/dispatch.h>
void edge_rise(double const * __nonnull const X, intptr_t const ldX,
			   double       * __nonnull const Y, intptr_t const ldY,
			   bool         * __nonnull const S,
			   dispatch_source_t const __nullable notify, intptr_t const offset,
			   intptr_t const stream, intptr_t const length);
void edge_fall(double const * __nonnull const X, intptr_t const ldX,
			   double       * __nonnull const Y, intptr_t const ldY,
			   bool         * __nonnull const S,
			   dispatch_source_t const __nullable notify, intptr_t const offset,
			   intptr_t const stream, intptr_t const length);
void edge_hold(double const * __nonnull const X, intptr_t const ldX,
			   double const * __nonnull const Y, intptr_t const ldY,
			   double       * __nonnull const Z, intptr_t const ldZ,
			   double       * __nonnull const S,
			   intptr_t const stream, intptr_t const length);
