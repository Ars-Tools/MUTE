//
//  ftf_filter.c
//  MUTE
//
//  Created by Kota on 8/20/R7.
//
#include"module.h"
#include"tfo.h"
tfo_t * __nonnull const tfo_create(intptr_t const order) {
	void * __nonnull const p = __malloc__(sizeof(tfo_t const) + ( 4 * order + 1 ) * sizeof(double const)); // G requires [order + 1]
	tfo_t * __nonnull const object = (tfo_t*__nonnull const)p;
	*(intptr_t*const)&object->n = order;
	*(double**__nonnull const)&object->B = (double*__nonnull const)(p + sizeof(tfo_t const) + 0 * order * sizeof(double const));
	*(double**__nonnull const)&object->A = (double*__nonnull const)(p + sizeof(tfo_t const) + 1 * order * sizeof(double const));
	*(double**__nonnull const)&object->K = (double*__nonnull const)(p + sizeof(tfo_t const) + 2 * order * sizeof(double const));
	*(double**__nonnull const)&object->G = (double*__nonnull const)(p + sizeof(tfo_t const) + 3 * order * sizeof(double const));
	tfo_reset(object);
	return object;
}
void tfo_destroy(tfo_t * __nonnull const object) {
	__free__(object);
}
void tfo_reset(tfo_t * __nonnull const object) {
	object->theta = FLT_EPSILON;
	object->zeta = 0;
	object->eta = 0;
	__clr__(object->B, 1, object->n);
	__clr__(object->A, 1, object->n);
	__clr__(object->K, 1, object->n);
	__clr__(object->G, 1, object->n + 1);
}
double const tfo(tfo_t * __nonnull const object,
				 double const             y,
				 double const * __nonnull x, intptr_t const ldx,
				 double       * __nonnull w, intptr_t const ldw) {
	static intptr_t const inc = 1;
	intptr_t const N = object->n;
	register double const lambda = object->lambda;
	// F
	double const
		fr = *x - object->zeta,
		fp = fr * object->theta,
		F = fma(fr, fp, lambda);
	// A
	 daxpy_(&N, &fp, object->K, &inc, object->A, &inc);
//	__vsmsma__(object->K, 1, fp, object->A, 1, lambda, object->A, 1, N); // with forgetting factor to forget previous numerical error
	// G
	__vsma__(object->A, 1, *object->G = fr / F, object->K, 1, object->G + 1, 1, N);
	// U
	double const
		rr = object->eta - ddot_(&N, object->B, &inc, x, &ldx),
		rp = rr * (object->theta = lambda / fma(rr, rr, F / object->theta)),
		R = fma(fr, fp, lambda);
	// K
	__vsma__(object->B, 1, -object->G[N], object->G, 1, object->K, 1, N);
	// B
	 daxpy_(&N, &rp, object->K, &inc, object->B, &inc);
//	__vsmsma__(object->K, 1, rp, object->B, 1, lambda, object->B, 1, N); // with forgetting factor to forget previous numerical error
	// E
	double const
		er = y - ddot_(&N, w, &ldw, x, &ldx),
		ep = er * object->theta * lambda / F;
	// W
	daxpy_(&N, &ep, object->G, &inc, w, &ldw);
	// Rescaling
	object->theta *= simd_precise_rsqrt(F * R);
//	object->theta = pow(object->theta, lambda);
	// cache for next update
	object->eta = x[N-1];
	object->zeta = ddot_(&N, object->A, &inc, x, &ldx);
	return er;
//	// VER.1
//	// capture λ * current F
//	double const Q = lambda * object->F;
//	
//	// (6.10)
//	double const bf = *x + object->zeta;
//	
//	// (6.34)
//	double const f = bf / object->theta;
//
//	// (6.38)
//	object->F = simd_dot((simd_double2 const) { lambda, bf }, (simd_double2 const) { object->F, f });
//	
//	// GUARD
//	if ( !(epsilon < object->F) ) {
//		++object->recover;
//		tfo_reset(object);
//		return 0;
//	}
//	
//	// (6.39)
//	double const eta = object->F / Q * object->theta;
//	
//	// (6.51)
//	__vsma__(object->A, 1, *object->G = bf / Q, object->K, 1, object->G + 1, 1, N);
//	
//	// (6.54)
//	double const br = lambda * object->G[N] * object->R;
//	
//	// (6.49)
//	object->theta = fabs(eta - object->G[N] * br); //
//	assert(isnormal(object->theta));
//	
//	// (6.37)
//	double const r = br / object->theta;
//	
//	// (6.40)
//	object->R = simd_dot((simd_double2 const) { lambda, br }, (simd_double2 const) { object->R, r });
//	
//	// (6.47)
//	daxpy_(&N, (double const[]){-f}, object->K, &inc, object->A, &inc);
//	
//	// (6.53)
//	__vsma__(object->B, 1, -object->G[N], object->G, 1, object->K, 1, N);
//	
//	// (6.48)
//	daxpy_(&N, (double const[]){-r}, object->K, &inc, object->B, &inc);
//	
//	// (6.16)
//	double const e = y - ddot_(&N, w, &ldw, x, &ldx);
//	
//	// (6.22)
//	double const d = e / eta;
//	
//	// (6.46)
//	daxpy_(&N, &d, object->G, &inc, w, &ldw);
//	
//	// for next update
//	object->zeta = ddot_(&N, object->A, &inc, x, &ldx);
//	return e;
}
tfo_filter_t * __nonnull const tfo_filter_create(intptr_t const order) {
	void * __nonnull const p = __malloc__(sizeof(tfo_filter_t const) + 3 * ( order + 1 ) * sizeof(double const));
	tfo_filter_t * __nonnull const object = (tfo_filter_t*__nonnull const)p;
	*(tfo_t**__nonnull const)&object->core = tfo_create(order + 1);
	*(double**__nonnull const)&object->x = (double*__nonnull const)(p + sizeof(tfo_filter_t const) + 0 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->h = (double*__nonnull const)(p + sizeof(tfo_filter_t const) + 1 * object->core->n * sizeof(double const));
	*(double**__nonnull const)&object->w = (double*__nonnull const)(p + sizeof(tfo_filter_t const) + 2 * object->core->n * sizeof(double const));
	tfo_filter_reset(object);
	return object;
}
void tfo_filter_destroy(tfo_filter_t * __nonnull const object) {
	tfo_destroy(object->core);
	__free__(object);
}
void tfo_filter_reset(tfo_filter_t * __nonnull const object) {
	tfo_reset(object->core);
	intptr_t const n = object->core->n;
	__clr__(object->h, 1, n);
	__clr__(object->w, 1, n);
	object->w[0] = 1;
	object->t = 0;
}
void tfo_filter_lambda(tfo_filter_t * __nonnull const object, double const lambda) {
	object->core->lambda = lambda;
}
void tfo_filter_kernel(tfo_filter_t * __nonnull const object,
					   double const * __nonnull y,
					   double const * __nonnull x,
					   double       * __nonnull w, intptr_t const ldw,
					   intptr_t const length) {
	tfo_t * __nonnull const core = object->core;
	intptr_t const N = core->n;
	register double * __nonnull const W = object->w;
	register double * __nonnull const H = object->h;
	register double * __nonnull const X = object->x;
	for ( register intptr_t t = object->t, T = t + length ; t < T ; ++ t, ++ y, ++ x, ++ w ) {
		register intptr_t
		tail = t % N + 1,
		head = N - tail;
		H[head] = *x;
		memcpy(X, H + head, tail * sizeof(double const));
		memcpy(X + tail, H, head * sizeof(double const));
		tfo(core, *y, X, 1, W, 1);
		daxpy_(&N, (double const[]){1}, W, (intptr_t const[]){1}, w, &ldw);
	}
	object->t = ( object->t + length ) % N;
}
void tfo_filter_error(tfo_filter_t * __nonnull const object,
					  double const * __nonnull y,
					  double const * __nonnull x,
					  double       * __nonnull e,
					  intptr_t const length) {
	tfo_t * __nonnull const core = object->core;
	intptr_t const N = core->n;
	register double * __nonnull const W = object->w;
	register double * __nonnull const H = object->h;
	register double * __nonnull const X = object->x;
	for ( register intptr_t t = object->t, T = t + length ; t < T ; ++ t, ++ y, ++ x, ++ e ) {
		register intptr_t
		tail = t % N + 1,
		head = N - tail;
		H[head] = *x;
		memcpy(X, H + head, tail * sizeof(double const));
		memcpy(X + tail, H, head * sizeof(double const));
		*e = tfo(core, *y, X, 1, W, 1);
	}
	object->t = ( object->t + length ) % N;
}
double tfo_ref(double const * __nonnull x, double const * __nonnull y, double * __nonnull w, intptr_t T, intptr_t p, double lambda) {
	double gp[p+1], g[p+2], newgp[p+1];
	double alpha[p+1], beta[p+1], be, e, rr;
	double oldff, theta, br, r, ff, thetap, bf, f, fff;
	intptr_t i, t, m, n, ip;
	ff = x[0] * x[0];
	w[0] = -y[0] / x[0];
	thetap = 1;
	for ( n = 1 ; n <= p ; ++ n ) {
		bf = x[n];
		for ( i = 0 ; i <= n - 1 ; ++ i ) bf = bf + x[n-i] * alpha[i];
		f = bf * thetap;
		ff = lambda * ff;
		fff = ff + bf * f;
		thetap = ff / fff * thetap;
		newgp[1] = bf / ff;
		for ( i = 2 ; i <= n ; ++ i ) newgp[i] = gp[i-1] + newgp[1] * alpha[i-1];
		for ( i = 1 ; i <= n ; ++ i ) gp[i] = newgp[i];
		be = y[n];
		for ( i = 0 ; i <= n - 1 ; ++ i ) be = be + x[n-i] * w[i];
		e = be * thetap;
		alpha[n] = -bf / x[0];
		w[n] = -be / x[0];
	}
	
	rr = x[0] * x[0] * thetap;
	
	for ( i = 1 ; i <= p ; ++ i ) beta[i] = -x[0] * thetap * gp[i];
	
	for ( i = 0 ; i <= p ; ++ i )
		printf("%lf, ", beta[i]);
	printf("\r\n");
	for ( n = p + 1 ; n < T ; ++ n ) {

		bf = x[n];
		for ( i = 1 ; i <= p ; ++ i ) bf = bf + x[n-i] * alpha[i]; // (6.10)

		f = bf * thetap; // (6.34)

		oldff = ff;
		
		ff = lambda * oldff + bf * f; // (6.38)
		
		theta = lambda * ( oldff / ff ) * thetap; // (6.39)
		
		g[1] = bf / ( lambda * oldff ); // (6.51)
		for ( i = 2 ; i <= p + 1 ; ++ i ) g[i] = gp[i-1] + g[1] * alpha[i-1];
		
		br = lambda * g[p+1] * rr; // (6.54)
		
		thetap = theta / ( 1 - g[p+1] * theta * br ); // (6.49)
		
		r = br * thetap; // (6.37)
		
		rr = lambda * rr + br * r; // (6.40)
		
		for ( i = 1 ; i <= p ; ++ i ) alpha[i] = alpha[i] - f * gp[i]; // (6.47)
		
		for ( i = 1 ; i <= p ; ++ i ) gp[i] = g[i] - g[p+1] * beta[i]; // (6.53)
		
		for ( i = 1 ; i <= p ; ++ i ) beta[i] = beta[i] - r * gp[i]; // (6.48)
		
		be = y[n];
		for ( i = 0 ; i <= p ; ++ i ) be = be + x[n-i] * w[i]; // (6.16)
		e = be * theta; // (6.22)
		
		for ( i = 0 ; i <= p ; ++ i ) w[i] = w[i] - e * g[i+1]; // (6.46)
		
//		theta *= simd_precise_rsqrt(ff * rr);
//		ff = 1;
//		rr = 1;
		
	}
	for ( i = 0 ; i <= p ; ++ i )
		printf("%lf, ", beta[i]);
	printf("\r\n%lf, %lf, %lf, %lf, %lf\r\n", rr, ff, rr, theta, thetap);
	return e;
}
double tfo_raw(double const * __nonnull x, double const * __nonnull y, double * __nonnull w, intptr_t T, intptr_t p, double lambda) {
	double gp[p+1], g[p+2], newgp[p+1];
	double alpha[p+1], beta[p+1], be, e, rr;
	double oldff, theta, br, r, ff, thetap, bf, f, fff;
	intptr_t i, t, m, n, ip;
	ff = x[0] * x[0];
	w[0] = -y[0] / x[0];
	thetap = 1;
	for ( n = 1 ; n <= p ; ++ n ) {
		bf = x[n];
		for ( i = 0 ; i <= n - 1 ; ++ i ) bf = bf + x[n-i] * alpha[i];
		f = bf * thetap;
		ff = lambda * ff;
		fff = ff + bf * f;
		thetap = ff / fff * thetap;
		newgp[1] = bf / ff;
		for ( i = 2 ; i <= n ; ++ i ) newgp[i] = gp[i-1] + newgp[1] * alpha[i-1];
		for ( i = 1 ; i <= n ; ++ i ) gp[i] = newgp[i];
		be = y[n];
		for ( i = 0 ; i <= n - 1 ; ++ i ) be = be + x[n-i] * w[i];
		e = be * thetap;
		alpha[n] = -bf / x[0];
		w[n] = -be / x[0];
	}
	
	rr = x[0] * x[0] * thetap;
	
	for ( i = 1 ; i <= p ; ++ i ) beta[i] = -x[0] * thetap * gp[i];
	
	for ( n = p + 1 ; n < T ; ++ n ) {

		bf = x[n];
		for ( i = 1 ; i <= p ; ++ i ) bf = bf + x[n-i] * alpha[i]; // (6.10)

		f = bf * thetap; // (6.34)

		oldff = ff;
		
		ff = lambda * oldff + bf * f; // (6.38)
		
		theta = lambda * ( oldff / ff ) * thetap; // (6.39)
		
		g[1] = bf / ( lambda * oldff ); // (6.51)
		for ( i = 2 ; i <= p + 1 ; ++ i ) g[i] = gp[i-1] + g[1] * alpha[i-1];
		
		br = lambda * g[p+1] * rr; // (6.54)
		
		thetap = theta / ( 1 - g[p+1] * theta * br ); // (6.49)
		
		r = br * thetap; // (6.37)
		
		rr = lambda * rr + br * r; // (6.40)
		
		for ( i = 1 ; i <= p ; ++ i ) alpha[i] = alpha[i] - f * gp[i]; // (6.47)
		
		for ( i = 1 ; i <= p ; ++ i ) gp[i] = g[i] - g[p+1] * beta[i]; // (6.53)
		
		for ( i = 1 ; i <= p ; ++ i ) beta[i] = beta[i] - r * gp[i]; // (6.48)
		
		be = y[n];
		for ( i = 0 ; i <= p ; ++ i ) be = be + x[n-i] * w[i]; // (6.16)
		e = be * theta; // (6.22)
		
		for ( i = 0 ; i <= p ; ++ i ) w[i] = w[i] - e * g[i+1]; // (6.46)
	}
	printf("%lf\r\n", rr);
	return e;
}
