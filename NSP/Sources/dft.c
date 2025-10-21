//
//  dft.c
//  MUTE
//
//  Created by Kota on 8/28/R7.
//
#include"module.h"
#include"dft.h"
// MARK: Constant
static
intptr_t const _[] = {0, 1, 2};
// MARK: Integer
static inline
intptr_t const isqrt(intptr_t const x) {
	register intptr_t x0 = x / 2;
	register intptr_t x1 = ( x0 + x / x0 ) / 2;
	while ( x1 < x0 ) {
		x0 = x1;
		x1 = (x0 + x / x0) / 2;
	}
	return x0;
}
static inline
intptr_t const ilog2n(intptr_t const x) {
	return sizeof(intptr_t const) * 8 - __builtin_clzl(x) - 1;
}
static inline
intptr_t const factorise(register intptr_t const value, register intptr_t check) {
	while ( check * check <= value )
		if ( value % check )
			check += 1 + (check & 1);
		else
			return check;
	return value;
}
intptr_t const pf(register intptr_t value, intptr_t * __nonnull const prime) {
	intptr_t const limit = isqrt(value + 1);
	intptr_t * const sieve = alloca(sizeof(intptr_t const) * 13 * limit / ilog2n(limit) / 7); // π(x) < 1.8*x/log2(x)
	assert(2 * sqrt(limit) / ceil(log(limit)) < 13 * limit / ilog2n(limit) / 7);
	register intptr_t count = 0, found = 0;
	*sieve = 3;
	while ( value % 2 == 0 )
		value /= prime[count++] = 2;
	while ( 1 < value ) if ( limit < sieve[found] )
		value ^= prime[count++] = value;
	else if ( value % sieve[found] == 0 )
		value /= prime[count++] = sieve[found];
	else for ( register intptr_t prima = sieve[found] + 2, proof = 1 ; ; prima += 2, proof = 1 ) {
		register bool proof = true;
		for ( register intptr_t index = 0, upper = isqrt(prima) + 1 ; proof && sieve[index] < upper ; ++ index )
			proof &= prima % sieve[index] != 0;
		if ( proof && (sieve[++found] = prima) )
			break;
	}
	return count;
}
intptr_t const pd(register intptr_t const value, intptr_t * __nonnull const prime) {
	intptr_t const limit = isqrt(value) + 1;
	intptr_t * const sieve = alloca(sizeof(intptr_t const) * (13 * limit / ilog2n(limit) / 7 + 1)); // π(x) < 1.8*x/log2(x)
	assert(1.2551 * limit / log(limit) <= 13 * limit / ilog2n(limit) / 7 + 1);
	register intptr_t count = 0, found = 0;
	sieve[0] = 3;
	*prime = value;
	while ( prime[count] % 2 == 0 )
		++ count, prime[count] = prime[count-1] / 2;
	while ( 1 < prime[count] ) if ( limit < sieve[found] )
		++ count, prime[count] = 1;
	else if ( prime[count] % sieve[found] == 0 )
		++ count, prime[count] = prime[count-1] / sieve[found];
	else for ( register bool proof = (++ found, sieve[found] = sieve[found-1], false) ; !proof ; )
		for ( register intptr_t const upper = isqrt(sieve[found] += 2), * __nonnull trial = (proof=true,sieve) ; proof && *trial < upper ; ++ trial )
			proof = proof && sieve[found] % *trial;
	assert(prime[count] == 1);
	return count + 1;
}
static inline
void create_table_value(intptr_t const rows, intptr_t const cols,
						__complex double const * __nonnull const table, double * __nullable const working) {
	double * __nonnull const edx = working ? working : alloca(2 * rows * sizeof(double const));
	double * __nonnull const edy = edx + rows;
	for ( register intptr_t k = 0, K = cols ; k < K ; ++ k ) {
		__ramp__(0, k, edy, 1, rows);
		__vsdiv__(edy, 1, -0.5 * rows, edy, 1, rows);
		__cospi__(edy, edx, rows); // cosπ and sinπ are superior numerical accuracy to other methods
		__sinpi__(edy, edy, rows); // like cosisin, vDSP_polarD, sincos(edy*M_PI) et al
		dcopy_(&rows, edx, &1[_], ((double*__nonnull const)(table + k * rows)) + 0, &2[_]);
		dcopy_(&rows, edy, &1[_], ((double*__nonnull const)(table + k * rows)) + 1, &2[_]);
	}
}
// MARK: DFS
__attribute__((overloadable))
ddft_t * __nonnull const ddft_create(intptr_t const * __nonnull const count) {
	assert(count[0] % count[1] == 0);
	intptr_t const rows = count[0];
	intptr_t const cols = count[0] / count[1];
	void*__nonnull const p = __malloc__(sizeof(ddft_t const) + ( cols * rows + rows ) * sizeof(__complex double)); // with extra workspace
	ddft_t*__nonnull const object = (ddft_t*__nonnull const)p;
	*(__complex double**const)&object->table = (__complex double*)(p + sizeof(ddft_t const));
	create_table_value(rows, cols, object->table, (double*__nonnull const)(object->table + cols * rows));
	*(intptr_t*const)&object->rows = rows;
	*(intptr_t*const)&object->cols = cols;
	*(void**const)&object->prime = 1 < count[1] ? ddft_create(count + 1) : NULL;
	return object;
}
__attribute__((overloadable))
ddft_t * __nonnull const ddft_create(intptr_t const count) {
	register intptr_t*__nonnull const prime = alloca(sizeof(intptr_t const) * (ilog2n(count) + 1));
	assert(floor(log2(count)) <= ilog2n(count) + 1);
	register intptr_t const found = pd(count, prime);
	assert(found <= ilog2n(count) + 1);
	return ddft_create(prime);
}
void ddft_destroy(ddft_t * __nonnull const object) {
	if (object->prime)
		ddft_destroy(object->prime);
	__free__(object);
}
inline static
void ddft(ddft_t const * __nonnull const object, intptr_t const stride,
		  __complex double const scale, char const t,
		  __complex double const * __nonnull const X,
		  __complex double       * __nonnull const Y) {
	ddft_t const * __nullable const factor = object->prime;
	if ( factor ) {
		register __complex double const * __nonnull z = object->table;
		register __complex double * __nonnull const w = object->table + object->rows * object->cols;
		
//		for ( register intptr_t j = 0, J = object->cols ; j < J ; ++ j )
//			ddft(factor, stride * object->cols, scale, t, X + j * stride, w + j * factor->rows);
//		for ( register intptr_t j = 0, J = object->cols ; j < J ; ++ j ) {
//			memcpy(Y + factor->rows * j, w, sizeof(__complex double const) * factor->rows);
//			for ( register intptr_t k = 1, K = object->cols ; k < K ; ++ k )
//				zgbmv_(&t,
//					   &factor->rows, &factor->rows, _, _,
//					   (__complex double const[]){1},
//					   z + factor->rows * ( j + J * k ), &1[_],
//					   w + factor->rows * k, &1[_],
//					   (__complex double const[]){1},
//					   Y + factor->rows * j, &1[_]);
//		}
		
		ddft(factor, stride * object->cols, scale, t, X, Y);
		for ( register intptr_t j = 1, J = object->cols ; j < J ; ++ j )
			memcpy(Y + factor->rows * j, Y, sizeof(__complex double const) * factor->rows);
		for ( register intptr_t j = 1, J = object->cols ; j < J ; ++ j ) {
			ddft(factor, stride * object->cols, scale, t, X + j * stride, w);
			for ( register intptr_t k = 0, K = object->cols ; k < K ; ++ k )
				zgbmv_(&t,
					   &factor->rows, &factor->rows, _, _,
					   (__complex double const[]){1},
					   z + factor->rows * ( j * K + k ), &1[_],
					   w, &1[_],
					   (__complex double const[]){1},
					   Y + factor->rows * k, &1[_]);
		}
		
//		for ( register intptr_t j = 0, J = object->cols ; j < J ; ++ j ) {
//			ddft(factor, stride * object->cols, scale, t, X + j * stride, w);
//			for ( register intptr_t k = 0, K = object->cols ; k < K ; ++ k ) {
//				zgbmv_(&t,
//					   &factor->rows, &factor->rows, _, _,
//					   (__complex double const[]){1},
//					   z + factor->rows * ( j * K + k ), &1[_],
//					   w, &1[_],
//					   (__complex double const[]){1},
//					   Y + factor->rows * k, &1[_]);
//			}
//		}
		
//		for ( register __complex double const * __nonnull x = X, * __nonnull const xx = x + object->cols * stride ; x < xx ; x += stride ) {
//			ddft(factor, stride * object->cols, scale, t, x, w);
//			for ( register __complex double       * __nonnull y = Y, * __nonnull const yy = y + object->rows ; y < yy ; y += factor->rows, z += factor->rows )
//				zgbmv_(&t,
//					   &factor->rows, &factor->rows, _, _,
//					   (__complex double const[]){1},
//					   z, &1[_],
//					   w, &1[_],
//					   (__complex double const[]){1},
//					   y, &1[_]);
//		}
	} else if ( X == Y ) {
		zcopy_(&object->rows, X, &stride, object->table + object->rows * object->cols, &1[_]);
		zgemv_(&t,
			   &object->rows, &object->cols,
			   &scale,
			   object->table, &object->rows,
			   object->table + object->rows * object->cols, &1[_],
			   (__complex double const[]){0.0},
			   Y, &1[_]);
	} else {
		zgemv_(&t,
			   &object->rows, &object->cols,
			   &scale,
			   object->table, &object->rows,
			   X, &stride,
			   (__complex double const[]){0.0},
			   Y, &1[_]);
	}
}
__attribute__((overloadable))
void ddft_forward(ddft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
	ddft(object, 1, 1.0,                'N', x, y);
}
__attribute__((overloadable))
void ddft_inverse(ddft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
	ddft(object, 1, 1.0 / object->rows, 'C', x, y);
}
// MARK: BFS
__attribute__((overloadable))
bdft_t * __nonnull const bdft_create(intptr_t const * __nonnull const count) {
    intptr_t depth = 0;
    while ( 1 < count[depth] ) ++ depth;
    void*__nonnull const w = __malloc__(sizeof(intptr_t const) + depth * sizeof(sparse_matrix_double_complex const));
    bdft_t*__nonnull const object = (bdft_t*__nonnull const)w;
    *(intptr_t*__nonnull const)&object->count = depth;
//    *(sparse_matrix_double_complex*__nonnull const)&object->prime = (sparse_matrix_double_complex const)(w + sizeof(bdft_t const));
    sparse_index * __nonnull const O = __malloc__(*count*(3 * sizeof(sparse_index const) + MAX(sizeof(sparse_index const), sizeof(__complex double const))));
    sparse_index * __nonnull const P = O + 1 ** count;
    sparse_index * __nonnull const Q = O + 2 ** count;
    sparse_index * __nonnull const R = O + 3 ** count;
    memset(O, 0, *count * sizeof(sparse_index const));
    for ( register intptr_t i = 0 ; i < object->count ; ++ i ) {
        intptr_t const m = count[i];
        intptr_t const k = count[i+1];
        assert(m % k == 0);
        intptr_t const n = m / k;
        object->prime[i] = sparse_matrix_create_double_complex(*count, *count);
        for ( register intptr_t c = 0 ; c < n ; ++ c ) {
            register __complex double * __nonnull const V = (__complex double * __nonnull const)R;
            register sparse_dimension U = 0;
            for ( register intptr_t r = 0 ; r < m ; ++ r ) {
                double const t = -2.0 * c * r / m;
                __complex double e = cospi(t) + I * sinpi(t);
                for ( register intptr_t j = 0 ; j < *count ; j += m ) {
                    P[U] = j + r;
                    Q[U] = j + c * k + r % k;
                    V[U] = e;
                    ++U;
                }
            }
            sparse_insert_entries_double_complex(object->prime[i], U, V, P, Q);
        }
        // permute target
        for ( register intptr_t c = 0, C = *count / m ; c < C ; ++ c ) {
            O[c] *= n;
            for ( register intptr_t r = 1, R = n ; r < R ; ++ r )
                O[c+r*C] = O[c] + r;
        }
    }
    // permute swap
    for ( register intptr_t s = 0, S = *count ; s < S ; ++ s ) {
        Q[s] = s;
        R[s] = s;
    }
    for ( register intptr_t s = 0, S = *count ; s < S ; ++ s ) {
        intptr_t const t = P[s] = R[O[s]];
        if ( t != s ) {
            intptr_t const u = Q[s];
            intptr_t const v = Q[t];
            Q[s] = v;
            Q[t] = u;
            R[u] = t;
            R[v] = s;
        }
    }
    sparse_permute_cols_double_complex(object->prime[object->count-1], P);
    for ( register intptr_t k = 0, K = object->count ; k < K ; ++ k )
        sparse_commit(object->prime[k]);
    __free__(O);
    return object;
}
__attribute__((overloadable))
bdft_t * __nonnull const bdft_create(intptr_t const count) {
    register intptr_t*__nonnull const prime = alloca(sizeof(intptr_t const) * (ilog2n(count) + 1));
    assert(floor(log2(count)) <= ilog2n(count) + 1);
    register intptr_t const found = pd(count, prime);
    assert(found <= ilog2n(count) + 1);
    return bdft_create(prime);
}
void bdft_dump(bdft_t const * __nonnull const object) {
    FILE * __nonnull const output = stderr;
    for ( intptr_t j = 0, J = object->count ; j < J ; ++ j ) {
        sparse_matrix_double_complex const w = object->prime[j];
        intptr_t const m = sparse_get_matrix_number_of_rows(w);
        intptr_t const n = sparse_get_matrix_number_of_columns(w);
        assert(m == n);
        __complex double * __nonnull const W = __malloc__(2 * m * n * sizeof(__complex double const));
        __complex double * __nonnull const B = W + 0 * m * n;
        __complex double * __nonnull const C = W + 1 * m * n;
        memset(W, 0, 2 * m * n * sizeof(__complex double const));
        for ( intptr_t k = 0, K = MIN(m, n) ; k < K ; ++ k )
            B[k*K+k] = 1;
        sparse_matrix_product_dense_double_complex(CblasRowMajor,
                                                   CblasNoTrans,
                                                   m,
                                                   1,
                                                   w,
                                                   B, n,
                                                   C, n);
        fprintf(output, "Op[%ld]=[\r\n", j);
        for ( intptr_t r = 0 ; r < m ; ++ r ) {
            fprintf(output, "\t[%.2lf%c%.2lfj", creal(C[r*n]), cimag(C[r*n])<0?'-':'+', fabs(cimag(C[r*n])));
            for ( intptr_t c = 1 ; c < n ; ++ c)
                fprintf(output, ",%.2lf%c%.2lfj", creal(C[r*n+c]), cimag(C[r*n+c])<0?'-':'+', fabs(cimag(C[r*n+c])));
            fprintf(output, "],\r\n");
        }
        fprintf(output, "]\r\n");
        __free__(W);
    }
}
void bdft_destroy(bdft_t * __nonnull const object) {
    for ( intptr_t k = 0, K = object->count ; k < K ; ++ k )
        sparse_matrix_destroy(object->prime[k]);
    __free__(object);
}
__attribute__((overloadable))
void bdft_forward(bdft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
    register intptr_t const n = sparse_get_matrix_number_of_rows(*object->prime), w = n * sizeof(__complex double const);
    __complex double * __nonnull const z = __malloc__(w);
    sparse_matrix_vector_product_dense_double_complex(CblasNoTrans,
                                                      1.0,
                                                      object->prime[object->count - 1],
                                                      x, 1,
                                                      memset(object->count & 1 ? y : z, 0, w), 1);
    for ( register intptr_t k = object->count - 1 ; 0 < k -- ; )
        sparse_matrix_vector_product_dense_double_complex(CblasNoTrans,
                                                          1,
                                                          object->prime[k],
                                                                 k & 1 ? y : z,        1,
                                                          memset(k & 1 ? z : y, 0, w), 1);
    __free__(z);
}
__attribute__((overloadable))
void bdft_forward(bdft_t const * __nonnull const object, intptr_t const n,
                  __complex double const * __nonnull const x, intptr_t const ldx,
                  __complex double       * __nonnull const y, intptr_t const ldy) {
    register intptr_t const m = sparse_get_matrix_number_of_rows(*object->prime), w = m * n * sizeof(__complex double const);
    __complex double * __nonnull const u = __malloc__(2 * w);
    __complex double * __nonnull const v = u + m * n;
    if ( object->count & 1 )
        __mcopy__(x, 2 * ldx,
                  v, 2 * m,
                  n, 2 * m);
    else
        __mcopy__(x, 2 * ldx,
                  u, 2 * m,
                  n, 2 * m);
    for ( register intptr_t k = object->count ; 0 < k -- ; )
        sparse_matrix_product_dense_double_complex(CblasColMajor, CblasNoTrans, n,
                                                   1, object->prime[k],
                                                          k & 1 ? u : v,        m,
                                                   memset(k & 1 ? v : u, 0, w), m);
    __mcopy__(u, 2 * m,
              y, 2 * ldy,
              n, 2 * m);
    __free__(u);
}
__attribute__((overloadable))
void bdft_inverse(bdft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
    register intptr_t const n = sparse_get_matrix_number_of_columns(*object->prime), w = n * sizeof(__complex double const);
    __complex double * __nonnull const z = __malloc__(w);
    sparse_matrix_vector_product_dense_double_complex(CblasConjTrans,
                                                      1.0 / (double const)n,
                                                      object->prime[0],
                                                      x, 1,
                                                      memset(object->count & 1 ? y : z, 0, w), 1);
    for ( register intptr_t k = object->count - 1 ; 0 < k -- ; )
        sparse_matrix_vector_product_dense_double_complex(CblasConjTrans,
                                                          1,
                                                          object->prime[object->count - k - 1],
                                                          k & 1 ? y : z, 1,
                                                          memset(k & 1 ? z : y, 0, w), 1);
    __free__(z);
}
__attribute__((overloadable))
void bdft_inverse(bdft_t const * __nonnull const object, intptr_t const n,
                  __complex double const * __nonnull const x, intptr_t const ldx,
                  __complex double       * __nonnull const y, intptr_t const ldy) {
    intptr_t const m = sparse_get_matrix_number_of_rows(*object->prime), w = m * n * sizeof(__complex double const);
    __complex double * __nonnull const u = __malloc__(2 * w);
    __complex double * __nonnull const v = u + m * n;
    // NOTE: use neg to obtain conj, CblasConjTrans might be broken for sparse_matrix_product_dense_double_complex
    if ( object->count & 1 )
        for ( register intptr_t k = 0 ; k < n ; ++ k )
            vDSP_zvconjD((DSPDoubleSplitComplex const[]){{
                .realp=((double*__nonnull const)(x + k * ldx)) + 0,
                .imagp=((double*__nonnull const)(x + k * ldx)) + 1
            }}, 2,
                         (DSPDoubleSplitComplex const[]){{
                .realp=((double*__nonnull const)(v + k * m)) + 0,
                .imagp=((double*__nonnull const)(v + k * m)) + 1,
            }}, 2, m);
    else
        for ( register intptr_t k = 0 ; k < n ; ++ k )
            vDSP_zvconjD((DSPDoubleSplitComplex const[]){{
                .realp=((double*__nonnull const)(x + k * ldx)) + 0,
                .imagp=((double*__nonnull const)(x + k * ldx)) + 1
            }}, 2,
                         (DSPDoubleSplitComplex const[]){{
                .realp=((double*__nonnull const)(u + k * m)) + 0,
                .imagp=((double*__nonnull const)(u + k * m)) + 1,
            }}, 2, m);
    for ( register intptr_t k = object->count ; 0 < k -- ; )
        sparse_matrix_product_dense_double_complex(CblasColMajor, CblasNoTrans, n,
                                                   1, object->prime[k],
                                                          k & 1 ? u : v,        m,
                                                   memset(k & 1 ? v : u, 0, w), m);
    for ( register intptr_t k = 0 ; k < n ; ++ k )
        vDSP_zvmulD((DSPDoubleSplitComplex const[]){{
            .realp=((double*__nonnull const)(u + k * m)) + 0,
            .imagp=((double*__nonnull const)(u + k * m)) + 1
        }}, 2,
                    (DSPDoubleSplitComplex const[]){{
            .realp=(double[]){1/(double const)m},
            .imagp=(double[]){0.0},
        }}, 0,
                    (DSPDoubleSplitComplex const[]){{
            .realp=((double*__nonnull const)(y + k * ldy)) + 0,
            .imagp=((double*__nonnull const)(y + k * ldy)) + 1
        }}, 2,
                    m, -1);
    __free__(u);
}
// MARK: XDFT
//__attribute__((overloadable))
//xdft_t * __nonnull const xdft_create(intptr_t const count) {
//    register intptr_t*__nonnull const prime = alloca(sizeof(intptr_t const) * (ilog2n(count) + 1));
//    assert(floor(log2(count)) <= ilog2n(count) + 1);
//    register intptr_t const found = pd(count, prime);
//    assert(found <= ilog2n(count) + 1);
//    return xdft_create(prime);
//}
//__attribute__((overloadable))
//xdft_t * __nonnull const xdft_create(intptr_t const * __nonnull const count) {
//    intptr_t depth = 0;
//    while ( 1 < count[depth] ) ++ depth;
//    void*__nonnull const w = __malloc__(sizeof(xdft_t const) + depth * sizeof(sparse_matrix_double_complex const));
//    xdft_t*__nonnull const object = (xdft_t*__nonnull const)w;
//    *(intptr_t*__nonnull const)&object->count = depth;
//    *(sparse_matrix_double_complex*__nonnull)&object->prime = (sparse_matrix_double_complex const)(w + sizeof(bdft_t const));
//    sparse_index * __nonnull const O = __malloc__(4**count*sizeof(sparse_index const));
//    sparse_index * __nonnull const P = O + 1 ** count;
//    sparse_index * __nonnull const Q = O + 2 ** count;
//    sparse_index * __nonnull const R = O + 3 ** count;
//    bzero(O, 4**count*sizeof(sparse_index const));
//    for ( intptr_t i = 0 ; i < object->count ; ++ i ) {
//        intptr_t const m = count[i];
//        intptr_t const k = count[i+1];
//        assert(m % k == 0);
//        intptr_t const n = m / k;
//        switch ( k ) {
//            case 1:
//                object->prime[i] = sparse_matrix_create_double_complex(*count, *count);
//                for ( intptr_t c = 0 ; c < n ; ++ c ) {
//                    for ( intptr_t r = 0 ; r < m ; ++ r ) {
//                        double const theta = -2.0 * c * r / m;
//                        __complex double e = cospi(theta) + I * sinpi(theta);
//                        for ( intptr_t j = 0 ; j < *count ; j += m )
//                            sparse_insert_entry_double_complex(object->prime[i],
//                                                               e,
//                                                               j + r,
//                                                               j + c * k + r % k);
//                    }
//                }
//                break;
//            default:
//                object->prime[i] = sparse_matrix_create_double_complex(m, m);
//                for ( intptr_t c = 0 ; c < n ; ++ c ) {
//                    for ( intptr_t r = 0 ; r < m ; ++ r ) {
//                        double const theta = -2.0 * c * r / m;
//                        __complex double e = cospi(theta) + I * sinpi(theta);
//                        sparse_insert_entry_double_complex(object->prime[i],
//                                                           e,
//                                                           r,
//                                                           c * k + r % k);
//                    }
//                }
//                break;
//        }
//        // permute target
//        for ( intptr_t c = 0, C = *count / m ; c < C ; ++ c ) {
//            O[c] *= n;
//            for ( intptr_t r = 1, R = n ; r < R ; ++ r )
//                O[c+r*C] = O[c] + r;
//        }
//    }
//    // permute swap
//    for ( intptr_t s = 0, S = *count ; s < S ; ++ s ) {
//        Q[s] = s;
//        R[s] = s;
//    }
//    for ( intptr_t s = 0, S = *count ; s < S ; ++ s ) {
//        intptr_t const t = P[s] = R[O[s]];
//        if ( t != s ) {
//            intptr_t const u = Q[s];
//            intptr_t const v = Q[t];
//            Q[s] = v;
//            Q[t] = u;
//            R[u] = t;
//            R[v] = s;
//        }
//    }
//    sparse_permute_cols_double_complex(object->prime[object->count-1], P);
//    for ( intptr_t k = 0, K = object->count ; k < K ; ++ k )
//        sparse_commit(object->prime[k]);
//    __free__(O);
//    return object;
//}
//void xdft_dump(xdft_t const * __nonnull const object) {
//    for ( intptr_t j = 0, J = object->count ; j < J ; ++ j ) {
//        sparse_matrix_double_complex const w = object->prime[j];
//        intptr_t const m = sparse_get_matrix_number_of_rows(w);
//        intptr_t const n = sparse_get_matrix_number_of_columns(w);
//        assert(m == n);
//        __complex double * __nonnull const W = __malloc__(2 * m * n * sizeof(__complex double const));
//        __complex double * __nonnull const B = W + 0 * m * n;
//        __complex double * __nonnull const C = W + 1 * m * n;
//        memset(W, 0, 2 * m * n * sizeof(__complex double const));
//        for ( intptr_t k = 0, K = MIN(m, n) ; k < K ; ++ k )
//            B[k*K+k] = 1;
//        sparse_matrix_product_dense_double_complex(CblasRowMajor,
//                                                   CblasNoTrans,
//                                                   m,
//                                                   1,
//                                                   w,
//                                                   B, n,
//                                                   C, n);
//        fprintf(stderr, "Op[%ld]=\r\n[", j);
//        for ( intptr_t r = 0 ; r < m ; ++ r ) {
//            fprintf(stderr, "\t[%.2lf%c%.2lfj", creal(C[r*n]), cimag(C[r*n])<0?'-':'+', fabs(cimag(C[r*n])));
//            for ( intptr_t c = 1 ; c < n ; ++ c)
//                fprintf(stderr, ",%.2lf%c%.2lfj", creal(C[r*n+c]), cimag(C[r*n+c])<0?'-':'+', fabs(cimag(C[r*n+c])));
//            fprintf(stderr, "],\r\n");
//        }
//        fprintf(stderr, "]\r\n");
//        __free__(W);
//    }
//}
//void xdft_destroy(xdft_t * __nonnull const object) {
//    for ( intptr_t k = 0, K = object->count ; k < K ; ++ k )
//        sparse_matrix_destroy(object->prime[k]);
//    __free__(object);
//}
//void xdft_forward(xdft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
//    intptr_t const m = sparse_get_matrix_number_of_rows(*object->prime), w = m * sizeof(__complex double const);
//    __complex double * __nonnull const z = __malloc__(w);
//    sparse_matrix_vector_product_dense_double_complex(CblasNoTrans,
//                                                      1.0,
//                                                      object->prime[object->count - 1],
//                                                      x, 1,
//                                                      memset(object->count & 1 ? y : z, 0, w), 1);
//    for ( intptr_t j = object->count - 1 ; 0 < j -- ;  ) {
//        intptr_t const k = sparse_get_matrix_number_of_rows(object->prime[j]);
//        intptr_t const n = m / k;
//        sparse_matrix_product_dense_double_complex(CblasColMajor,
//                                                   CblasNoTrans,
//                                                   n,
//                                                   1,
//                                                   object->prime[j],
//                                                   j & 1 ? y : z, k,
//                                                   memset(j & 1 ? z : y, 0, w), k);
//    }
//    __free__(z);
//}
//void xdft_inverse(xdft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
//    intptr_t const m = sparse_get_matrix_number_of_rows(*object->prime), w = m * sizeof(__complex double const);
//    __complex double * __nonnull const z = __malloc__(w);
//    sparse_matrix_vector_product_dense_double_complex(CblasConjTrans,
//                                                      1.0,
//                                                      object->prime[object->count - 1],
//                                                      x, 1,
//                                                      memset(object->count & 1 ? y : z, 0, w), 1);
//    for ( intptr_t j = object->count - 1 ; 0 < j -- ;  ) {
//        intptr_t const k = sparse_get_matrix_number_of_rows(object->prime[j]);
//        intptr_t const n = m / k;
//        sparse_matrix_product_dense_double_complex(CblasColMajor,
//                                                   CblasConjTrans,
//                                                   n,
//                                                   1,
//                                                   object->prime[j],
//                                                   j & 1 ? y : z, k,
//                                                   memset(j & 1 ? z : y, 0, w), k);
//    }
//    __free__(z);
//}
//
