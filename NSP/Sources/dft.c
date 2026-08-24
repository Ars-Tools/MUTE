//
//  dft.c
//  MUTE
//
//  Created by Kota on 8/28/R7.
//
#include<simd/simd.h>
#include"module.h"
#include"mkl+arithmetic.h"
#include"mkl+fma.h"
#include"vforce+trigonometric.h"
#include"dft.h"
// MARK: Constant
__attribute__((visibility("hidden")))
static intptr_t const _[] = {0, 1, 2};
__attribute__((visibility("hidden")))
static __complex double const zero = 0.0;
__attribute__((visibility("hidden")))
static __complex double const one = 1.0;
// MARK: Helper
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
__complex double const dft_scale(dft_scale_t const mode, double const count) {
    switch ( mode ) {
        case DFT_SCALE_ONE:
            return 1;
        case DFT_SCALE_ONE_OVER_N:
            return simd_recip(count);
        case DFT_SCALE_ONE_OVER_SQRT_N:
            return simd_rsqrt(count);
    }
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dft_create_table_value(__complex double * __nonnull const table,
                            double * __nullable cache,
                            intptr_t const count) {
    if ( !cache )
        cache = alloca(count * sizeof(double const));
    __ramp__(0, -2.0 * M_PI / count, cache, 1, count);
    vvcosisin(cache, table, count);
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dft_create_table_value(intptr_t const rows, intptr_t const cols,
                            __complex double * __nonnull const table,
                            double * __nullable const working) {
    double * __nonnull const edx = working ? working : alloca(2 * rows * sizeof(double const));
    double * __nonnull const edy = edx + rows;
    for ( register intptr_t k = 0, K = cols ; k < K ; ++ k ) {
        __ramp__(0, k, edy, 1, rows);
        __vsdiv__(edy, 1, -0.5 * rows, edy, 1, rows);
        __cospi__(edy, edx, rows); // cosπ and sinπ are superior numerical accuracy to other methods
        __sinpi__(edy, edy, rows); // like cosisin, vDSP_polarD, sincos(edy*M_PI) et al
        dcopy_(&rows, edx, &1[_], &__real(table[k * rows]), &2[_]);
        dcopy_(&rows, edy, &1[_], &__imag(table[k * rows]), &2[_]);
    }
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dft_create_table(intptr_t const count,
                      __complex double * __nonnull const table) {
    double * __nonnull const r = &__real(*table);
    double * __nonnull const i = &__imag(*table);
    __fill__(1, r, 2, count);
    __ramp__(0, -2 * M_PI / count, i, 2, count);
    vDSP_polarD(r, 2, r, 2, count);
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dft_create_table(intptr_t const rows, intptr_t const cols,
                      __complex double * __nonnull const table, intptr_t const ld) {
    double * __nonnull const edx = &__real(*table);
    double * __nonnull const edy = edx + ld;
    for ( register intptr_t col = 1 ; col < cols ; ++ col ) {
        __ramp__(0, -2 * col, edx, 1, rows);
        __vsdiv__(edx, 1, rows, edx, 1, rows);
        vvsinpi(edx, edy, rows);
        vvcospi(edx, edx, rows);
        vDSP_ztocD(&(DSPDoubleSplitComplex const) {
            .realp = edx,
            .imagp = edy
        }, 1, table + col * ld, 2, rows);
    }
//    __ramp__(0, 1, edx, 1, rows);
//    __vsdiv__(edx, 1, rows, edx, 1, rows);
//    for ( register intptr_t col = 1 ; col < cols ; ++ col )
//        vDSP_vsmulD(edx, 1,
//                    (double const[]){-2*M_PI*col},
//                    edy, 1,
//                    rows),
//        vvcosisin(table + col * ld, edy, (int const[]){(int)rows});
    vDSP_zvfillD(&(DSPDoubleSplitComplex const) {
        .realp = &__real(one),
        .imagp = &__imag(one)
    }, &(DSPDoubleSplitComplex const) {
        .realp = &__real(*table),
        .imagp = &__imag(*table)
    }, 2, rows);
}
__attribute__((overloadable, visibility("hidden"))) static inline // dump matrix
void dft_dump(FILE * __nonnull const output,
              intptr_t const rows, intptr_t const cols,
              __complex double const * __nonnull const dense, intptr_t const ld) {
    fprintf(output, "[");
    for ( intptr_t row = 0 ; row < rows ; ++ row ) {
        fprintf(output, "%s[", row ? ",\r\n " : "");
        for ( intptr_t col = 0 ; col < cols ; ++ col ) {
            register double const
            r = __real(dense[col*ld+row]),
            i = __imag(dense[col*ld+row]);
            fprintf(output, "%s", col ? ", " : "");
            if ( i < 0 )
                fprintf(output, "%lf-%lfj", r, fabs(i));
            else if ( 0 < i )
                fprintf(output, "%lf+%lfj", r, fabs(i));
            else
                fprintf(output, "%lf", r);
        }
        fprintf(output, "]");
    }
    fprintf(output, "]\r\n");
}
// MARK: Integer OPs
__attribute__((always_inline)) static inline
intptr_t const isqrt(intptr_t const x) {
	register intptr_t x0 = x / 2;
	register intptr_t x1 = ( x0 + x / x0 ) / 2;
	while ( x1 < x0 ) {
		x0 = x1;
		x1 = (x0 + x / x0) / 2;
	}
	return x0;
}
__attribute__((always_inline)) static inline
intptr_t const ilog2n(intptr_t const x) {
	return sizeof(x) * 8 - __builtin_clzl(x) - 1;
}
__attribute__((always_inline)) static inline
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
// MARK: DIT, struct from chunk-completed dft
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dit_forward(__complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double const * __nonnull const z, intptr_t const ldz,
                 __complex double       * __nonnull const w,
                 intptr_t const * __nonnull const prime,
                 void(^invoke)(__complex double const * __nonnull const, intptr_t const,
                               __complex double       * __nonnull const, intptr_t const,
                               intptr_t const)) {
    switch ( prime[1] ) {
        case 0:
            abort();
        case 1:
            invoke(x, incx, y, incy, prime[0]);
            break;
        default: {
            intptr_t const n = prime[0];
            intptr_t const h = prime[1];
            intptr_t const p = n / h;
            intptr_t const incz = ldz / n;
            for ( intptr_t r = 0 ; r < p ; ++ r ) {
                dit_forward(x + r * incx, p * incx,
                            w, 1,
                            z, ldz,
                            w + h,
                            prime + 1,
                            invoke);
                for ( intptr_t j = 0 ; j < p ; ++ j ) {
                    __complex double       * const blk = y + j * h * incy;
                    __complex double const * const col = z + (j * h * incz) + r * ldz;
                    if (r == 0)
                        zcopy_(&h, w, &1[_], blk, &incy);
                    else
                        vDSP_zvmaD(&(DSPDoubleSplitComplex const) {
                            .realp = &__real(*col),
                            .imagp = &__imag(*col)
                        }, 2 * incz, &(DSPDoubleSplitComplex const) {
                            .realp = &__real(*w),
                            .imagp = &__imag(*w)
                        }, 2, &(DSPDoubleSplitComplex const) {
                            .realp = &__real(*blk),
                            .imagp = &__imag(*blk)
                        }, 2 * incy, &(DSPDoubleSplitComplex const) {
                            .realp = &__real(*blk),
                            .imagp = &__imag(*blk)
                        }, 2 * incy, h);
                }
            }
            break;
        }
    }
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dit_inverse(__complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double const * __nonnull const z, intptr_t const ldz,
                 __complex double       * __nonnull const w,
                 intptr_t const * __nonnull const prime,
                 void(^invoke)(__complex double const * __nonnull const, intptr_t const,
                               __complex double  * __nonnull const, intptr_t const,
                               intptr_t const)) {
    switch ( prime[1] ) {
        case 0:
            abort();
        case 1:
            invoke(x, incx, y, incy, prime[0]);
            break;
        default: {
            intptr_t const n = prime[0];
            intptr_t const h = prime[1];
            intptr_t const p = n / h;
            intptr_t const incz = ldz / n;
            for ( intptr_t r = 0 ; r < p ; ++ r ) {
                dit_inverse(x + r * incx, p * incx,
                            w, 1,
                            z, ldz,
                            w + h,
                            prime + 1,
                            invoke);
                for ( intptr_t j = 0 ; j < p ; ++ j ) {
                    __complex double       * const blk = y + j * h * incy;
                    __complex double const * const col = z + (j * h * incz) + r * ldz;
                    if (r == 0)
                        zcopy_(&h, w, &1[_], blk, &incy);
                    else
                        vDSP_zvcmaD(&(DSPDoubleSplitComplex const) {
                            .realp = &__real(*col),
                            .imagp = &__imag(*col)
                        }, 2 * incz, &(DSPDoubleSplitComplex const) {
                            .realp = &__real(*w),
                            .imagp = &__imag(*w)
                        }, 2, &(DSPDoubleSplitComplex const) {
                            .realp = &__real(*blk),
                            .imagp = &__imag(*blk)
                        }, 2 * incy, &(DSPDoubleSplitComplex const) {
                            .realp = &__real(*blk),
                            .imagp = &__imag(*blk)
                        }, 2 * incy, h);
                }
            }
            break;
        }
    }
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dit_forward(__complex double const * __nonnull const x, intptr_t const incx, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const incy, intptr_t const ldy,
                 __complex double const * __nonnull const z, intptr_t const ldz,
                 __complex double       * __nonnull const w,
                 intptr_t const * __nonnull const prime, intptr_t const nrhs,
                 void(^invoke)(__complex double const * __nonnull const, intptr_t const, intptr_t const,
                               __complex double  * __nonnull const, intptr_t const, intptr_t const,
                               intptr_t const, intptr_t const)) {
    switch ( prime[1] ) {
        case 0:
            abort();
        case 1:
            invoke(x, incx, ldx,
                   y, incy, ldy,
                   prime[0], nrhs);
            break;
        default: {
            intptr_t const n = prime[0];
            intptr_t const h = prime[1];
            intptr_t const p = n / h;
            intptr_t const incz = ldz / n;
            for ( intptr_t r = 0 ; r < p ; ++ r ) {
                dit_forward(x + r * incx, p * incx, ldx,
                            w, 1, h,
                            z, ldz,
                            w + h * nrhs,
                            prime + 1, nrhs,
                            invoke);
                for ( intptr_t j = 0 ; j < p ; ++ j ) {
                    __complex double const * const col = z + (j * h * incz) + r * ldz;
                    for ( intptr_t c = 0 ; c < nrhs ; ++ c ) {
                        __complex double       * const blk = y + j * h * incy + c * ldy;
                        __complex double const * const wc  = w + c * h;
                        if (r == 0)
                            zcopy_(&h, wc, &1[_], blk, &incy);
                        else
                            vDSP_zvmaD(&(DSPDoubleSplitComplex const) {
                                .realp = &__real(*col),
                                .imagp = &__imag(*col)
                            }, 2 * incz, &(DSPDoubleSplitComplex const) {
                                .realp = &__real(*wc),
                                .imagp = &__imag(*wc)
                            }, 2, &(DSPDoubleSplitComplex const) {
                                .realp = &__real(*blk),
                                .imagp = &__imag(*blk)
                            }, 2 * incy, &(DSPDoubleSplitComplex const) {
                                .realp = &__real(*blk),
                                .imagp = &__imag(*blk)
                            }, 2 * incy, h);
                    }
                }
            }
            break;
        }
    }
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dit_inverse(__complex double const * __nonnull const x, intptr_t const incx, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const incy, intptr_t const ldy,
                 __complex double const * __nonnull const z, intptr_t const ldz,
                 __complex double       * __nonnull const w,
                 intptr_t const * __nonnull const prime, intptr_t const nrhs,
                 void(^invoke)(__complex double const * __nonnull const, intptr_t const, intptr_t const,
                               __complex double  * __nonnull const, intptr_t const, intptr_t const,
                               intptr_t const, intptr_t const)) {
    switch ( prime[1] ) {
        case 0:
            abort();
        case 1:
            invoke(x, incx, ldx,
                   y, incy, ldy,
                   prime[0], nrhs);
            break;
        default: {
            intptr_t const n = prime[0];
            intptr_t const h = prime[1];
            intptr_t const p = n / h;
            intptr_t const incz = ldz / n;
            for ( intptr_t r = 0 ; r < p ; ++ r ) {
                dit_inverse(x + r * incx, p * incx, ldx,
                            w, 1, h,
                            z, ldz,
                            w + h * nrhs,
                            prime + 1, nrhs,
                            invoke);
                for ( intptr_t j = 0 ; j < p ; ++ j ) {
                    __complex double const * const col = z + (j * h * incz) + r * ldz;
                    for ( intptr_t c = 0 ; c < nrhs ; ++ c ) {
                        __complex double       * const blk = y + j * h * incy + c * ldy;
                        __complex double const * const wc  = w + c * h;
                        if (r == 0)
                            zcopy_(&h, wc, &1[_], blk, &incy);
                        else
                            vDSP_zvcmaD(&(DSPDoubleSplitComplex const) {
                                .realp = &__real(*col),
                                .imagp = &__imag(*col)
                            }, 2 * incz, &(DSPDoubleSplitComplex const) {
                                .realp = &__real(*wc),
                                .imagp = &__imag(*wc)
                            }, 2, &(DSPDoubleSplitComplex const) {
                                .realp = &__real(*blk),
                                .imagp = &__imag(*blk)
                            }, 2 * incy, &(DSPDoubleSplitComplex const) {
                                .realp = &__real(*blk),
                                .imagp = &__imag(*blk)
                            }, 2 * incy, h);
                    }
                }
            }
            break;
        }
    }
}
// MARK: DIF
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dif(__complex double * __nonnull const y, intptr_t const incy,
         __complex double * __nonnull const z, intptr_t const incz,// table
         __complex double * __nonnull const w, // cache
         intptr_t const * __nonnull const prime) {
    assert(!(prime[0] % prime[1]));
    intptr_t const ratio = prime[0] / prime[1];
    intptr_t const width = prime[1] * incz;
    intptr_t const stepz = incz * ratio;
    intptr_t const stepy = incy * ratio;
    zcopy_(prime + 0, y, &incy, w, &1[_]);
    for ( intptr_t j = 0 ; j < ratio ; ++ j ) {
        zcopy_(prime + 1,
               w, &1[_],
               y + j * incy, &stepy);
        for ( intptr_t k = 1 ; k < ratio ; ++ k )
            zaxpy_(prime + 1,
                   z + width * ((j * k) % ratio),
                   w + k * prime[1], &1[_],
                   y + j * incy, &stepy);
        vDSP_mul(y + j * incy, stepy,
                 z, j * incz,
                 y + j * incy, stepy, prime[1]);
    }
    switch ( prime[1] ) {
        case 0:
            abort();
        case 1:
            break;
        default:
            for ( intptr_t k = 0 ; k < ratio ; ++ k )
                dif(y + k * incy, stepy,
                    z, stepz,
                    w, prime + 1);
            break;
    }
}
__attribute__((visibility("hidden"), always_inline, overloadable)) static inline
void dif(__complex double * __nonnull const y, intptr_t const incy, intptr_t const ldy,
         __complex double * __nonnull const z, intptr_t const incz,// table
         __complex double * __nonnull const w, // cache
         intptr_t const * __nonnull const prime,
         intptr_t const nrhs) {
    assert(!(prime[0] % prime[1]));
    intptr_t const ratio = prime[0] / prime[1];
    intptr_t const width = prime[1] * incz;
    intptr_t const stepz = incz * ratio;
    intptr_t const stepy = incy * ratio;
    for ( intptr_t c = 0 ; c < nrhs ; ++ c ) {
        __complex double * const yc = y + c * ldy;
        zcopy_(prime + 0, yc, &incy, w, &1[_]);
        for ( intptr_t j = 0 ; j < ratio ; ++ j ) {
            zcopy_(prime + 1,
                   w, &1[_],
                   yc + j * incy, &stepy);
            for ( intptr_t k = 1 ; k < ratio ; ++ k )
                zaxpy_(prime + 1,
                       z + width * ((j * k) % ratio),
                       w + k * prime[1], &1[_],
                       yc + j * incy, &stepy);
            vDSP_mul(yc + j * incy, stepy,
                     z, j * incz,
                     yc + j * incy, stepy, prime[1]);
        }
    }
    switch ( prime[1] ) {
        case 0:
            abort();
        case 1:
            break;
        default:
            for ( intptr_t k = 0 ; k < ratio ; ++ k )
                dif(y + k * incy, stepy, ldy,
                    z, stepz,
                    w, prime + 1, nrhs);
            break;
    }
}
// MARK: JIT, construct table just in time, DIF-based
__attribute__((overloadable))
void dft_forward(intptr_t const count,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable const w) {
    dft_forward(count, x, 1, y, 1, w);
}
__attribute__((overloadable))
void dft_inverse(intptr_t const count,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable const w) {
    dft_inverse(count, x, 1, y, 1, w);
}
__attribute__((overloadable))
void dft_forward(intptr_t const count,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const w) {
    register intptr_t * __nonnull const prime = alloca((ilog2n(count) + 1) * sizeof(intptr_t const));
    assert(floor(log2(count)) <= ilog2n(count) + 1);
    register intptr_t const found = pd(count, prime);
    assert(found <= ilog2n(count) + 1);
    __complex double * __nonnull const table = w ? w : __malloc__(2 * count * sizeof(__complex double const));
    __complex double * __nonnull const cache = table + count;
    __ramp__(0, -2.0 * M_PI / count, &__real(*cache), 1, count);
    vvcosisin(&__real(*cache), table, count);
    if ( x != y )
        zcopy_(&count, x, &incx, y, &incy);
    else
        assert(incx == incy);
    dif(y, incy,
        table, 1,
        cache,
        prime);
    if ( !w )
        __free__(table);
}
__attribute__((overloadable))
void dft_inverse(intptr_t const count,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const w) {
    register intptr_t * __nonnull const prime = alloca((ilog2n(count) + 1) * sizeof(intptr_t const));
    assert(floor(log2(count)) <= ilog2n(count) + 1);
    register intptr_t const found = pd(count, prime);
    assert(found <= ilog2n(count) + 1);
    __complex double * __nonnull const table = w ? w : __malloc__(2 * count * sizeof(__complex double const));
    __complex double * __nonnull const cache = table + count;
    __ramp__(0,  2.0 * M_PI / count, &__real(*cache), 1, count);
    vvcosisin(&__real(*cache), table, count);
    if ( x != y )
        zcopy_(&count, x, &incx, y, &incy);
    else
        assert(incx == incy);
    dif(y, incy,
        table, 1,
        cache,
        prime);
    if ( !w )
        __free__(table);
}
__attribute__((overloadable))
void dft_forward(intptr_t const count, intptr_t const nrhs,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const w) {
    register intptr_t * __nonnull const prime = alloca((ilog2n(count) + 1) * sizeof(intptr_t const));
    assert(floor(log2(count)) <= ilog2n(count) + 1);
    intptr_t const found = pd(count, prime);
    assert(found <= ilog2n(count) + 1);
    __complex double * __nonnull const table = w ? w : __malloc__(2 * count * sizeof(__complex double const));
    __complex double * __nonnull const cache = table + count;
    __ramp__(0, -2.0 * M_PI / count, &__real(*cache), 1, count);
    vvcosisin(&__real(*cache), table, count);
    if ( x != y );
        __mcopy__(x, ldx, y, ldy, nrhs, count);
    dif(y, 1, ldy,
        table, 1,
        cache,
        prime,
        nrhs);
    if ( !w )
        __free__(table);
}
__attribute__((overloadable))
void dft_inverse(intptr_t const count, intptr_t const nrhs,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const w) {
    register intptr_t * __nonnull const prime = alloca((ilog2n(count) + 1) * sizeof(intptr_t const));
    assert(floor(log2(count)) <= ilog2n(count) + 1);
    intptr_t const found = pd(count, prime);
    assert(found <= ilog2n(count) + 1);
    __complex double * __nonnull const table = w ? w : __malloc__(2 * count * sizeof(__complex double const));
    __complex double * __nonnull const cache = table + count;
    __ramp__(0,  2.0 * M_PI / count, &__real(*cache), 1, count);
    vvcosisin(&__real(*cache), table, count);
    if ( x != y );
        __mcopy__(x, ldx, y, ldy, nrhs, count);
    dif(y, 1, ldy,
        table, 1,
        cache,
        prime,
        nrhs);
    if ( !w )
        __free__(table);
}

// MARK: DFS
#if 0 // prev. ddft_t
__attribute__((overloadable))
ddft_t * __nonnull const ddft_create(intptr_t const * __nonnull const count) {
	assert(count[0] % count[1] == 0);
	intptr_t const rows = count[0];
	intptr_t const cols = count[0] / count[1];
	void*__nonnull const p = __malloc__(sizeof(ddft_t const) + ( cols * rows + rows ) * sizeof(__complex double)); // with extra workspace
	ddft_t*__nonnull const object = (ddft_t*__nonnull const)p;
	*(__complex double**const)&object->table = (__complex double*)(p + sizeof(ddft_t const));
    dft_create_table_value(rows, cols, object->table, object->table + rows * cols);
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
__attribute__((overloadable))
void dft_destroy(ddft_t const * __nonnull const object) {
    if (object->prime)
        ddft_destroy(object->prime);
    __free__(object);
}
void ddft_destroy(ddft_t const * __nonnull const object) {
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
void dft_forward(ddft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nonnull const w) {
    if ( object->prime ) {
        intptr_t const p = object->cols;
        intptr_t const h = object->rows / object->cols;
        for ( intptr_t r = 0 ; r < p ; ++ r ) {
            dft_forward((ddft_t const*__nonnull const)object->prime, scale,
                        x + r * incx, p * incx,
                        w, 1,
                        w + h);
            for ( intptr_t j = 0 ; j < p ; ++ j ) {
                __complex double * const blk = y + j * h * incy;
                __complex double * const col = object->table + (j * h) + r * object->rows;
                if (r == 0)
                    zcopy_(&h, w, &1[_], blk, &incy);
                else
                    vDSP_zvmaD(&(DSPDoubleSplitComplex const) {
                        .realp = &__real(*col),
                        .imagp = &__imag(*col)
                    }, 2, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*w),
                        .imagp = &__imag(*w)
                    }, 2, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*blk),
                        .imagp = &__imag(*blk)
                    }, 2 * incy, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*blk),
                        .imagp = &__imag(*blk)
                    }, 2 * incy, h);
            }
        }
    } else if ( object->rows != object->cols )
        abort();
    else if ( x != y )
        zgemv_("N",
               &object->rows, &object->cols,
               (__complex double const[]) {dft_scale(scale, object->rows)},
               object->table, &object->rows,
               x, &incx,
               &zero,
               y, &incy);
    else if ( incx != incy )
        abort();
    else
        zcopy_(&object->cols, x, &incx, w, &1[_]),
        zgemv_("N",
               &object->rows, &object->cols,
               (__complex double const[]){dft_scale(scale, object->rows)},
               object->table, &object->rows,
               w, &1[_],
               &zero,
               y, &incy);
}
__attribute__((overloadable))
void dft_inverse(ddft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const w) {
    if ( object->prime ) {
        
    } else if ( object->rows != object->cols )
        abort();
    else if ( x != y )
        zgemv_("C",
               &object->rows, &object->cols,
               (__complex double const[]) {dft_scale(scale, object->rows)},
               object->table, &object->rows,
               x, &incx,
               &zero,
               y, &incy);
    else if ( incx != incy )
        abort();
    else if ( w )
        zgemv_("C",
               &object->rows, &object->cols,
               (__complex double const[]){dft_scale(scale, object->rows)},
               object->table, &object->rows,
               (zcopy_(&object->cols, x, &incx, w, &1[_]), w), &1[_],
               &zero,
               y, &incy);
    else
        abort();
}
__attribute__((overloadable))
void ddft_forward(ddft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
	ddft(object, 1, 1.0,                'N', x, y);
}
__attribute__((overloadable))
void ddft_inverse(ddft_t const * __nonnull const object, __complex double const * __nonnull const x, __complex double * __nonnull const y) {
	ddft(object, 1, 1.0 / object->rows, 'C', x, y);
}
__attribute__((overloadable))
void dft_forward(ddft_t const * __nonnull const object,
                 dft_scale_t const scale,
                 __complex double * __nonnull const x, intptr_t const incx,
                 __complex double * __nonnull       y, intptr_t const incy,
                 __complex double * __nullable w) {
    if ( !object->prime )
        return zgemv_("N",
                      &object->rows, &object->cols,
                      (__complex double[]){1.0},
                      object->table, &object->rows,
                      x, incx,
                      (__complex double[]){0.0},
                      y, incy);
    if ( !w )
        w = alloca(object->rows * sizeof(__complex double const));
    
}
#endif
// MARK: DDFT
__attribute__((visibility("hidden"), always_inline)) static inline
__complex double * __nonnull const ddft_table(ddft_t const * __nonnull const object) {
    uintptr_t static const mask = sizeof(__complex double const) - 1;
    uintptr_t const base = &object->prime[object->count];
    return ( base + mask ) & ~mask;
}
__attribute__((overloadable)) // custom factorised series, forcely dense
ddft_t const * __nonnull const ddft_create(intptr_t const * __nonnull const prime) {
    assert(prime[0] % prime[1] == 0);
    intptr_t found = 0;
    intptr_t ratio = 0;
    do ratio = MAX(ratio, prime[found] / prime[found+1]);
    while ( 1 < prime[++found] );
    ddft_t * __nonnull const object =
    __malloc__(sizeof(ddft_t const) + found * sizeof(intptr_t const) + ( prime[0] * ratio + 1 ) * sizeof(__complex double const));
    object->count = found + 1;
    object->log2n = 0;
    memcpy(object->prime, prime, object->count * sizeof(intptr_t const));
    object->dense = __malloc__(object->prime[object->count-2] * object->prime[object->count-2] * sizeof(__complex double const));
    dft_create_table(prime[0],
                     object->prime[object->count-2],
                     object->dense,
                     object->prime[object->count-2]);
    dft_create_table(prime[0],
                     ratio,
                     ddft_table(object),
                     prime[0]);
    return object;
}
__attribute__((overloadable))
ddft_t const * __nonnull const ddft_create(intptr_t const count) {
    register intptr_t*__nonnull const prime = alloca(sizeof(intptr_t const) * (ilog2n(count) + 1));
    assert(floor(log2(count)) <= ilog2n(count) + 1);
    register intptr_t const found = pd(count, prime);
    assert(found <= ilog2n(count) + 1);
    assert(prime[0] == count);
    assert(prime[found-1] == 1);
    register intptr_t log2n = 0;
    while ( prime[log2n] == 2 * prime[log2n + 1] ) ++ log2n;
    FFTSetupD __nullable const setup = log2n ? vDSP_create_fftsetupD(log2n, FFT_RADIX2) : NULL;
    ddft_t * __nonnull const object = __malloc__(sizeof(ddft_t const) + ( found - 1 ) * sizeof(intptr_t const) + ( count * prime[found-2] + 1 ) * sizeof(__complex double const));
    object->log2n = setup ? log2n : 0;
    switch ( object->log2n ) {
        case 0:
            object->count = found;
            memcpy(object->prime, prime, object->count * sizeof(intptr_t const));
            dft_create_table(object->prime[object->count-2],
                             object->prime[object->count-2],
                             object->dense = __malloc__(object->prime[object->count-2] * object->prime[object->count-2] * sizeof(__complex double const)),
                             object->prime[object->count-2]);
            break;
        default:
            object->count = found - object->log2n + 1;
            object->prime[object->count-1] = 1;
            object->prime[object->count-2] = 1 << object->log2n;
            for ( register intptr_t k = object->count-2 ; 0 < k -- ;  )
                object->prime[k] = object->prime[k+1] * prime[object->log2n+k] / prime[object->log2n+k+1];
            assert(count == object->prime[0]);
            object->setup = setup;
            break;
    }
    dft_create_table(prime[0],
                     prime[found-2],
                     ddft_table(object),
                     prime[0]);
    return object;
}
__attribute__((overloadable))
void dft_destroy(ddft_t const * __nonnull const object) {
    switch ( object->log2n ) {
        case 0:
            __free__(object->dense);
            break;
        default:
            vDSP_destroy_fftsetupD(object->setup);
            break;
    }
    __free__(object);
}
__attribute__((overloadable))
void dft_dump(ddft_t const * __nonnull const object) {
    FILE * __nonnull const output = stderr;
    fprintf(output, "DDFT\r\n");
    fprintf(output, " - Prime: [%ld", object->prime[0]);
    for ( intptr_t k = 1, K = object->count ; k < K ; ++ k )
        fprintf(output, ", %ld", object->prime[k]);
    fprintf(output, "]\r\n");
    switch ( object->log2n ) {
        case 0:
            fprintf(output, " - Core: BLAS { count: %ld, table: %p }\r\n", object->prime[object->count-2], object->dense),
            dft_dump(output,
                     object->prime[object->count-2],
                     object->prime[object->count-2],
                     object->dense,
                     object->prime[object->count-2]);
            break;
        default:
            fprintf(output, " - Core: vDSP { log2n: %ld, setup: %p }\r\n", object->log2n, object->setup);
            break;
    }
    fprintf(output, " - Table:\r\n");
    dft_dump(output,
             object->prime[0],
             object->prime[object->count-2],
             ddft_table(object),
             object->prime[0]);
    fflush(output);
}
__attribute__((always_inline, overloadable))
void dft_forward(ddft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable w) {
    dft_forward(object, scale, x, 1, y, 1, w);
}
__attribute__((always_inline, overloadable))
void dft_inverse(ddft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable w) {
    dft_inverse(object, scale, x, 1, y, 1, w);
}
__attribute__((always_inline, overloadable))
void dft_forward(ddft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable w) {
    if ( !w )
        w = alloca(object->prime[0] * sizeof(__complex double const));
    assert(w);
    switch ( object->log2n ) {
        case 0:
            dit_forward(x, incx, y, incy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        ^(__complex double const * const __nonnull _x, intptr_t const _incx,
                          __complex double       * const __nonnull _y, intptr_t const _incy,
                          intptr_t const _count) {
                assert(_count == object->prime[object->count-2]);
                assert(_x != _y);
                zgemv_("N",
                       object->prime + object->count - 2, object->prime + object->count - 2,
                       &one,
                       object->dense, object->prime + object->count - 2,
                       _x, &_incx,
                       &zero,
                       _y, &_incy);
            });
            break;
        default:
            dit_forward(x, incx, y, incy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        ^(__complex double const * const __nonnull _x, intptr_t const _incx,
                          __complex double       * const __nonnull _y, intptr_t const _incy,
                          intptr_t const _count) {
                assert(_count == 1 << object->log2n);
                if ( _x == _y )
                    vDSP_fft_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_y),
                        .imagp = &__imag(*_y)
                    }, 2 * _incy, object->log2n, FFT_FORWARD);
                else
                    vDSP_fft_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_x),
                        .imagp = &__imag(*_x)
                    }, 2 * _incx, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_y),
                        .imagp = &__imag(*_y)
                    }, 2 * _incy, object->log2n, FFT_FORWARD);
            });
            break;
            
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            zscal_(object->prime, (__complex double const[]){simd_recip((double const)object->prime[0])}, y, &incy);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            zscal_(object->prime, (__complex double const[]){simd_rsqrt((double const)object->prime[0])}, y, &incy);
            break;
    }
}
__attribute__((always_inline, overloadable))
void dft_inverse(ddft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable w) {
    if ( !w )
        w = alloca(object->prime[0] * sizeof(__complex double const));
    assert(w);
    switch ( object->log2n ) {
        case 0:
            dit_inverse(x, incx, y, incy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        ^(__complex double const * const __nonnull _x, intptr_t const _incx,
                          __complex double       * const __nonnull _y, intptr_t const _incy,
                          intptr_t const _count) {
                assert(_count == object->prime[object->count-2]);
                assert(_x != _y);
                zgemv_("C",
                       object->prime + object->count - 2, object->prime + object->count - 2,
                       &one,
                       object->dense, object->prime + object->count - 2,
                       _x, &_incx,
                       &zero,
                       _y, &_incy);
            });
            break;
        default:
            dit_inverse(x, incx, y, incy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        ^(__complex double const * const __nonnull _x, intptr_t const _incx,
                          __complex double       * const __nonnull _y, intptr_t const _incy,
                          intptr_t const _count) {
                assert(_count == 1 << object->log2n);
                if ( _x == _y )
                    vDSP_fft_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_y),
                        .imagp = &__imag(*_y)
                    }, 2 * _incy, object->log2n, FFT_INVERSE);
                else
                    vDSP_fft_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_x),
                        .imagp = &__imag(*_x)
                    }, 2 * _incx, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_y),
                        .imagp = &__imag(*_y)
                    }, 2 * _incy, object->log2n, FFT_INVERSE);
            });
            break;
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            zscal_(object->prime, (__complex double const[]){simd_recip((double const)object->prime[0])}, y, &incy);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            zscal_(object->prime, (__complex double const[]){simd_rsqrt((double const)object->prime[0])}, y, &incy);
            break;
    }
}
__attribute__((always_inline, overloadable))
void dft_forward(ddft_t const * __nonnull const object, dft_scale_t const scale, intptr_t const nrhs,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable w) {
    if ( !w )
        w = alloca(nrhs * object->prime[0] * sizeof(__complex double const));
    assert(w);
    switch ( object->log2n ) {
        case 0:
            dit_forward(x, 1, ldx,
                        y, 1, ldy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        nrhs,
                        ^(__complex double const * __nonnull const _x, intptr_t const _incx, intptr_t const _ldx,
                          __complex double       * __nonnull const _y, intptr_t const _incy, intptr_t const _ldy,
                          intptr_t const _count, intptr_t const _nrhs) {
                assert(_count == object->prime[object->count-2]);
                assert(_x != _y);
                if ( simd_all(simd_make_long2(_incx, _incy) == 1) )
                    zgemm_("N", "N",
                           object->prime + object->count - 2, &_nrhs, object->prime + object->count - 2,
                           &one,
                           object->dense, object->prime + object->count - 2,
                           _x, &_ldx,
                           &zero,
                           _y, &_ldy);
                else for ( intptr_t k = 0 ; k < _nrhs ; ++ k )
                    zgemv_("N",
                           object->prime + object->count - 2, object->prime + object->count - 2,
                           &one,
                           object->dense, object->prime + object->count - 2,
                           _x + k * _ldx, &_incx,
                           &zero,
                           _y + k * _ldy, &_incy);
            });
            break;
        default:
            dit_forward(x, 1, ldx,
                        y, 1, ldy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        nrhs,
                        ^(__complex double const * __nonnull const _x, intptr_t const _incx, intptr_t const _ldx,
                          __complex double       * __nonnull const _y, intptr_t const _incy, intptr_t const _ldy,
                          intptr_t const _count, intptr_t const _nrhs) {
                assert(_count == 1 << object->log2n);
                if ( _x == _y )
                    vDSP_fftm_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_y),
                        .imagp = &__imag(*_y)
                    }, 2 * _incy, 2 * _ldy, object->log2n, _nrhs, FFT_FORWARD);
                else
                    vDSP_fftm_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_x),
                        .imagp = &__imag(*_x)
                    }, 2 * _incx, 2 * _ldx, &(DSPDoubleSplitComplex const) {
                        .realp = &__real(*_y),
                        .imagp = &__imag(*_y)
                    }, 2 * _incy, 2 * _ldy, object->log2n, _nrhs, FFT_FORWARD);
            });
            break;
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            for ( register intptr_t k = 0 ; k < nrhs ; ++ k )
                zscal_(object->prime, (__complex double const[]){simd_recip((double const)object->prime[0])}, y + k * ldy, &1[_]);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            for ( register intptr_t k = 0 ; k < nrhs ; ++ k )
                zscal_(object->prime, (__complex double const[]){simd_rsqrt((double const)object->prime[0])}, y + k * ldy, &1[_]);
            break;
    }
}
__attribute__((always_inline, overloadable))
void dft_inverse(ddft_t const * __nonnull const object, dft_scale_t const scale, intptr_t const nrhs,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable w) {
    if ( !w )
        w = alloca(nrhs * object->prime[0] * sizeof(__complex double const));
    assert(w);
    switch ( object->log2n ) {
        case 0:
            dit_inverse(x, 1, ldx,
                        y, 1, ldy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        nrhs,
                        ^(__complex double const * __nonnull const _x, intptr_t const _incx, intptr_t const _ldx,
                          __complex double       * __nonnull const _y, intptr_t const _incy, intptr_t const _ldy,
                          intptr_t const _count, intptr_t _nrhs) {
                assert(_count == object->prime[object->count-2]);
                assert(_x != _y);
                if ( simd_all(simd_make_long2(_incx, _incy) == 1) )
                    zgemm_("C", "N",
                           object->prime + object->count - 2, &nrhs, object->prime + object->count - 2,
                           &one,
                           object->dense, object->prime + object->count - 2,
                           _x, &_ldx,
                           &zero,
                           _y, &_ldy);
                else for ( intptr_t k = 0 ; k < _nrhs ; ++ k )
                    zgemv_("C",
                           object->prime + object->count - 2, object->prime + object->count - 2,
                           &one,
                           object->dense, object->prime + object->count - 2,
                           _x + k * _ldx, &_incx,
                           &zero,
                           _y + k * _ldy, &_incy);
            });
            break;
        default:
            dit_inverse(x, 1, ldx,
                        y, 1, ldy,
                        ddft_table(object), object->prime[0],
                        w,
                        object->prime,
                        nrhs,
                        ^(__complex double const * __nonnull const _x, intptr_t const _incx, intptr_t const _ldx,
                          __complex double       * __nonnull const _y, intptr_t const _incy, intptr_t const _ldy,
                          intptr_t const _count, intptr_t const _nrhs) {
                assert(_count == 1 << object->log2n);
            if ( _x == _y )
                vDSP_fftm_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                    .realp = &__real(*_y),
                    .imagp = &__imag(*_y)
                }, 2 * _incy, 2 * _ldy, object->log2n, _nrhs, FFT_INVERSE);
            else
                vDSP_fftm_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                    .realp = &__real(*_x),
                    .imagp = &__imag(*_x)
                }, 2 * _incx, 2 * _ldx, &(DSPDoubleSplitComplex const) {
                    .realp = &__real(*_y),
                    .imagp = &__imag(*_y)
                }, 2 * _incy, 2 * _ldy, object->log2n, _nrhs, FFT_INVERSE);
            });
            break;
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            for ( register intptr_t k = 0 ; k < nrhs ; ++ k )
                zscal_(object->prime, (__complex double const[]){simd_recip((double const)object->prime[0])}, y + k * ldy, &1[_]);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            for ( register intptr_t k = 0 ; k < nrhs ; ++ k )
                zscal_(object->prime, (__complex double const[]){simd_rsqrt((double const)object->prime[0])}, y + k * ldy, &1[_]);
            break;
    }
}

