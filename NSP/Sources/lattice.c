//
//  lattice.c
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
#include<CoreFoundation/CoreFoundation.h>
#include<Accelerate/Accelerate.h>
#include<simd/simd.h>
#include"lattice.h"
// MARK: process
__attribute__((always_inline))
lattice_filter_t * __nonnull const lattice_filter_create(intptr_t const order, intptr_t const count) {
	void * const p = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(lattice_filter_t const) + count * ( order + 1 ) * sizeof(double const), 0);
	lattice_filter_t * const object = (lattice_filter_t * const)p;
	*(double**const)&object->w = (double*const)(p + sizeof(lattice_filter_t const));
	*(void**const)&object->r = nil;
	*(intptr_t*const)&object->c = count;
	*(intptr_t*const)&object->n = order;
	return object;
}
__attribute__((always_inline))
void lattice_filter_destroy(lattice_filter_t * __nonnull const object) {
	CFAllocatorDeallocate(kCFAllocatorDefault, object);
}
__attribute__((always_inline))
void lattice_filter_static(lattice_filter_t * __nonnull const object,
						   double const * __nonnull const P, intptr_t const ldP, // PARCOR
						   double const * __nonnull const X, intptr_t const ldX,
						   double       * __nonnull const Y, intptr_t const ldY,
						   intptr_t const length) {
	register intptr_t const N = object->n;
	register double * __nonnull const r = object->w;
	for ( register intptr_t c = object->c ; 0 < c -- ;  ) {
		register double const * __nonnull p = P + c * ldP;
		register double const * __nonnull x = X + c * ldX;
		register double       * __nonnull y = Y + c * ldY;
		for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ x, ++ y ) {
			register double f = *x;
			for ( register intptr_t n = 0 ; n < N ; ++ n )
				r[n] = fma(f = fma(-p[n], r[n+1], f), p[n], r[n+1]);
			*y = r[N] = f;
		}
	}
}
__attribute__((always_inline))
void lattice_filter_active(lattice_filter_t * __nonnull const object,
						   double const * __nonnull const P, intptr_t const ldP, // PARCOR
						   double const * __nonnull const X, intptr_t const ldX,
						   double       * __nonnull const Y, intptr_t const ldY,
						   intptr_t const length) {
	register intptr_t const N = object->n;
	register double * __nonnull const r = object->w;
	for ( register intptr_t c = object->c ; 0 < c -- ;  ) {
		register double const * __nonnull p = P;
		register double const * __nonnull x = X + c * ldX;
		register double       * __nonnull y = Y + c * ldY;
		for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ x, ++ y, ++ p ) {
			register double f = *x;
			for ( register intptr_t n = 0 ; n < N ; ++ n )
				r[n] = fma(f = fma(-p[n*ldP], r[n+1], f), p[n*ldP], r[n+1]);
			*y = r[N] = f;
		}
	}
}
// MARK: LMS
__attribute__((always_inline))
lattice_sgd_t * __nonnull const lattice_sgd_create(intptr_t const order) {
	void * const p = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(lattice_sgd_t const) + 2 * order * sizeof(double const), 0);
	lattice_sgd_t * const object = (lattice_sgd_t * const)p;
	*(double**const)&object->p = (double*const)(p + sizeof(lattice_sgd_t const) + 0 * order * sizeof(double const));
	*(double**const)&object->h = (double*const)(p + sizeof(lattice_sgd_t const) + 1 * order * sizeof(double const));
	*(intptr_t*const)&object->n = order;
	lattice_sgd_reset(object);
	return object;
}
__attribute__((always_inline))
void lattice_sgd_destroy(lattice_sgd_t * __nonnull const object) {
	CFAllocatorDeallocate(kCFAllocatorDefault, object);
}
__attribute__((always_inline))
void lattice_sgd_reset(lattice_sgd_t * __nonnull const object) {
	vDSP_vclrD(object->p, 1, 2 * object->n);
}
__attribute__((always_inline))
void lattice_sgd(lattice_sgd_t * __nonnull const object,
				 double const * __nonnull Y,
				 double const mu,
				 intptr_t const length,
				 void(^notify)(intptr_t const, double const*__nonnull const, double const, double const)) {
	register double * __nonnull const p = object->p;
	register double * __nonnull const h = object->h;
	register intptr_t const N = object->n;
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y ) {
		register double r = *Y, f = r;
		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
			register simd_double2 const v = fma(p[n], simd_make_double2(h[n], f), simd_make_double2(f, h[n]));
			p[n] = fma(-mu, simd_dot(v, simd_make_double2(h[n], f)), p[n]);
			h[n] = r;
			f = v.x;
			r = v.y;
		}
		notify(t, p, f, r);
	}
}
__attribute__((always_inline))
void lattice_sgd_p(lattice_sgd_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull P, intptr_t const ldP,
				   double const mu,
				   intptr_t const length) {
	static const double _ = 0;
	register intptr_t const N = object->n;
	lattice_sgd(object, Y, mu, length, ^(intptr_t const t, double const*__nonnull const p, double const f, double const r) {
		vDSP_viclipD(p, 1, &_, &_, P + t + ( N - 1 ) * ldP, -ldP, N);
	});
}
void lattice_sgd_e(lattice_sgd_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull E,
				   double const mu,
				   intptr_t const length) {
	lattice_sgd(object, Y, mu, length, ^(intptr_t const t, double const*__nonnull const p, double const f, double const r) {
		E[t] = f;
	});
}
// MARK: RLS
__attribute__((always_inline))
lattice_rls_t * __nonnull const lattice_rls_create(intptr_t const order) {
	void * const p = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(lattice_rls_t const) + 4 * ( order + 1 ) * sizeof(double const), 0);
	lattice_rls_t * const object = (lattice_rls_t * const)p;
	*(intptr_t*const)&object->n = order;
	*(double**const)&object->p = (double*const)(p + sizeof(lattice_rls_t const) + 0 * ( order + 1 ) * sizeof(double const));
	*(double**const)&object->_ = (double*const)(p + sizeof(lattice_rls_t const) + 1 * ( order + 1 ) * sizeof(double const));
	*(double**const)&object->h = (double*const)(p + sizeof(lattice_rls_t const) + 2 * ( order + 1 ) * sizeof(double const));
	*(double**const)&object->s = (double*const)(p + sizeof(lattice_rls_t const) + 3 * ( order + 1 ) * sizeof(double const));
	lattice_rls_reset(object);
	return object;
}
__attribute__((always_inline))
void lattice_rls_destroy(lattice_rls_t * __nonnull const object) {
	CFAllocatorDeallocate(kCFAllocatorDefault, object);
}
__attribute__((always_inline)) // assume E[|x|^2] = 1
void lattice_rls_reset(lattice_rls_t * __nonnull const object) {
	vDSP_vclrD(object->p, 1, object->n+1);
	vDSP_vfillD((double const[]){0}, object->s, 1, object->n + 1);
	vDSP_vfillD((double const[]){M_SQRT1_2}, object->h, 1, object->n + 1);
	vDSP_vfillD((double const[]){M_SQRT1_2}, object->_, 1, object->n + 1);
}
__attribute__((always_inline))
void lattice_rls(lattice_rls_t * __nonnull const object,
				 double const * __nonnull Y, double const lambda,
				 double const * __nonnull Z, intptr_t const ldZ,
				 intptr_t const length,
				 void(^notify)(intptr_t const t, double const*__nonnull const p, double const f, double const r)) {
	register intptr_t const N = object->n;
	register double * __nonnull const _ = object->_; // [F0, Δ]
	register double * __nonnull const h = object->h; // R_{t-1}[n]
	register double * __nonnull const s = object->s; // r_{t-1}[n]
	register double * __nonnull const p = object->p; // PARCOR and working memory
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, Z += ldZ ) {
		register double f, r, F, R;
		r = f = *Y;
		if ( *Z < ( R = F = *_ = simd_dot((simd_double2 const) {lambda, f}, (simd_double2 const) {*_, r}) )) {
			p[0] = 1;
			for ( register intptr_t n = 0 ; n < N ; ++ n ) {
				register double const
					Q = h[n],
					q = s[n],
					D = _[n+1] = fma(lambda, _[n+1], f * q / p[n]),
					b = -D / F,
					a = -D / Q;
				h[n] = R;
				s[n] = r;
				R = Q - D * D / F;
				F = F - D * D / Q;
				r = fma(b, f, q);
				f = fma(a, q, f);
				p[n+1] = p[n] - q * q / Q;
				p[n] = a;
			}
		}
		notify(t, p, f, r);
	}
}
__attribute__((always_inline)) // normalized algorithm optimised for fixed-point-number processor
void lattice_rls_n(lattice_rls_t * __nonnull const object,
				   double const * __nonnull Y, double const lambda,
				   double const * __nonnull Z, intptr_t const ldZ,
				   intptr_t const length,
				   void(^notify)(intptr_t const t, double const*__nonnull const p, double const f, double const r)) {
	register intptr_t const N = object->n;
	register double * __nonnull const p = object->p; // PARCOR
	register double * __nonnull const _ = object->_; // [F0,]
	register double * __nonnull const h = object->h; // r[t-1,:]
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, Z += ldZ ) {
		register double const y = *Y;
		if ( *Z < (*_ = fma(lambda, *_, y * y)) ) {
			register double f, r;
			f = r = y * simd_rsqrt(*_);
			for ( register intptr_t n = 0 ; n < N ; ++ n ) {
				register double const
				q = h[n],
				Q = sqrt(fma(-f, f, 1) * fma(-q, q, 1)) * p[n] - f * q;
				h[n] = r;
				p[n] = Q;
				r = fma(Q, f, q) * simd_rsqrt(fma(-Q, Q, 1) * fma(-f, f, 1));
				f = fma(Q, q, f) * simd_rsqrt(fma(-Q, Q, 1) * fma(-q, q, 1));
			}
			notify(t, p, f, r); // also residual (f, r) are normalized by RMS (EMA)
		} else {
			notify(t, p, y, y);
		}
	}
}
__attribute__((always_inline))
void lattice_rls_p(lattice_rls_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull P, intptr_t const ldP,
				   double const lambda,
				   intptr_t const length) {
	static double const _ = 0;
	register intptr_t const N = object->n;
	double thr = 0.5;
	lattice_rls(object, Y, lambda, &thr, 0, length, ^(const intptr_t t, double const*const __nonnull p, const double f, const double r) {
		vDSP_viclipD(p, 1, &_, &_, P + t + ( N - 1 ) * ldP, -ldP, N);
	});
}
__attribute__((always_inline))
void lattice_rls_e(lattice_rls_t * __nonnull const object,
				   double const * __nonnull Y,
				   double       * __nonnull E,
				   double const lambda,
				   intptr_t const length) {
	register intptr_t const N = object->n;
	double thr = 0.1;
	lattice_rls(object, Y, lambda, &thr, 0, length, ^(const intptr_t t, double const*const __nonnull p, const double f, const double r) {
		E[t] = f;
	});
}
