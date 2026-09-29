//
//  var.c
//  MUTE
//
//  Created by Kota on 11/13/25.
//
#include"module.h"
#include"var.h"
__attribute__((__visibility__("hidden")))
static simd_double2x2 const eye2 = {.columns={
    {1,0},
    {0,1}
}};
__attribute__((__visibility__("hidden")))
static simd_double3x3 const eye3 = {.columns={
    {1,0,0},
    {0,1,0},
    {0,0,1}
}};
__attribute__((__visibility__("hidden")))
static simd_double4x4 const eye4 = {.columns={
    {1,0,0,0},
    {0,1,0,0},
    {0,0,1,0},
    {0,0,0,1}
}};
// MARK: 1, forward and backward lsl
__attribute__((overloadable))
void var1(double const * __nonnull const X, intptr_t const ldX,
          double       * __nonnull const Y, intptr_t const ldY,
          double const * __nonnull const A,
          double const * __nonnull const B,
          double       * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t ) {
        register double f = fma(-*A, *S, X[t]);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = fma(f = fma(-A[k], S[k], f), B[k], S[k]);
        S[stage-1] = Y[t] = f;
    }
}
__attribute__((overloadable))
void var1(double const * __nonnull X, intptr_t const ldX,
          double       * __nonnull Y, intptr_t const ldY,
          double const * __nonnull A, intptr_t const ldA,
          double const * __nonnull B, intptr_t const ldB,
          double       * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t, ++ X, ++ Y, ++ A, ++ B ) {
        register double f = fma(-*A, *S, *X);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = fma(f = fma(-A[k*ldA], S[k], f), B[k*ldB], S[k]);
        S[stage-1] = *Y = f;
    }
}
__attribute__((always_inline))
var1_t * __nonnull const var1_create(intptr_t const m) {
    var1_t * __nonnull const object = __malloc__(sizeof(var1_t const) + ( m - 1 ) * sizeof(*object->stage));
    *(intptr_t*__nonnull const)&object->m = m;
    var1_reset(object, 1);
    return object;
}
__attribute__((always_inline))
void var1_destroy(var1_t * __nonnull const object) {
    __free__(object);
}
__attribute__((always_inline))
void var1_reset(var1_t * __nonnull const object, double const scale) {
    memset(object->stage, 0, object->m * sizeof(*object->stage));
    object->c = simd_precise_recip(scale);
}
__attribute__((always_inline))
void var1_lambda(var1_t * __nonnull const object, double const lambda) {
    *(double*__nonnull const)&object->lambda = lambda;
}
__attribute__((always_inline))
void var1_r(var1_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull E, intptr_t const ldE,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ E ) {
        register double
        f = *Y,
        r = object->c * f;
        register double
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = (object->c - r * r / fma(f, r, lambda)) / lambda,
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register double const q = stage[k].q;
            register double const Q = stage[k].Q;
            // D ← λD + θ * outer(f, q)
            stage[k].d = simd_dot((simd_double2 const) {lambda, theta}, (simd_double2 const) {stage[k].d, f * q});
            stage[k].q = r;
            stage[k].Q = R;
            //
            register double const
            // b = -F • D
            // a = -D • Q
            b = -F * stage[k].d,
            a = -stage[k].d * Q;
            // R ← Q • inv(eye(1) + D.T • B • Q)
            // F ← F • inv(eye(1) + A • D.T • F)
            R = Q / fma(stage[k].d * b, Q, 1),
            F = F / fma(a * stage[k].d, F, 1);
            // r ← f • b + q
            // f ← f + a • q
            r = fma(f, b, q);
            f = fma(q, a, f);
            // θ /= 1 - θ * q • Q • q
            theta /= fma(-theta, simd_clamp(q * Q * q, 0, 1), 1);
        }
        *E = f;
    }
}
void var1_p(var1_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull A, intptr_t const ldA,
            double       * __nonnull B, intptr_t const ldB,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ A, ++ B ) {
        register double
        f = *Y,
        r = object->c * f;
        register double
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = (object->c - r * r / fma(f, r, lambda)) / lambda,
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register double const q = stage[k].q;
            register double const Q = stage[k].Q;
            // D ← λD + θ * outer(f, q)
            stage[k].d = simd_dot((simd_double2 const) {lambda, theta}, (simd_double2 const) {stage[k].d, f * q});
            stage[k].q = r;
            stage[k].Q = R;
            //
            register double const
            // b = -F • D
            // a = -D • Q
            b = -F * stage[k].d,
            a = -stage[k].d * Q;
            // R ← Q • inv(eye(1) + D.T • B • Q)
            // F ← F • inv(eye(1) + A • D.T • F)
            R = Q / fma(stage[k].d * b, Q, 1),
            F = F / fma(a * stage[k].d, F, 1);
            // r ← f • b + q
            // f ← f + a • q
            r = fma(f, b, q);
            f = fma(q, a, f);
            // θ /= 1 - θ * q • Q • q
            theta /= fma(-theta, simd_clamp(q * Q * q, 0, 1), 1);
            //
            A[(K-k-1)*ldA] = a;
            //
            B[(K-k-1)*ldB] = b;
        }
    }
}
// MARK: 2
__attribute__((overloadable))
void var2(double const * __nonnull const X, intptr_t const ldX,
          double       * __nonnull const Y, intptr_t const ldY,
          simd_double2x2 const * __nonnull const A,
          simd_double2x2 const * __nonnull const B,
          simd_double2 * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t ) {
        register simd_double2 f = (simd_double2 const) {
            X[t+0*ldX],
            X[t+1*ldY],
        } - simd_mul(*A, *S);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = S[k] + simd_mul(f -= simd_mul(A[k], S[k]), B[k]);
        S[stage-1] = f;
        Y[t+0*ldY] = f[0];
        Y[t+1*ldY] = f[1];
    }
}
__attribute__((overloadable))
void var2(double const * __nonnull X, intptr_t const ldX,
          double       * __nonnull Y, intptr_t const ldY,
          double const * __nonnull A, intptr_t const ldA,
          double const * __nonnull B, intptr_t const ldB,
          simd_double2 * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t, ++ X, ++ Y, ++ A, ++ B ) {
        register simd_double2 f = (simd_double2 const) {
            X[0*ldX],
            X[1*ldY],
        } - simd_mul((simd_double2x2 const) {
            .columns={
                {A[0*ldA], A[1*ldA]},
                {A[2*ldA], A[3*ldA]}
            }
        }, *S);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = S[k] + simd_mul(f -= simd_mul((simd_double2x2 const) {
                .columns={
                    {A[(4*k+0)*ldA], A[(4*k+1)*ldA]},
                    {A[(4*k+2)*ldA], A[(4*k+3)*ldA]}
                }
            }, S[k]), (simd_double2x2 const) {
                .columns={
                    {B[(4*k+0)*ldB], B[(4*k+1)*ldB]},
                    {B[(4*k+2)*ldB], B[(4*k+3)*ldB]}
                }
            });
        S[stage-1] = f;
        Y[0*ldY] = f[0];
        Y[1*ldY] = f[1];
    }
}
__attribute__((always_inline))
var2_t * __nonnull const var2_create(intptr_t const m) {
    var2_t * __nonnull const object = __malloc__(sizeof(var2_t const) + ( m - 1 ) * sizeof(*object->stage));
    *(intptr_t*__nonnull const)&object->m = m;
    var2_reset(object, 1);
    return object;
}
__attribute__((always_inline))
void var2_destroy(var2_t * __nonnull const object) {
    __free__(object);
}
__attribute__((always_inline))
void var2_reset(var2_t * __nonnull const object, double const scale) {
    memset(object->stage, 0, object->m * sizeof(*object->stage));
    object->c = simd_div(eye2, scale);
}
__attribute__((always_inline))
void var2_lambda(var2_t * __nonnull const object, double const lambda) {
    *(double*__nonnull const)&object->lambda = lambda;
}
__attribute__((always_inline))
void var2_r(var2_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull E, intptr_t const ldE,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ E ) {
        register simd_double2
        f = {Y[0*ldY], Y[1*ldY]},
        r = simd_mul(object->c, f);
        register simd_double2x2
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = simd_div(simd_sub(object->c, simd_div(simd_outer(r, r), lambda + simd_dot(f, r))), lambda),
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register simd_double2 const q = stage[k].q;
            register simd_double2x2 const Q = stage[k].Q;
            // D ← λD - θ * outer(f, q)
            stage[k].d = simd_sub(simd_mul(lambda, stage[k].d), simd_mul(theta, simd_outer(f, q)));
            stage[k].q = r;
            stage[k].Q = R;
            //
            register simd_double2x2 const
            // b = F • D
            // a = D • Q
            b = simd_mul(F, stage[k].d),
            a = simd_mul(stage[k].d, Q);
            // R ← Q • inv(eye(2) - D.T • B • Q)
            // F ← F • inv(eye(2) - A • D.T • F)
            R = simd_mul(Q, simd_inverse(simd_sub(eye2, simd_mul(simd_mul(simd_transpose(stage[k].d), b), Q)))),
            F = simd_mul(F, simd_inverse(simd_sub(eye2, simd_mul(simd_mul(a, simd_transpose(stage[k].d)), F))));
            // r ← f • b + q
            // f ← f + a • q
            r = simd_mul(f, b) + q;
            f = f + simd_mul(a, q);
            // θ /= 1 - θ * q • Q • q
            theta /= fma(-theta, simd_clamp(simd_dot(q, simd_mul(Q, q)), 0, 1), 1);
        }
        E[0*ldE] = f[0];
        E[1*ldE] = f[1];
    }
}
void var2_p(var2_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull A, intptr_t const ldA,
            double       * __nonnull B, intptr_t const ldB,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ A, ++ B ) {
        register simd_double2
        f = {Y[0*ldY], Y[1*ldY]},
        r = simd_mul(object->c, f);
        register simd_double2x2
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = simd_div(simd_sub(object->c, simd_div(simd_outer(r, r), lambda + simd_dot(f, r))), lambda),
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register simd_double2 const q = stage[k].q;
            register simd_double2x2 const Q = stage[k].Q;
            // D ← λD - θ * outer(f, q)
            stage[k].d = simd_sub(simd_mul(lambda, stage[k].d), simd_mul(theta, simd_outer(f, q)));
            stage[k].q = r;
            stage[k].Q = R;
            //
            register simd_double2x2 const
            // b = F • D
            // a = D • Q
            b = simd_mul(F, stage[k].d),
            a = simd_mul(stage[k].d, Q);
            // R ← Q • inv(eye(2) - D.T • B • Q)
            // F ← F • inv(eye(2) - A • D.T • F)
            R = simd_mul(Q, simd_inverse(simd_sub(eye2, simd_mul(simd_mul(simd_transpose(stage[k].d), b), Q)))),
            F = simd_mul(F, simd_inverse(simd_sub(eye2, simd_mul(simd_mul(a, simd_transpose(stage[k].d)), F))));
            // r ← f • b + q
            // f ← f + a • q
            r = simd_mul(f, b) + q;
            f = f + simd_mul(a, q);
            // θ /= 1 - θ * q • Q • q
            theta /= fma(-theta, simd_clamp(simd_dot(q, simd_mul(Q, q)), 0, 1), 1);
            //
            A[(4*(K-k-1)+0)*ldA] = a.columns[0][0];
            A[(4*(K-k-1)+1)*ldA] = a.columns[0][1];
            A[(4*(K-k-1)+2)*ldA] = a.columns[1][0];
            A[(4*(K-k-1)+3)*ldA] = a.columns[1][1];
            //
            B[(4*(K-k-1)+0)*ldB] = b.columns[0][0];
            B[(4*(K-k-1)+1)*ldB] = b.columns[0][1];
            B[(4*(K-k-1)+2)*ldB] = b.columns[1][0];
            B[(4*(K-k-1)+3)*ldB] = b.columns[1][1];
        }
    }
}
// MARK: 3
__attribute__((overloadable))
void var3(double const * __nonnull const X, intptr_t const ldX,
          double       * __nonnull const Y, intptr_t const ldY,
          simd_double3x3 const * __nonnull const A,
          simd_double3x3 const * __nonnull const B,
          simd_double3 * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t ) {
        register simd_double3 f = (simd_double3 const) {
            X[t+0*ldX],
            X[t+1*ldY],
            X[t+2*ldY],
        } - simd_mul(*A, *S);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = S[k] + simd_mul(f -= simd_mul(A[k], S[k]), B[k]);
        S[stage-1] = f;
        Y[t+0*ldY] = f[0];
        Y[t+1*ldY] = f[1];
        Y[t+2*ldY] = f[2];
    }
}
__attribute__((overloadable))
void var3(double const * __nonnull X, intptr_t const ldX,
          double       * __nonnull Y, intptr_t const ldY,
          double const * __nonnull A, intptr_t const ldA,
          double const * __nonnull B, intptr_t const ldB,
          simd_double3 * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t, ++ X, ++ Y, ++ A, ++ B ) {
        register simd_double3 f = (simd_double3 const) {
            X[0*ldX],
            X[1*ldY],
            X[2*ldY],
        } - simd_mul((simd_double3x3 const) {
            .columns={
                {A[0*ldA], A[1*ldA], A[2*ldA]},
                {A[3*ldA], A[4*ldA], A[5*ldA]},
                {A[6*ldA], A[7*ldA], A[8*ldA]},
            }
        }, *S);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = S[k] + simd_mul(f -= simd_mul((simd_double3x3 const) {
                .columns={
                    {A[(9*k+0)*ldA], A[(9*k+1)*ldA], A[(9*k+2)*ldA]},
                    {A[(9*k+3)*ldA], A[(9*k+4)*ldA], A[(9*k+5)*ldA]},
                    {A[(9*k+6)*ldA], A[(9*k+7)*ldA], A[(9*k+8)*ldA]},
                }
            }, S[k]), (simd_double3x3 const) {
                .columns={
                    {B[(9*k+0)*ldB], B[(9*k+1)*ldB], B[(9*k+2)*ldB]},
                    {B[(9*k+3)*ldB], B[(9*k+4)*ldB], B[(9*k+5)*ldB]},
                    {B[(9*k+6)*ldB], B[(9*k+7)*ldB], B[(9*k+8)*ldB]},
                }
            });
        S[stage-1] = f;
        Y[0*ldY] = f[0];
        Y[1*ldY] = f[1];
        Y[2*ldY] = f[2];
    }
}
__attribute__((always_inline))
var3_t * __nonnull const var3_create(intptr_t const m) {
    var3_t * __nonnull const object = __malloc__(sizeof(var3_t const) + ( m - 1 ) * sizeof(*object->stage));
    *(intptr_t*__nonnull const)&object->m = m;
    var3_reset(object, 1);
    return object;
}
__attribute__((always_inline))
void var3_destroy(var3_t * __nonnull const object) {
    __free__(object);
}
__attribute__((always_inline))
void var3_reset(var3_t * __nonnull const object, double const scale) {
    memset(object->stage, 0, object->m * sizeof(*object->stage));
    object->c = simd_div(eye3, scale);
}
__attribute__((always_inline))
void var3_lambda(var3_t * __nonnull const object, double const lambda) {
    *(double*__nonnull const)&object->lambda = lambda;
}
__attribute__((always_inline))
void var3_r(var3_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull E, intptr_t const ldE,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ E ) {
        register simd_double3
        f = {Y[0*ldY], Y[1*ldY], Y[2*ldY]},
        r = simd_mul(object->c, f);
        register simd_double3x3
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = simd_div(simd_sub(object->c, simd_div(simd_outer(r, r), lambda + simd_dot(f, r))), lambda),
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register simd_double3 const q = stage[k].q;
            register simd_double3x3 const Q = stage[k].Q;
            // D ← λD - θ * outer(f, q)
            stage[k].d = simd_sub(simd_mul(lambda, stage[k].d), simd_mul(theta, simd_outer(f, q)));
            stage[k].q = r;
            stage[k].Q = R;
            //
            register simd_double3x3 const
            // b = F • D
            // a = D • Q
            b = simd_mul(F, stage[k].d),
            a = simd_mul(stage[k].d, Q);
            // R ← Q • inv(eye(3) - D.T • B • Q)
            // F ← F • inv(eye(3) - A • D.T • F)
            R = simd_mul(Q, simd_inverse(simd_sub(eye3, simd_mul(simd_mul(simd_transpose(stage[k].d), b), Q)))),
            F = simd_mul(F, simd_inverse(simd_sub(eye3, simd_mul(simd_mul(a, simd_transpose(stage[k].d)), F))));
            // r ← f • b + q
            // f ← f + a • q
            r = simd_mul(f, b) + q;
            f = f + simd_mul(a, q);
            // θ /= 1 - θ * q • Q • q
            theta /= fma(-theta, simd_clamp(simd_dot(q, simd_mul(Q, q)), 0, 1), 1);
        }
        E[0*ldE] = f[0];
        E[1*ldE] = f[1];
        E[2*ldE] = f[2];
    }
}
void var3_p(var3_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull A, intptr_t const ldA,
            double       * __nonnull B, intptr_t const ldB,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ A, ++ B ) {
        register simd_double3
        f = {Y[0*ldY], Y[1*ldY], Y[2*ldY]},
        r = simd_mul(object->c, f);
        register simd_double3x3
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = simd_div(simd_sub(object->c, simd_div(simd_outer(r, r), lambda + simd_dot(f, r))), lambda),
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register simd_double3 const q = stage[k].q;
            register simd_double3x3 const Q = stage[k].Q;
            // D ← λD - θ * outer(f, q)
            stage[k].d = simd_sub(simd_mul(lambda, stage[k].d), simd_mul(theta, simd_outer(f, q)));
            stage[k].q = r;
            stage[k].Q = R;
            //
            register simd_double3x3 const
            // b = F • D
            // a = D • Q
            b = simd_mul(F, stage[k].d),
            a = simd_mul(stage[k].d, Q);
            // R ← Q • inv(eye(3) - D.T • B • Q)
            // F ← F • inv(eye(3) - A • D.T • F)
            R = simd_mul(Q, simd_inverse(simd_sub(eye3, simd_mul(simd_mul(simd_transpose(stage[k].d), b), Q)))),
            F = simd_mul(F, simd_inverse(simd_sub(eye3, simd_mul(simd_mul(a, simd_transpose(stage[k].d)), F))));
            // r ← f • b + q
            // f ← f + a • q
            r = simd_mul(f, b) + q;
            f = f + simd_mul(a, q);
            // θ /= 1 - θ * q • Q • q
            theta /= fma(-theta, simd_clamp(simd_dot(q, simd_mul(Q, q)), 0, 1), 1);
            //
            A[(9*(K-k-1)+0)*ldA] = a.columns[0][0];
            A[(9*(K-k-1)+1)*ldA] = a.columns[0][1];
            A[(9*(K-k-1)+2)*ldA] = a.columns[0][2];
            A[(9*(K-k-1)+3)*ldA] = a.columns[1][0];
            A[(9*(K-k-1)+4)*ldA] = a.columns[1][1];
            A[(9*(K-k-1)+5)*ldA] = a.columns[1][2];
            A[(9*(K-k-1)+6)*ldA] = a.columns[2][0];
            A[(9*(K-k-1)+7)*ldA] = a.columns[2][1];
            A[(9*(K-k-1)+8)*ldA] = a.columns[2][2];
            //
            B[(9*(K-k-1)+0)*ldB] = b.columns[0][0];
            B[(9*(K-k-1)+1)*ldB] = b.columns[0][1];
            B[(9*(K-k-1)+2)*ldB] = b.columns[0][2];
            B[(9*(K-k-1)+3)*ldB] = b.columns[1][0];
            B[(9*(K-k-1)+4)*ldB] = b.columns[1][1];
            B[(9*(K-k-1)+5)*ldB] = b.columns[1][2];
            B[(9*(K-k-1)+6)*ldB] = b.columns[2][0];
            B[(9*(K-k-1)+7)*ldB] = b.columns[2][1];
            B[(9*(K-k-1)+8)*ldB] = b.columns[2][2];
        }
    }
}
// MARK: 4
__attribute__((overloadable))
void var4(double const * __nonnull const X, intptr_t const ldX,
          double       * __nonnull const Y, intptr_t const ldY,
          simd_double4x4 const * __nonnull const A,
          simd_double4x4 const * __nonnull const B,
          simd_double4 * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t ) {
        register simd_double4 f = (simd_double4 const) {
            X[t+0*ldX],
            X[t+1*ldY],
            X[t+2*ldY],
            X[t+3*ldY],
        } - simd_mul(*A, *S);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = S[k] + simd_mul(f -= simd_mul(A[k], S[k]), B[k]);
        S[stage-1] = f;
        Y[t+0*ldY] = f[0];
        Y[t+1*ldY] = f[1];
        Y[t+2*ldY] = f[2];
        Y[t+3*ldY] = f[3];
    }
}
__attribute__((overloadable))
void var4(double const * __nonnull X, intptr_t const ldX,
          double       * __nonnull Y, intptr_t const ldY,
          double const * __nonnull A, intptr_t const ldA,
          double const * __nonnull B, intptr_t const ldB,
          simd_double4 * __nonnull const S,
          intptr_t const stage, intptr_t const count) {
    for ( register intptr_t t = 0, T = count ; t < T ; ++ t, ++ X, ++ Y, ++ A, ++ B ) {
        register simd_double4 f = (simd_double4 const) {
            X[0*ldX],
            X[1*ldY],
            X[2*ldY],
            X[3*ldY],
        } - simd_mul((simd_double4x4 const) {
            .columns={
                {A[0x0*ldA], A[0x1*ldA], A[0x2*ldA], A[0x3*ldA]},
                {A[0x4*ldA], A[0x5*ldA], A[0x6*ldA], A[0x7*ldA]},
                {A[0x8*ldA], A[0x9*ldA], A[0xa*ldA], A[0xb*ldA]},
                {A[0xc*ldA], A[0xd*ldA], A[0xe*ldA], A[0xf*ldA]},
            }
        }, *S);
        for ( register intptr_t k = 1, K = stage ; k < K ; ++ k )
            S[k-1] = S[k] + simd_mul(f -= simd_mul((simd_double4x4 const) {
                .columns={
                    {A[(0x10*k+0x0)*ldA], A[(0x10*k+0x1)*ldA], A[(0x10*k+0x2)*ldA], A[(0x10*k+0x3)*ldA]},
                    {A[(0x10*k+0x4)*ldA], A[(0x10*k+0x5)*ldA], A[(0x10*k+0x6)*ldA], A[(0x10*k+0x7)*ldA]},
                    {A[(0x10*k+0x8)*ldA], A[(0x10*k+0x9)*ldA], A[(0x10*k+0xa)*ldA], A[(0x10*k+0xb)*ldA]},
                    {A[(0x10*k+0xc)*ldA], A[(0x10*k+0xd)*ldA], A[(0x10*k+0xe)*ldA], A[(0x10*k+0xf)*ldA]},
                }
            }, S[k]), (simd_double4x4 const) {
                .columns={
                    {B[(0x10*k+0x0)*ldB], B[(0x10*k+0x1)*ldB], B[(0x10*k+0x2)*ldB], B[(0x10*k+0x3)*ldB]},
                    {B[(0x10*k+0x4)*ldB], B[(0x10*k+0x5)*ldB], B[(0x10*k+0x6)*ldB], B[(0x10*k+0x7)*ldB]},
                    {B[(0x10*k+0x8)*ldB], B[(0x10*k+0x9)*ldB], B[(0x10*k+0xa)*ldB], B[(0x10*k+0xb)*ldB]},
                    {B[(0x10*k+0xc)*ldB], B[(0x10*k+0xd)*ldB], B[(0x10*k+0xe)*ldB], B[(0x10*k+0xf)*ldB]},
                }
            });
        S[stage-1] = f;
        Y[0*ldY] = f[0];
        Y[1*ldY] = f[1];
        Y[2*ldY] = f[2];
        Y[3*ldY] = f[3];
    }
}
__attribute__((always_inline))
var4_t * __nonnull const var4_create(intptr_t const m) {
    var4_t * __nonnull const object = __malloc__(sizeof(var4_t const) + ( m - 1 ) * sizeof(*object->stage));
    *(intptr_t*__nonnull const)&object->m = m;
    var4_reset(object, 1);
    return object;
}
__attribute__((always_inline))
void var4_destroy(var4_t * __nonnull const object) {
    __free__(object);
}
__attribute__((always_inline))
void var4_reset(var4_t * __nonnull const object, double const scale) {
    memset(object->stage, 0, object->m * sizeof(*object->stage));
    object->c = simd_div(eye4, scale);
}
__attribute__((always_inline))
void var4_lambda(var4_t * __nonnull const object, double const lambda) {
    *(double*__nonnull const)&object->lambda = lambda;
}
__attribute__((always_inline))
void var4_r(var4_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull E, intptr_t const ldE,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ E ) {
        register simd_double4
        f = {Y[0*ldY], Y[1*ldY], Y[2*ldY], Y[3*ldY]},
        r = simd_mul(object->c, f);
        register simd_double4x4
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = simd_div(simd_sub(object->c, simd_div(simd_outer(r, r), lambda + simd_dot(f, r))), lambda),
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register simd_double4 const q = stage[k].q;
            register simd_double4x4 const Q = stage[k].Q;
            // D ← λD - θ * outer(f, q)
            stage[k].d = simd_sub(simd_mul(lambda, stage[k].d), simd_mul(theta, simd_outer(f, q)));
            stage[k].q = r;
            stage[k].Q = R;
            //
            register simd_double4x4 const
            // b = F • D
            // a = D • Q
            b = simd_mul(F, stage[k].d),
            a = simd_mul(stage[k].d, Q);
            // R ← Q • inv(eye(4) - D.T • B • Q)
            // F ← F • inv(eye(4) - A • D.T • F)
            R = simd_mul(Q, simd_inverse(simd_sub(eye4, simd_mul(simd_mul(simd_transpose(stage[k].d), b), Q)))),
            F = simd_mul(F, simd_inverse(simd_sub(eye4, simd_mul(simd_mul(a, simd_transpose(stage[k].d)), F))));
            // r ← f • b + q
            // f ← f + a • q
            r = simd_mul(f, b) + q;
            f = f + simd_mul(a, q);
            // θ /= 1 - θ * q • Q • q
            theta /= fma(-theta, simd_clamp(simd_dot(q, simd_mul(Q, q)), 0, 1), 1);
        }
        E[0*ldE] = f[0];
        E[1*ldE] = f[1];
        E[2*ldE] = f[2];
        E[3*ldE] = f[3];
    }
}
void var4_p(var4_t * __nonnull const object,
            double const * __nonnull Y, intptr_t const ldY,
            double       * __nonnull A, intptr_t const ldA,
            double       * __nonnull B, intptr_t const ldB,
            intptr_t const length) {
    register double const lambda = object->lambda;
    register typeof(*object->stage) * __nonnull const stage = object->stage;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ A, ++ B ) {
        register simd_double4
        f = {Y[0*ldY], Y[1*ldY], Y[2*ldY], Y[3*ldY]},
        r = simd_mul(object->c, f);
        register simd_double4x4
        // c ← ( c - outer(c • f, r • c) / ( lr + f • c • r ) ) / lr
        F = simd_div(simd_sub(object->c, simd_div(simd_outer(r, r), lambda + simd_dot(f, r))), lambda),
        R = object->c = F;
        r = f;
        register double theta = 1;
        for ( register intptr_t k = 0, K = object->m ; k < K ; ++ k ) {
            register simd_double4 const q = stage[k].q;
            register simd_double4x4 const Q = stage[k].Q;
            // D ← λD - θ * outer(f, q)
            stage[k].d = simd_sub(simd_mul(lambda, stage[k].d), simd_mul(theta, simd_outer(f, q)));
            stage[k].q = r;
            stage[k].Q = R;
            //
            register simd_double4x4 const
            // b = F • D
            // a = D • Q
            b = simd_mul(F, stage[k].d),
            a = simd_mul(stage[k].d, Q);
            // R ← Q • inv(eye(4) - D.T • B • Q)
            // F ← F • inv(eye(4) - A • D.T • F)
            R = simd_mul(Q, simd_inverse(simd_sub(eye4, simd_mul(simd_mul(simd_transpose(stage[k].d), b), Q)))),
            F = simd_mul(F, simd_inverse(simd_sub(eye4, simd_mul(simd_mul(a, simd_transpose(stage[k].d)), F))));
            // r ← f • b + q
            // f ← f + a • q
            r = simd_mul(f, b) + q;
            f = f + simd_mul(a, q);
            // θ /= 1 - θ * • Q • q
            theta /= fma(-theta, simd_clamp(simd_dot(q, simd_mul(Q, q)), 0, 1), 1);
            //
            A[(0x10*(K-k-1)+0x0)*ldA] = a.columns[0][0];
            A[(0x10*(K-k-1)+0x1)*ldA] = a.columns[0][1];
            A[(0x10*(K-k-1)+0x2)*ldA] = a.columns[0][2];
            A[(0x10*(K-k-1)+0x3)*ldA] = a.columns[0][3];
            A[(0x10*(K-k-1)+0x4)*ldA] = a.columns[1][0];
            A[(0x10*(K-k-1)+0x5)*ldA] = a.columns[1][1];
            A[(0x10*(K-k-1)+0x6)*ldA] = a.columns[1][2];
            A[(0x10*(K-k-1)+0x7)*ldA] = a.columns[1][3];
            A[(0x10*(K-k-1)+0x8)*ldA] = a.columns[2][0];
            A[(0x10*(K-k-1)+0x9)*ldA] = a.columns[2][1];
            A[(0x10*(K-k-1)+0xa)*ldA] = a.columns[2][2];
            A[(0x10*(K-k-1)+0xb)*ldA] = a.columns[2][3];
            A[(0x10*(K-k-1)+0xc)*ldA] = a.columns[3][0];
            A[(0x10*(K-k-1)+0xd)*ldA] = a.columns[3][1];
            A[(0x10*(K-k-1)+0xe)*ldA] = a.columns[3][2];
            A[(0x10*(K-k-1)+0xf)*ldA] = a.columns[3][3];
            
            //
            B[(0x10*(K-k-1)+0x0)*ldB] = b.columns[0][0];
            B[(0x10*(K-k-1)+0x1)*ldB] = b.columns[0][1];
            B[(0x10*(K-k-1)+0x2)*ldB] = b.columns[0][2];
            B[(0x10*(K-k-1)+0x3)*ldB] = b.columns[0][3];
            B[(0x10*(K-k-1)+0x4)*ldB] = b.columns[1][0];
            B[(0x10*(K-k-1)+0x5)*ldB] = b.columns[1][1];
            B[(0x10*(K-k-1)+0x6)*ldB] = b.columns[1][2];
            B[(0x10*(K-k-1)+0x7)*ldB] = b.columns[1][3];
            B[(0x10*(K-k-1)+0x8)*ldB] = b.columns[2][0];
            B[(0x10*(K-k-1)+0x9)*ldB] = b.columns[2][1];
            B[(0x10*(K-k-1)+0xa)*ldB] = b.columns[2][2];
            B[(0x10*(K-k-1)+0xb)*ldB] = b.columns[2][3];
            B[(0x10*(K-k-1)+0xc)*ldB] = b.columns[3][0];
            B[(0x10*(K-k-1)+0xd)*ldB] = b.columns[3][1];
            B[(0x10*(K-k-1)+0xe)*ldB] = b.columns[3][2];
            B[(0x10*(K-k-1)+0xf)*ldB] = b.columns[3][3];
        }
    }
}
// MARK: N
__attribute__((overloadable))
void var(double const * __nonnull X, intptr_t const ldX,
         double       * __nonnull Y, intptr_t const ldY,
         double const * __nonnull const A, intptr_t const ldA, intptr_t const lmA,
         double const * __nonnull const B, intptr_t const ldB, intptr_t const lmB,
         double       * __nonnull const Z, // require size * stage
         intptr_t const n, intptr_t const m, intptr_t const length) {
    static intptr_t const inc = 1;
    static double const minus = -1, plus = 1;
    if ( X != Y || ldX != ldY )
        for ( register intptr_t k = 0, K = n ; k < K ; ++ k )
            dcopy_(&length, X + k * ldX, &inc, Y + k * ldY, &inc);
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ X, ++ Y ) {
        dgemv_("N",
               &n, &n,
               &minus,
               A, &ldA,
               Z, &inc,
               &plus,
               Y, &ldY);
        for ( register intptr_t k = 1, K = m ; k < K ; ++ k ) {
            // f ← f - a • r[k]
            dgemv_("N",
                   &n, &n,
                   &minus,
                   A + k * lmA, &ldA,
                   Z + k * n, &inc,
                   &plus,
                   Y, &ldY);
            // r[k-1] ← f • b + r[k]
            dgemv_("T",
                   &n, &n,
                   &plus,
                   B + k * lmB, &ldB,
                   Y, &ldY,
                   &plus,
                   memcpy(Z + k * n - n, Z + k * n, n * sizeof(double const)), &inc);
        }
        dcopy_(&n, Y, &ldY, Z + m * n - n, &inc);
    }
}
__attribute__((overloadable))
void var(double const * __nonnull X, intptr_t const ldX,
         double       * __nonnull Y, intptr_t const ldY,
         double const * __nonnull A, intptr_t const ldA,
         double const * __nonnull B, intptr_t const ldB,
         double       * __nonnull const Z, // require size * stage
         double       * __nullable const W, // require size * size
         intptr_t const n, intptr_t const m, intptr_t const length) {
    static intptr_t const inc = 1;
    static double const minus = -1, plus = 1;
    if ( X != Y || ldX != ldY )
        for ( register intptr_t k = 0, K = n ; k < K ; ++ k )
            dcopy_(&length, X + k * ldX, &inc, Y + k * ldY, &inc);
    if ( !W )
        *(double const*__nullable*__nonnull const)&W = alloca(n * n * sizeof(double const));
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ X, ++ Y, ++ A, ++ B ) {
        for ( register intptr_t c = 0, C = n ; c < C ; ++ c )
            dcopy_(&n, A + c * n * ldA, &ldA, W + c * n, &inc);
        dgemv_("N",
               &n, &n,
               &minus,
               W, &n,
               Z, &inc,
               &plus,
               Y, &ldY);
        for ( register intptr_t k = 1, K = m ; k < K ; ++ k ) {
            // f ← f - a • r[k+1]
            for ( register intptr_t c = 0, C = n ; c < C ; ++ c )
                dcopy_(&n, A + ( k * n + c ) * n * ldA, &ldA, W + c * n, &inc);
            dgemv_("N",
                   &n, &n,
                   &minus,
                   W, &n,
                   Z + k * n, &inc,
                   &plus,
                   Y, &ldY);
            // r[k-1] ← f • b + r[k]
            for ( register intptr_t c = 0, C = n ; c < C ; ++ c )
                dcopy_(&n, B + ( k * n + c ) * n * ldB, &ldB, W + c * n, &inc);
            dgemv_("T",
                   &n, &n,
                   &plus,
                   W, &n,
                   Y, &ldY,
                   &plus,
                   memcpy(Z + k * n - n, Z + k * n, n * sizeof(double const)), &inc);
        }
        dcopy_(&n, Y, &ldY, Z + m * n - n, &inc);
    }
}
var_t * __nonnull const var_create(intptr_t const n, intptr_t const m) {
    void * __nonnull const memory = __malloc__((n * n +
                                                m * n * n +
                                                m * n +
                                                m * n * n +
                                                n * n +
                                                n * n +
                                                n * n +
                                                n +
                                                n +
                                                n +
                                                n * n) * sizeof(double const)
                                               + n * sizeof(intptr_t const)
                                               + sizeof(var_t const));
    var_t * __nonnull const object = memory;
    *(intptr_t*__nonnull const)&object->n = n;
    *(intptr_t*__nonnull const)&object->m = m;
    *(double*__nonnull*__nonnull const)&object->C = memory + sizeof(var_t const);
    *(double*__nonnull*__nonnull const)&object->D = object->C + n * n;
    *(double*__nonnull*__nonnull const)&object->z = object->D + m * n * n;
    *(double*__nonnull*__nonnull const)&object->Z = object->z + m * n;
    *(double*__nonnull*__nonnull const)&object->F = object->Z + m * n * n;
    *(double*__nonnull*__nonnull const)&object->R = object->F + n * n;
    *(double*__nonnull*__nonnull const)&object->Q = object->R + n * n;
    *(double*__nonnull*__nonnull const)&object->f = object->Q + n * n;
    *(double*__nonnull*__nonnull const)&object->r = object->f + n;
    *(double*__nonnull*__nonnull const)&object->q = object->r + n;
    *(double*__nonnull*__nonnull const)&object->P = object->q + n;
    *(double*__nonnull*__nonnull const)&object->p = object->P + n * n;
    var_reset(object, 1);
    return object;
}
void var_destroy(var_t * __nonnull const object) {
    __free__(object);
}
void var_reset(var_t * __nonnull const object, double const scale) {
    double const _[] = {0, simd_precise_recip(scale)};
    dlaset_("G", &object->n, &object->n, _ + 0, _ + 1, object->C, &object->n);
    __clr__(object->D, 1, object->m * object->n * object->n);
    __clr__(object->z, 1, object->m * object->n);
    __clr__(object->Z, 1, object->m * object->n * object->n);
}
void var_lambda(var_t * __nonnull const object, double const lambda) {
    *(double*__nonnull const)&object->lambda = lambda;
}
void var_r(var_t * __nonnull const object,
           double const * __nonnull Y, intptr_t const ldY,
           double       * __nonnull E, intptr_t const ldE,
           intptr_t const length) {
    static intptr_t const inc = 1;
    static double const minus = -1, zero = 0, one = 1;
    intptr_t const n = object->n;
    intptr_t const m = object->m;
    double const lambda = object->lambda;
    register double * __nonnull const f = object->f;
    register double * __nonnull const r = object->r;
    register double * __nonnull const q = object->q;
    register double * __nonnull const F = object->F;
    register double * __nonnull const R = object->R;
    register double * __nonnull const Q = object->Q;
    register double * __nonnull const P = object->P;
    register intptr_t * __nonnull const p = object->p;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ E ) {
        intptr_t info = 0;
        // c ← ( c - outer(x, x) / σ ) / λ
        dcopy_(&n, Y, &ldY, f, &inc);
        dsymv_("L",
               &n,
               &one,
               object->C, &n,
               f, &inc,
               &zero,
               r, &inc);
        dscal_(&n, (double const[]) { simd_precise_rsqrt(lambda + ddot_(&n, f, &inc, r, &inc)) }, r, &inc);
        dger_(&n, &n,
              &minus,
              r, &inc,
              r, &inc,
              object->C, &n);
        dlascl_("G", &info, &info,
                &lambda, &one,
                &n, &n,
                object->C, &n,
                &info);
        assert(!info);
        memcpy(F, object->C, n * n * sizeof(double const));
        memcpy(R, object->C, n * n * sizeof(double const));
        memcpy(r, f, n * sizeof(double const));
        double theta = 1;
        for ( register intptr_t k = 0, K = m ; k < K ; ++ k ) {
            register double * __nonnull const z = object->z + k * n;
            register double * __nonnull const Z = object->Z + k * n * n;
            register double * __nonnull const D = object->D + k * n * n;
            memcpy(q, z, 1 * n * sizeof(double const));
            memcpy(Q, Z, n * n * sizeof(double const));
            memcpy(z, r, 1 * n * sizeof(double const));
            memcpy(Z, R, n * n * sizeof(double const));
            // D ← λD + θ * outer(f, q)
            dlascl_("G",
                    &info, &info,
                    &one, &lambda,
                    &n, &n,
                    D, &n,
                    &info);
            assert(!info);
            dger_(&n, &n,
                  &theta,
                  f, &inc,
                  q, &inc,
                  D, &n);
            
            // θ /= 1 - θ * q • Q • q
            dgemv_("N",
                   &n, &n,
                   &one,
                   Q, &n,
                   q, &inc,
                   &zero,
                   r, &inc);
            theta /= fma(-theta, simd_clamp(ddot_(&n, q, &inc, r, &inc), 0, 1), 1);
            
            // b = -F • D
            dgemm_("N", "N",
                   &n, &n, &n,
                   &minus,
                   F, &n,
                   D, &n,
                   &zero,
                   P, &n);
            
            // r ← f • b + q = b.T • f + q
            dgemv_("T",
                   &n, &n,
                   &one,
                   P, &n,
                   f, &inc,
                   &one,
                   memcpy(r, q, n * sizeof(double const)), &inc);
            
            // R ← Q • inv(eye(n) + D.T • B • Q) = solve(eye(n) + Q.T • B.T • D, Q) = solve((eye(n) + (D.T • B) • Q).T, Q)
            dgemm_("T", "N",
                   &n, &n, &n,
                   &one,
                   D, &n,
                   P, &n,
                   &zero,
                   R, &n);
            dlaset_("G",
                    &n, &n,
                    &zero, &one,
                    P, &n);
            dgemm_("N", "N",
                   &n, &n, &n,
                   &one,
                   R, &n,
                   Q, &n,
                   &one,
                   P, &n);
            dgetrf_(&n, &n,
                    P, &n, p,
                    &info);
            assert(!info);
            dgetrs_("T",
                    &n, &n,
                    P, &n, p,
                    memcpy(R, Q, n * n * sizeof(double const)), &n,
                    &info);
            assert(!info);
            
            // a = -D • Q
            dgemm_("N", "N",
                   &n, &n, &n,
                   &minus,
                   D, &n,
                   Q, &n,
                   &zero,
                   P, &n);
            
            // f ← f + a • q
            dgemv_("N",
                   &n, &n,
                   &one,
                   P, &n,
                   q, &inc,
                   &one,
                   f, &inc);
            
            // F ← F • inv(eye(n) + A • D.T • F) = solve(eye(n) + F.T • D • A.T, F) = solve((eye(n) + (A • D.T) • F).T, F)
            dgemm_("N", "T",
                   &n, &n, &n,
                   &one,
                   P, &n,
                   D, &n,
                   &zero,
                   Q, &n);
            dlaset_("G",
                    &n, &n,
                    &zero, &one,
                    P, &n);
            dgemm_("N", "N",
                   &n, &n, &n,
                   &one,
                   Q, &n,
                   F, &n,
                   &one,
                   P, &n);
            dgetrf_(&n, &n,
                    P, &n, p,
                    &info);
            assert(!info);
            dgetrs_("T",
                    &n, &n,
                    P, &n, p,
                    F, &n,
                    &info);
            assert(!info);
            
        }
        dcopy_(&n, f, &inc, E, &ldE);
    }
}
void var_p(var_t * __nonnull const object,
           double const * __nonnull Y, intptr_t const ldY,
           double       * __nonnull A, intptr_t const ldA,
           double       * __nonnull B, intptr_t const ldB,
           intptr_t const length) {
    static intptr_t const inc = 1;
    static double const minus = -1, zero = 0, one = 1;
    intptr_t const n = object->n;
    intptr_t const m = object->m;
    double const lambda = object->lambda;
    register double * __nonnull const f = object->f;
    register double * __nonnull const r = object->r;
    register double * __nonnull const q = object->q;
    register double * __nonnull const F = object->F;
    register double * __nonnull const R = object->R;
    register double * __nonnull const Q = object->Q;
    register double * __nonnull const P = object->P;
    register intptr_t * __nonnull const p = object->p;
    for ( register intptr_t t = 0, T = length ; t < T ; ++ t, ++ Y, ++ A, ++ B ) {
        intptr_t info = 0;
        // c ← ( c - outer(x, x) / σ ) / λ
        dcopy_(&n, Y, &ldY, f, &inc);
        dsymv_("L",
               &n,
               &one,
               object->C, &n,
               f, &inc,
               &zero,
               r, &inc);
        dscal_(&n, (double const[]) { simd_precise_rsqrt(lambda + ddot_(&n, f, &inc, r, &inc)) }, r, &inc);
        dger_(&n, &n,
              &minus,
              r, &inc,
              r, &inc,
              object->C, &n);
        dlascl_("G", &info, &info,
                &lambda, &one,
                &n, &n,
                object->C, &n,
                &info);
        assert(!info);
        memcpy(F, object->C, n * n * sizeof(double const));
        memcpy(R, object->C, n * n * sizeof(double const));
        memcpy(r, f, n * sizeof(double const));
        double theta = 1;
        for ( register intptr_t k = 0, K = m ; k < K ; ++ k ) {
            register double * __nonnull const z = object->z + k * n;
            register double * __nonnull const Z = object->Z + k * n * n;
            register double * __nonnull const D = object->D + k * n * n;
            memcpy(q, z, 1 * n * sizeof(double const));
            memcpy(Q, Z, n * n * sizeof(double const));
            memcpy(z, r, 1 * n * sizeof(double const));
            memcpy(Z, R, n * n * sizeof(double const));
            // D ← λD + θ * outer(f, q)
            dlascl_("G",
                    &info, &info,
                    &one, &lambda,
                    &n, &n,
                    D, &n,
                    &info);
            assert(!info);
            dger_(&n, &n,
                  &theta,
                  f, &inc,
                  q, &inc,
                  D, &n);
            
            // θ /= 1 - θ * q • Q • q
            dgemv_("N",
                   &n, &n,
                   &one,
                   Q, &n,
                   q, &inc,
                   &zero,
                   r, &inc);
            theta /= fma(-theta, simd_clamp(ddot_(&n, q, &inc, r, &inc), 0, 1), 1);
            
            // b = -F • D
            dgemm_("N", "N",
                   &n, &n, &n,
                   &minus,
                   F, &n,
                   D, &n,
                   &zero,
                   P, &n);
            for ( register intptr_t c = 0, C = n ; c < C ; ++ c )
                dcopy_(&n, P + c * n, &inc, B + ( ( m - k - 1 ) * n + c ) * n * ldB, &ldB);
            
            // r ← f • b + q = b.T • f + q
            dgemv_("T",
                   &n, &n,
                   &one,
                   P, &n,
                   f, &inc,
                   &one,
                   memcpy(r, q, n * sizeof(double const)), &inc);
            
            // R ← Q • inv(eye(n) + D.T • B • Q) = solve(eye(n) + Q.T • B.T • D, Q) = solve((eye(n) + (D.T • B) • Q).T, Q)
            dgemm_("T", "N",
                   &n, &n, &n,
                   &one,
                   D, &n,
                   P, &n,
                   &zero,
                   R, &n);
            dlaset_("G",
                    &n, &n,
                    &zero, &one,
                    P, &n);
            dgemm_("N", "N",
                   &n, &n, &n,
                   &one,
                   R, &n,
                   Q, &n,
                   &one,
                   P, &n);
            dgetrf_(&n, &n,
                    P, &n, p,
                    &info);
            assert(!info);
            dgetrs_("T",
                    &n, &n,
                    P, &n, p,
                    memcpy(R, Q, n * n * sizeof(double const)), &n,
                    &info);
            assert(!info);
            
            // a = -D • Q
            dgemm_("N", "N",
                   &n, &n, &n,
                   &minus,
                   D, &n,
                   Q, &n,
                   &zero,
                   P, &n);
            for ( register intptr_t c = 0, C = n ; c < C ; ++ c )
                dcopy_(&n, P + c * n, &inc, A + ( ( m - k - 1 ) * n + c ) * n * ldA, &ldA);
            
            // f ← f + a • q
            dgemv_("N",
                   &n, &n,
                   &one,
                   P, &n,
                   q, &inc,
                   &one,
                   f, &inc);
            
            // F ← F • inv(eye(n) + A • D.T • F) = solve(eye(n) + F.T • D • A.T, F) = solve((eye(n) + (A • D.T) • F).T, F)
            dgemm_("N", "T",
                   &n, &n, &n,
                   &one,
                   P, &n,
                   D, &n,
                   &zero,
                   Q, &n);
            dlaset_("G",
                    &n, &n,
                    &zero, &one,
                    P, &n);
            dgemm_("N", "N",
                   &n, &n, &n,
                   &one,
                   Q, &n,
                   F, &n,
                   &one,
                   P, &n);
            dgetrf_(&n, &n,
                    P, &n, p,
                    &info);
            assert(!info);
            dgetrs_("T",
                    &n, &n,
                    P, &n, p,
                    F, &n,
                    &info);
            assert(!info);
            
        }
    }
}