// MARK: BFS
__attribute__((overloadable))
bdft_t const * __nonnull const bdft_create(intptr_t const * __nonnull const count) {
    intptr_t depth = 0;
    while ( 1 < count[++depth] );
    bdft_t * __nonnull const object = __malloc__(sizeof(intptr_t const) + depth * sizeof(sparse_matrix_double_complex const));
    *(intptr_t*__nonnull const)&object->count = depth;
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
        *(sparse_matrix_double_complex*__nonnull const)(object->prime + i) = sparse_matrix_create_double_complex(*count, *count);
        for ( register intptr_t c = 0 ; c < n ; ++ c ) {
            register __complex double * __nonnull const V = (__complex double * __nonnull const)R;
            register sparse_dimension U = 0;
            for ( register intptr_t r = 0 ; r < m ; ++ r ) {
                __complex double e = 0;
                sincospi(-2.0 * c * r / m, &__imag(e), &__real(e));
                for ( register intptr_t j = 0 ; j < *count ; j += m, ++ U ) {
                    P[U] = j + r;
                    Q[U] = j + c * k + r % k;
                    V[U] = e;
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
bdft_t const * __nonnull const bdft_create(intptr_t const count) {
    register intptr_t*__nonnull const prime = alloca(sizeof(intptr_t const) * (ilog2n(count) + 1));
    assert(floor(log2(count)) <= ilog2n(count) + 1);
    register intptr_t const found = pd(count, prime);
    assert(found <= ilog2n(count) + 1);
    return bdft_create(prime);
}
__attribute__((overloadable))
void dft_dump(bdft_t const * __nonnull const object) {
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
            fprintf(output, "\t[%.2lf%c%.2lfj", __real(C[r*n]), __imag(C[r*n])<0?'-':'+', fabs(__imag(C[r*n])));
            for ( intptr_t c = 1 ; c < n ; ++ c)
                fprintf(output, ",%.2lf%c%.2lfj", __real(C[r*n+c]), __imag(C[r*n+c])<0?'-':'+', fabs(__imag(C[r*n+c])));
            fprintf(output, "],\r\n");
        }
        fprintf(output, "]\r\n");
        __free__(W);
    }
}
__attribute__((overloadable))
void dft_destroy(bdft_t const * __nonnull const object) {
    for ( intptr_t k = 0, K = object->count ; k < K ; ++ k )
        sparse_matrix_destroy(object->prime[k]);
    __free__(object);
}
__attribute__((always_inline, overloadable))
void dft_forward(bdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable w) {
    dft_forward(object, scale, x, 1, y, 1, w);
}
__attribute__((always_inline, overloadable))
void dft_inverse(bdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable w) {
    dft_inverse(object, scale, x, 1, y, 1, w);
}
__attribute__((always_inline, overloadable))
void dft_forward(bdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable w) {
    intptr_t const count = dft_count(object);
    if ( !w )
        w = alloca(count * 2 * sizeof(__complex double const));
    assert(w);
    __complex double * __nonnull const z[] = {w, w + count};
    __copy__(x, incx, z[object->count&1], 1, count);
    for ( register intptr_t k = object->count ; 0 < k -- ; )
        sparse_matrix_vector_product_dense_double_complex(CblasNoTrans, 1, object->prime[k],
                                                          z[(~k)&1], 1,
                                                          memset(z[k&1], 0, count * sizeof(__complex double const)), 1);
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            zscal_((intptr_t const[]){count}, (__complex double const[]){simd_recip((double const)count)}, z[0], _ + 1);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            zscal_((intptr_t const[]){count}, (__complex double const[]){simd_rsqrt((double const)count)}, z[0], _ + 1);
            break;
    }
    __copy__(z[0], 1, y, incy, count);
}
__attribute__((always_inline, overloadable))
void dft_inverse(bdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable w) {
    intptr_t const count = dft_count(object);
    if ( !w )
        w = alloca(count * 2 * sizeof(__complex double const));
    assert(w);
    __complex double * __nonnull const z[] = {w, w + count};
    __copy__(x, incx, z[0], 1, count);
    for ( register intptr_t k = 0 ; k < object->count ; ++ k )
        sparse_matrix_vector_product_dense_double_complex(CblasConjTrans, 1, object->prime[k],
                                                          z[k&1], 1,
                                                          memset(z[(~k)&1], 0, count * sizeof(__complex double const)), 1);
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            zscal_((intptr_t const[]){count}, (__complex double const[]){simd_recip((double const)count)}, z[object->count&1], _ + 1);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            zscal_((intptr_t const[]){count}, (__complex double const[]){simd_rsqrt((double const)count)}, z[object->count&1], _ + 1);
            break;
    }
    __copy__(z[object->count&1], 1, y, incy, count);
}
__attribute__((always_inline, overloadable))
void dft_forward(bdft_t const * __nonnull const object, dft_scale_t const scale, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable w) {
    intptr_t const count = dft_count(object);
    if ( !w )
        w = alloca(count * n * 2 * sizeof(__complex double const));
    assert(w);
    __complex double * __nonnull const z[] = {w, w + count * n};
    __mcopy__(x, ldx, z[object->count&1], count, n, count);
    for ( register intptr_t k = object->count ; 0 < k -- ; )
        sparse_matrix_product_dense_double_complex(CblasColMajor, CblasNoTrans, n, 1, object->prime[k],
                                                   z[(~k)&1], count,
                                                   memset(z[k&1], 0, count * n * sizeof(__complex double const)), count);
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            zscal_((intptr_t const[]){count*n}, (__complex double const[]){simd_recip((double const)count)}, z[0], _ + 1);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            zscal_((intptr_t const[]){count*n}, (__complex double const[]){simd_rsqrt((double const)count)}, z[0], _ + 1);
            break;
    }
    __mcopy__(z[0], count, y, ldy, n, count);
}
__attribute__((overloadable))
void dft_inverse(bdft_t const * __nonnull const object, dft_scale_t const scale, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable w) {
    intptr_t const count = dft_count(object);
    if ( !w )
        w = alloca(count * n * 2 * sizeof(__complex double const));
    __complex double * __nonnull const z[] = {w, w + count * n};
    __mcopy__(x, ldx, z[object->count&1], count, n, count);
    __conj__(z[object->count&1], 1, z[object->count&1], 1, n * count);
    for ( register intptr_t k = object->count ; 0 < k -- ; )
        sparse_matrix_product_dense_double_complex(CblasColMajor, CblasNoTrans, n, 1, object->prime[k],
                                                   z[(~k)&1], count,
                                                   memset(z[k&1], 0, count * n * sizeof(__complex double const)), count);
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            zscal_((intptr_t const[]){count*n}, (__complex double const[]){simd_recip((double const)count)}, z[0], _ + 1);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            zscal_((intptr_t const[]){count*n}, (__complex double const[]){simd_rsqrt((double const)count)}, z[0], _ + 1);
            break;
    }
    __conj__(z[0], 1, z[0], 1, n * count);
    __mcopy__(z[0], count, y, ldy, n, count);
