//
//  lattice.c
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
#include"module.h"
#include"lattice.h"
// MARK: process
__attribute__((always_inline))
lattice_filter_t * __nonnull const lattice_filter_create(intptr_t const order, intptr_t const count) {
	void*__nullable const p = __malloc__(sizeof(lattice_filter_t const) + count * ( order + 1 ) * sizeof(double const));
	lattice_filter_t * const object = (lattice_filter_t*const)p;
	*(double**const)&object->w = (double*const)(p + sizeof(lattice_filter_t const));
	*(void**const)&object->r = nil;
	*(intptr_t*const)&object->c = count;
	*(intptr_t*const)&object->n = order;
	return object;
}
__attribute__((always_inline))
void lattice_filter_destroy(lattice_filter_t * __nonnull const object) {
	__free__(object);
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
__attribute__((always_inline))
void lattice_filter_jp_static(lattice_filter_t * __nonnull const object,
							  double const * __nonnull const P, intptr_t const ldP, // PARCOR
							  double const * __nonnull const K, intptr_t const ldK, // KERNEL
							  double const * __nonnull const X, intptr_t const ldX,
							  double       * __nonnull const Y, intptr_t const ldY,
							  intptr_t const length) {
	register intptr_t const N = object->n;
	register double * __nonnull const r = object->w;
	for ( register intptr_t c = object->c ; 0 < c -- ;  ) {
		register double const * __nonnull p = P + c * ldP;
		register double const * __nonnull k = K + c * ldK;
		register double const * __nonnull x = X + c * ldX;
		register double       * __nonnull y = Y + c * ldY;
		for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ x, ++ y ) {
			register double f = *x, a = 0;
			for ( register intptr_t n = 0 ; n < N ; ++ n )
				a = fma(k[n], r[n] = fma(f = fma(-p[n], r[n+1], f), p[n], r[n+1]), a);
			r[N] = f;
			*y = a;
		}
	}
}
__attribute__((always_inline))
void lattice_filter_jp_active(lattice_filter_t * __nonnull const object,
							  double const * __nonnull const P, intptr_t const ldP, // PARCOR
							  double const * __nonnull const K, intptr_t const ldK, // KERNEL
							  double const * __nonnull const X, intptr_t const ldX,
							  double       * __nonnull const Y, intptr_t const ldY,
							  intptr_t const length) {
	register intptr_t const N = object->n;
	register double * __nonnull const r = object->w;
	for ( register intptr_t c = object->c ; 0 < c -- ;  ) {
		register double const * __nonnull p = P;
		register double const * __nonnull k = K;
		register double const * __nonnull x = X + c * ldX;
		register double       * __nonnull y = Y + c * ldY;
		for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ x, ++ y, ++ p, ++ k ) {
			register double f = *x, a = 0;
			for ( register intptr_t n = 0 ; n < N ; ++ n )
				a = fma(k[n*ldK], r[n] = fma(f = fma(-p[n*ldP], r[n+1], f), p[n*ldP], r[n+1]), a);
			r[N] = f;
			*y = a;
		}
	}
}
//// MARK: LMS
//__attribute__((always_inline))
//lattice_sgd_t * __nonnull const lattice_sgd_create(intptr_t const order) {
//	void * const p = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(lattice_sgd_t const) + 2 * order * sizeof(double const), 0);
//	lattice_sgd_t * const object = (lattice_sgd_t * const)p;
//	*(double**const)&object->p = (double*const)(p + sizeof(lattice_sgd_t const) + 0 * order * sizeof(double const));
//	*(double**const)&object->h = (double*const)(p + sizeof(lattice_sgd_t const) + 1 * order * sizeof(double const));
//	*(intptr_t*const)&object->n = order;
//	lattice_sgd_reset(object);
//	return object;
//}
//__attribute__((always_inline))
//void lattice_sgd_destroy(lattice_sgd_t * __nonnull const object) {
//	CFAllocatorDeallocate(kCFAllocatorDefault, object);
//}
//__attribute__((always_inline))
//void lattice_sgd_reset(lattice_sgd_t * __nonnull const object) {
//	vDSP_vclrD(object->p, 1, 2 * object->n);
//}
//__attribute__((always_inline))
//inline void lattice_sgd(lattice_sgd_t * __nonnull const object,
//						double const * __nonnull Y,
//						double const mu,
//						intptr_t const length,
//						void(^notify)(intptr_t const, double const*__nonnull const, double const, double const)) {
//	register double * __nonnull const p = object->p;
//	register double * __nonnull const h = object->h;
//	register intptr_t const N = object->n;
//	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y ) {
//		register double f, r;
//		f = r = *Y;
//		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
//			register simd_double2 const
//			u = simd_make_double2(h[n], f),
//			v = fma(p[n], u, simd_make_double2(u.y, u.x));
//			p[n] -= mu * simd_dot(u, v);
//			h[n] = r;
//			f = v.x;
//			r = v.y;
//		}
//		notify(t, p, f, r);
//	}
//}
//__attribute__((always_inline))
//void lattice_sgd_p(lattice_sgd_t * __nonnull const object,
//				   double const * __nonnull Y,
//				   double       * __nonnull P, intptr_t const ldP,
//				   double const mu,
//				   intptr_t const length) {
//	static const double _ = 0;
//	register intptr_t const N = object->n;
//	lattice_sgd(object, Y, mu, length, ^(intptr_t const t, double const*__nonnull const p, double const f, double const r) {
//		vDSP_viclipD(p, 1, &_, &_, P + t + ( N - 1 ) * ldP, -ldP, N);
//	});
//}
//__attribute__((always_inline))
//void lattice_sgd_e(lattice_sgd_t * __nonnull const object,
//				   double const * __nonnull Y,
//				   double       * __nonnull E,
//				   double const mu,
//				   intptr_t const length) {
//	lattice_sgd(object, Y, mu, length, ^(intptr_t const t, double const*__nonnull const p, double const f, double const r) {
//		E[t] = f;
//	});
//}
//// MARK: RLS
//__attribute__((always_inline))
//lattice_rls_t * __nonnull const lattice_rls_create(intptr_t const order) {
//	void * const p = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(lattice_rls_t const) + 4 * ( order + 1 ) * sizeof(double const), 0);
//	lattice_rls_t * const object = (lattice_rls_t * const)p;
//	*(intptr_t*const)&object->n = order;
//	*(double**const)&object->p = (double*const)(p + sizeof(lattice_rls_t const) + 0 * ( order + 1 ) * sizeof(double const));
//	*(double**const)&object->_ = (double*const)(p + sizeof(lattice_rls_t const) + 1 * ( order + 1 ) * sizeof(double const));
//	*(double**const)&object->h = (double*const)(p + sizeof(lattice_rls_t const) + 2 * ( order + 1 ) * sizeof(double const));
//	*(double**const)&object->s = (double*const)(p + sizeof(lattice_rls_t const) + 3 * ( order + 1 ) * sizeof(double const));
//	lattice_rls_reset(object);
//	return object;
//}
//__attribute__((always_inline))
//void lattice_rls_destroy(lattice_rls_t * __nonnull const object) {
//	CFAllocatorDeallocate(kCFAllocatorDefault, object);
//}
//__attribute__((always_inline)) // assume E[|x|^2] = 1
//void lattice_rls_reset(lattice_rls_t * __nonnull const object) {
//	vDSP_vclrD(object->p, 1, object->n+1);
//	vDSP_vclrD(object->s, 1, object->n+1);
//	vDSP_vfillD((double const[]){1.0}, object->h, 1, object->n+1);
//	vDSP_vfillD((double const[]){1.0}, object->_, 1, object->n+1);
//}
//__attribute__((always_inline))
//inline void lattice_rls(lattice_rls_t * __nonnull const object,
//						double const * __nonnull Y, double const lambda,
//						double const * __nonnull Z, intptr_t const ldZ,
//						intptr_t const length,
//						void(^notify)(intptr_t const t, double const*__nonnull const p, double const f, double const r)) {
//	register intptr_t const N = object->n;
//	register double * __nonnull const _ = object->_; // [F0, Δ]
//	register double * __nonnull const s = object->s; // r_{t-1}[n]
//	register double * __nonnull const h = object->h; // R_{t-1}[n]
//	register double * __nonnull const p = object->p; // PARCOR
//	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, Z += ldZ ) {
//		// VER.3
//		register double f, r, F, R, P = 1;
//		r = f = *Y;
//		R = F = *_ /= fma(*_, *Y**Y, lambda);
//		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
//			register double
//			q = s[n],
//			Q = h[n],
//			D = _[n+1] = lambda * _[n+1] + f * q * P,
//			b = -D * F,
//			a = -D * Q,
//			g = fma(-F * Q, D * D, 1),
//			d = fma(-P * Q, q * q, 1);
//			s[n] = r;
//			h[n] = R;
//			r = fma(b, f, q);
//			f = fma(a, q, f);
//			R = 0 < g ? Q / g : 0;
//			F = 0 < g ? F / g : 0;
//			P = 0 < d ? P / d : 0;
//			p[n] = a;
//		}
//// 		VER.2
////		register double f, r, F, R, P = 1;
////		r = f = *Y;
////		R = F = *_ = simd_dot((simd_double2 const) {lambda, f}, (simd_double2 const) {*_, r});
////		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
////			register double const q = s[n], Q = h[n], D = _[n+1] = fma(lambda, _[n+1], f * q * P);
////			s[n] = r;
////			h[n] = R;
////			if ( q * q < Q * P && D * D < Q * F ) {
////				register double const b = -D / F, a = -D / Q;
////				R = Q - D * D / F;
////				F = F - D * D / Q;
////				r = fma(b, f, q);
////				f = fma(a, q, f);
////				P = Q / ( Q * P - q * q );
////				p[n] = a;
////			} else {
////				P = 0;
////				p[n] = 0;
////			}
////		}
//// 		VER.1
////		if ( *Z < *_ ) {
////			p[0] = 1;
////			for ( register intptr_t n = 0 ; n < N ; ++ n )
////				if ( FLT_EPSILON < p[n] ) {
////					register double const
////					Q = h[n],
////					q = s[n],
////					D = _[n+1] = fma(lambda, _[n+1], f * q / p[n]),
////					b = -D / F,
////					a = -D / Q;
////					h[n] = R;
////					s[n] = r;
////					R = Q - D * D / F;
////					F = F - D * D / Q;
////					r = fma(b, f, q);
////					f = fma(a, q, f);
////					p[n+1] = p[n] - q * q / Q;
////					p[n] = a;
////				} else {
////					_[n+1] = 0;
////					h[n] = F;
////					s[n] = f;
////					p[n+1] = 0;
////					p[n] = 0;
////				}
////		}
//		notify(t, p, f, r);
//	}
//}
//__attribute__((always_inline)) // normalized algorithm optimised for fixed-point-number processor
//void lattice_rls_n(lattice_rls_t * __nonnull const object,
//				   double const * __nonnull Y, double const lambda,
//				   double const * __nonnull Z, intptr_t const ldZ,
//				   intptr_t const length,
//				   void(^notify)(intptr_t const t, double const*__nonnull const p, double const f, double const r)) {
//	register intptr_t const N = object->n;
//	register double * __nonnull const p = object->p; // PARCOR
//	register double * __nonnull const _ = object->_; // [F0,]
//	register double * __nonnull const h = object->h; // r[t-1,:]
//	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, Z += ldZ ) {
//		register double const y = *Y;
//		if ( *Z < (*_ = fma(lambda, *_, y * y)) ) {
//			register double f, r;
//			f = r = y * simd_rsqrt(*_);
//			for ( register intptr_t n = 0 ; n < N ; ++ n ) {
//				register double const
//				q = h[n],
//				Q = sqrt(fma(-f, f, 1) * fma(-q, q, 1)) * p[n] - f * q;
//				h[n] = r;
//				p[n] = Q;
//				r = fma(Q, f, q) * simd_rsqrt(fma(-Q, Q, 1) * fma(-f, f, 1));
//				f = fma(Q, q, f) * simd_rsqrt(fma(-Q, Q, 1) * fma(-q, q, 1));
//			}
//			notify(t, p, f, r); // also residual (f, r) are normalized by RMS (EMA), to fix f**_, r**_
//		} else {
//			notify(t, p, y, y);
//		}
//	}
//}
//__attribute__((always_inline))
//void lattice_rls_p(lattice_rls_t * __nonnull const object,
//				   double const * __nonnull Y,
//				   double       * __nonnull P, intptr_t const ldP,
//				   double const lambda,
//				   intptr_t const length) {
//	static double const _ = 0;
//	register intptr_t const N = object->n;
//	double thr = FLT_EPSILON;
//	lattice_rls(object, Y, lambda, &thr, 0, length, ^(const intptr_t t, double const*const __nonnull p, const double f, const double r) {
//		vDSP_viclipD(p, 1, &_, &_, P + t + ( N - 1 ) * ldP, -ldP, N);
//	});
//}
//__attribute__((always_inline))
//void lattice_rls_e(lattice_rls_t * __nonnull const object,
//				   double const * __nonnull Y,
//				   double       * __nonnull E,
//				   double const lambda,
//				   intptr_t const length) {
//	register intptr_t const N = object->n;
//	double thr = FLT_EPSILON;
//	lattice_rls(object, Y, lambda, &thr, 0, length, ^(const intptr_t t, double const*const __nonnull p, const double f, const double r) {
//		E[t] = f;
//	});
//}
//__attribute__((always_inline))
//inline void lattice_jp_rls(lattice_rls_t * __nonnull const object,
//						   double const * __nonnull Y, double const lambda,
//						   double const * __nonnull Z, intptr_t const ldZ,
//						   intptr_t const length,
//						   void(^notify)(intptr_t const t, double const*__nonnull const p, double const f, double const r)) {
//	register intptr_t const N = object->n;
//	register double * __nonnull const _ = object->_; // [F0, Δ]
//	register double * __nonnull const s = object->s; // r_{t-1}[n]
//	register double * __nonnull const h = object->h; // R_{t-1}[n]
//	register double * __nonnull const p = object->p; // PARCOR
//	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, Z += ldZ ) {
//		// VER.3
//		register double f, r, F, R, P = 1;
//		r = f = *Y;
//		R = F = *_ /= fma(*_, *Y**Y, lambda);
//		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
//			register double
//			q = s[n],
//			Q = h[n],
//			D = _[n+1] = lambda * _[n+1] + f * q * P,
//			b = -D * F,
//			a = -D * Q,
//			g = fma(-F * Q, D * D, 1),
//			d = fma(-P * Q, q * q, 1);
//			s[n] = r;
//			h[n] = R;
//			r = fma(b, f, q);
//			f = fma(a, q, f);
//			R = 0 < g ? Q / g : 0;
//			F = 0 < g ? F / g : 0;
//			P = 0 < d ? P / d : 0;
//			p[n] = a;
//		}
//// 		VER.2
////		register double f, r, F, R, P = 1;
////		r = f = *Y;
////		R = F = *_ = simd_dot((simd_double2 const) {lambda, f}, (simd_double2 const) {*_, r});
////		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
////			register double const q = s[n], Q = h[n], D = _[n+1] = fma(lambda, _[n+1], f * q * P);
////			s[n] = r;
////			h[n] = R;
////			if ( q * q < Q * P && D * D < Q * F ) {
////				register double const b = -D / F, a = -D / Q;
////				R = Q - D * D / F;
////				F = F - D * D / Q;
////				r = fma(b, f, q);
////				f = fma(a, q, f);
////				P = Q / ( Q * P - q * q );
////				p[n] = a;
////			} else {
////				P = 0;
////				p[n] = 0;
////			}
////		}
//// 		VER.1
////		if ( *Z < *_ ) {
////			p[0] = 1;
////			for ( register intptr_t n = 0 ; n < N ; ++ n )
////				if ( FLT_EPSILON < p[n] ) {
////					register double const
////					Q = h[n],
////					q = s[n],
////					D = _[n+1] = fma(lambda, _[n+1], f * q / p[n]),
////					b = -D / F,
////					a = -D / Q;
////					h[n] = R;
////					s[n] = r;
////					R = Q - D * D / F;
////					F = F - D * D / Q;
////					r = fma(b, f, q);
////					f = fma(a, q, f);
////					p[n+1] = p[n] - q * q / Q;
////					p[n] = a;
////				} else {
////					_[n+1] = 0;
////					h[n] = F;
////					s[n] = f;
////					p[n+1] = 0;
////					p[n] = 0;
////				}
////		}
//		notify(t, p, f, r);
//	}
//}
// MARK: GAL
__attribute__((always_inline))
gal_t * __nonnull const gal_create(intptr_t const order) {
	void * const p = __malloc__(sizeof(gal_t const) + 3 * order * sizeof(double const));
	gal_t * const object = (gal_t * const)p;
	*(double**const)&object->p = (double*const)(p + sizeof(gal_t const) + 0 * order * sizeof(double const));
	*(double**const)&object->c = (double*const)(p + sizeof(gal_t const) + 1 * order * sizeof(double const));
	*(double**const)&object->h = (double*const)(p + sizeof(gal_t const) + 2 * order * sizeof(double const));
	*(intptr_t*const)&object->n = order;
	gal_reset(object);
	return object;
}
__attribute__((always_inline))
void gal_destroy(gal_t * __nonnull const object) {
	__free__(object);
}
__attribute__((always_inline))
void gal_reset(gal_t * __nonnull const object) {
	__clr__(object->p, 1, object->n);
	__clr__(object->c, 1, object->n);
	__clr__(object->h, 1, object->n);
}
__attribute__((always_inline))
void gal_mu(gal_t * __nonnull const object, double const mu) {
	object->mu = mu;
}
__attribute__((always_inline))
void gal_p(gal_t * __nonnull const object,
		   register double const * __nonnull Y,
		   register double       * __nonnull P, intptr_t const ldP,
		   intptr_t const length) {
	static intptr_t const neg = -1;
	register double * __nonnull const p = object->p;
	register double * __nonnull const h = object->h;
	register double const mu = object->mu;
	intptr_t const N = object->n;
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ P ) {
		register double f, r;
		f = r = *Y;
		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
			register simd_double2 const u = {h[n], f}, v = {u.y, u.x}, _ = fma(p[n], u, v);
			p[n] = fma(-mu, simd_dot(u, _), p[n]);
			h[n] = r;
			f = _.x;
			r = _.y;
		}
		dcopy_(&N, p, &neg, P, &ldP);
	}
}
__attribute__((always_inline))
void gal_r(gal_t * __nonnull const object,
		   register double const * __nonnull Y,
		   register double       * __nonnull R,
		   intptr_t const length) {
	register double * __nonnull const p = object->p;
	register double * __nonnull const h = object->h;
	register double const mu = object->mu;
	intptr_t const N = object->n;
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ R ) {
		register double f, r;
		f = r = *Y;
		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
			register simd_double2 const u = {h[n], f}, v = {u.y, u.x}, _ = fma(p[n], u, v);
			p[n] = fma(-mu, simd_dot(u, _), p[n]);
			h[n] = r;
			f = _.x;
			r = _.y;
		}
		*R = f;
	}
}
__attribute__((always_inline))
void gal_e(gal_t * __nonnull const object,
		   register double const * __nonnull Y,
		   register double const * __nonnull D,
		   register double       * __nonnull E,
		   intptr_t const length) {
	register double * __nonnull const p = object->p;
	register double * __nonnull const c = object->c;
	register double * __nonnull const h = object->h;
	register double const mu = object->mu;
	intptr_t const N = object->n;
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ D, ++ E ) {
		register double f, r, e = *D;
		f = r = *Y;
		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
			register simd_double2 const u = {h[n], f}, v = {u.y, u.x}, _ = fma(p[n], u, v);
			p[n] = fma(-mu, simd_dot(u, _), p[n]);
			h[n] = r;
			{//JP
				c[n] = fma(2 * mu * r, e = fma(-c[n], r, e), c[n]);
			}
			f = _.x;
			r = _.y;
		}
		*E = e;
	}
}
// MARK: LSL
__attribute__((always_inline))
lsl_t * __nonnull const lsl_create(intptr_t const order) {
	void * const p = __malloc__(sizeof(lsl_t const) + 4 * order * sizeof(double const));
	lsl_t * const object = (lsl_t * const)p;
	*(double**const)&object->h = (double*const)(p + sizeof(lsl_t const) + 0 * order * sizeof(double const));
	*(double**const)&object->H = (double*const)(p + sizeof(lsl_t const) + 1 * order * sizeof(double const));
	*(double**const)&object->U = (double*const)(p + sizeof(lsl_t const) + 2 * order * sizeof(double const));
	*(double**const)&object->V = (double*const)(p + sizeof(lsl_t const) + 3 * order * sizeof(double const));
	*(intptr_t*const)&object->n = order;
	lsl_reset(object);
	return object;
}
__attribute__((always_inline))
void lsl_destroy(lsl_t * __nonnull const object) {
	__free__(object);
}
__attribute__((always_inline))
void lsl_reset(lsl_t * __nonnull const object) {
	__clr__(object->h, 1, object->n);
	__fill__(FLT_EPSILON, object->H, 1, object->n);
	__fill__(1, object->U, 1, object->n);
	__fill__(1, object->V, 1, object->n);
}
__attribute__((always_inline))
void lsl_lambda(lsl_t * __nonnull const object, double const lambda) {
	object->lambda = lambda;
}
__attribute__((always_inline))
void lsl_p(lsl_t * __nonnull const object,
		   register double const * __nonnull Y,
		   register double       * __nonnull _, intptr_t const ldP,
		   intptr_t const length) {
	intptr_t const N = object->n;
	register double * __nonnull const h = object->h;
	register double * __nonnull const H = object->H;
	register double * __nonnull const U = object->U;
	register double const lambda = object->lambda;
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ _ ) {
		register double f, r, F, R, P = 1, * p = _ + N * ldP - ldP;
		r = f = *Y;
		R = F = *H / fma(*H, *Y**Y, lambda);
		for ( register intptr_t n = 0 ; n < N ; ++ n, p -= ldP ) {
			register double const
			q = h[n],
			Q = H[n],
			D = U[n] = lambda * U[n] + f * q * P,
			b = -D * F,
			a = -D * Q,
			g = fma(-F * Q, D * D, 1),
			d = fma(-P * Q, q * q, 1);
			h[n] = r;
			H[n] = R;
			r = fma(b, f, q);
			f = fma(a, q, f);
			R = 0 < g ? Q / g : 0;
			F = 0 < g ? F / g : 0;
			P = 0 < d ? P / d : 0;
			*p = a;
		}
	}
}
__attribute__((always_inline))
void lsl_r(lsl_t * __nonnull const object,
		   register double const * __nonnull Y,
		   register double       * __nonnull _,
		   intptr_t const length) {
	register intptr_t const N = object->n;
	register double * __nonnull const h = object->h; // r_{t-1}[n]
	register double * __nonnull const H = object->H; // R_{t-1}[n]
	register double * __nonnull const U = object->U; //
	register double const lambda = object->lambda;
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ _ ) {
		register double f, r, F, R, P = 1;
		r = f = *Y;
		R = F = *H / fma(*H, *Y**Y, lambda);
		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
			register double const
			q = h[n],
			Q = H[n],
			D = U[n] = lambda * U[n] + f * q * P,
			b = -D * F,
			a = -D * Q,
			g = fma(-F * Q, D * D, 1),
			d = fma(-P * Q, q * q, 1);
			h[n] = r;
			H[n] = R;
			r = fma(b, f, q);
			f = fma(a, q, f);
			R = 0 < g ? Q / g : 0;
			F = 0 < g ? F / g : 0;
			P = 0 < d ? P / d : 0;
		}
		*_ = f;
	}
}
__attribute__((always_inline))
void lsl_e(lsl_t * __nonnull const object,
		   register double const * __nonnull Y,
		   register double const * __nonnull D,
		   register double       * __nonnull E,
		   intptr_t const length) {
	register intptr_t const N = object->n;
	register double * __nonnull const h = object->h; // r_{t-1}[n]
	register double * __nonnull const H = object->H; // R_{t-1}[n]
	register double * __nonnull const U = object->U; //
	register double * __nonnull const V = object->V; //
	register double const lambda = object->lambda;
	for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ D, ++ E ) {
		register double f, r, F, R, P = 1, e = *D;
		r = f = *Y;
		R = F = *H / fma(*H, *Y**Y, lambda);
		for ( register intptr_t n = 0 ; n < N ; ++ n ) {
			register double const
			Q = H[n],
			q = h[n],
			D = U[n] = fma(lambda, U[n], f * q * P),
			b = -D * F,
			a = -D * Q,
			g = fma(-F * Q, D * D, 1),
			d = fma(-P * Q, q * q, 1);
			H[n] = R;
			h[n] = r;
			{//JP
				e = fma(-R * r, V[n] = fma(lambda, V[n], e * r * P), e);
			}
			P = 0 < d ? P / d : 0;
			R = 0 < g ? Q / g : 0;
			F = 0 < g ? F / g : 0;
			r = fma(b, f, q);
			f = fma(a, q, f);
		}
		*E = e;
	}
}