//  CblasConjTrans isn't available for sparse_matrix_product_dense_double_complex
//    __mcopy__(x, ldx, z[0], count, n, count);
//    for ( register intptr_t k = 0 ; k < object->count ; ++ k )
//        sparse_matrix_product_dense_double_complex(CblasColMajor, CblasConjTrans, n, 1, object->prime[k],
//                                                   z[k&1], count,
//                                                   memset(z[(~k)&1], 0, count * n * sizeof(__complex double const)), count);
//    __mcopy__(z[object->count&1], count, y, ldy, n, count);
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
// MARK: DSP
pdft_t const * __nullable const pdft_create(intptr_t const count) {
    register intptr_t const log2n = ilog2n(count);
    if ( 1 << log2n != count )
        return 0;
    FFTSetupD const setup = vDSP_create_fftsetupD(log2n, FFT_RADIX2);
    if ( !setup )
        return 0;
    pdft_t * __nonnull const object = __malloc__(sizeof(pdft_t const));
    object->log2n = log2n;
    object->setup = setup;
    return object;
}
__attribute__((always_inline, overloadable))
intptr_t const dft_count(pdft_t const * __nonnull const object) {
    return 1 << object->log2n;
}
__attribute__((always_inline, overloadable))
void dft_destroy(pdft_t const * __nonnull const object) {
    vDSP_destroy_fftsetupD(object->setup);
    __free__(object);
}
__attribute__((always_inline, overloadable))
void dft_forward(pdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable const w) {
    dft_forward(object, scale, x, 1, y, 1, w);
}
__attribute__((always_inline, overloadable))
void dft_inverse(pdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x,
                 __complex double       * __nonnull const y,
                 __complex double       * __nullable const w) {
    dft_inverse(object, scale, x, 1, y, 1, w);
}
__attribute__((always_inline, overloadable))
void dft_forward(pdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const w) {
    if ( x != y ) {
        if ( w )
            vDSP_fft_zoptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, FFT_FORWARD);
        else
            vDSP_fft_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, object->log2n, FFT_FORWARD);
    } else if ( incx != incy ) {
        abort();
    } else {
        if ( w )
            vDSP_fft_ziptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, FFT_FORWARD);
        else
            vDSP_fft_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, object->log2n, FFT_FORWARD);
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N: {
            intptr_t const count = dft_count(object);
            zscal_(&count, (__complex double[]){simd_recip((double const)count)}, y, &incy);
            break;
        }
        case DFT_SCALE_ONE_OVER_SQRT_N: {
            intptr_t const count = dft_count(object);
            zscal_(&count, (__complex double[]){simd_rsqrt((double const)count)}, y, &incy);
            break;
        }
    }
}
__attribute__((overloadable))
void dft_inverse(pdft_t const * __nonnull const object, dft_scale_t const scale,
                 __complex double const * __nonnull const x, intptr_t const incx,
                 __complex double       * __nonnull const y, intptr_t const incy,
                 __complex double       * __nullable const w) {
    if ( x != y ) {
        if ( w )
            vDSP_fft_zoptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2 * incx, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2 * incy, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, FFT_INVERSE);
        else
            vDSP_fft_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2 * incx, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2 * incy, object->log2n, FFT_INVERSE);
    } else if ( incx != incy ) {
        abort();
    } else {
        if ( w )
            vDSP_fft_ziptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2 * incy, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, FFT_INVERSE);
        else
            vDSP_fft_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2 * incy, object->log2n, FFT_INVERSE);
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N: {
            intptr_t const count = dft_count(object);
            zscal_(&count, (__complex double[]){simd_recip((double const)count)}, y, &incy);
            break;
        }
        case DFT_SCALE_ONE_OVER_SQRT_N: {
            intptr_t const count = dft_count(object);
            zscal_(&count, (__complex double[]){simd_rsqrt((double const)count)}, y, &incy);
            break;
        }
    }
}
__attribute__((always_inline, overloadable))
void dft_forward(pdft_t const * __nonnull const object, dft_scale_t const scale, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const w) {
    if ( x != y ) {
        if ( w )
            vDSP_fftm_zoptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2, 2 * ldx, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, n, FFT_FORWARD);
        else
            vDSP_fftm_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2, 2 * ldx, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, object->log2n, n, FFT_FORWARD);
    } else if ( ldx != ldy ) {
        abort();
    } else {
        if ( w )
            vDSP_fftm_ziptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, n, FFT_FORWARD);
        else
            vDSP_fftm_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, object->log2n, n, FFT_FORWARD);
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            for ( intptr_t count = dft_count(object), k = 0, K = n ; k < K ; ++ k )
                zscal_(&count, (__complex double[]){simd_recip((double const)count)}, y + k * ldy, _ + 1);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            for ( intptr_t count = dft_count(object), k = 0, K = n ; k < K ; ++ k )
                zscal_(&count, (__complex double[]){simd_rsqrt((double const)count)}, y + k * ldy, _ + 1);
            break;
    }
}
__attribute__((always_inline, overloadable))
void dft_inverse(pdft_t const * __nonnull const object, dft_scale_t const scale, intptr_t const n,
                 __complex double const * __nonnull const x, intptr_t const ldx,
                 __complex double       * __nonnull const y, intptr_t const ldy,
                 __complex double       * __nullable const w) {
    if ( x != y ) {
        if ( w )
            vDSP_fftm_zoptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2, 2 * ldx, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, n, FFT_INVERSE);
        else
            vDSP_fftm_zopD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*x),
                .imagp = &__imag(*x)
            }, 2, 2 * ldx, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, object->log2n, n, FFT_INVERSE);
    } else if ( ldx != ldy ) {
        abort();
    } else {
        if ( w )
            vDSP_fftm_ziptD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*w),
                .imagp = &__imag(*w)
            }, object->log2n, n, FFT_INVERSE);
        else
            vDSP_fftm_zipD(object->setup, &(DSPDoubleSplitComplex const) {
                .realp = &__real(*y),
                .imagp = &__imag(*y)
            }, 2, 2 * ldy, object->log2n, n, FFT_INVERSE);
    }
    switch ( scale ) {
        case DFT_SCALE_ONE:
            break;
        case DFT_SCALE_ONE_OVER_N:
            for ( intptr_t count = dft_count(object), k = 0, K = n ; k < K ; ++ k )
                zscal_(&count, (__complex double[]){simd_recip((double const)count)}, y + k * ldy, _ + 1);
            break;
        case DFT_SCALE_ONE_OVER_SQRT_N:
            for ( intptr_t count = dft_count(object), k = 0, K = n ; k < K ; ++ k )
                zscal_(&count, (__complex double[]){simd_rsqrt((double const)count)}, y + k * ldy, _ + 1);
            break;
    }
}
