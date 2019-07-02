/*
 * This code implements the MD5 message-digest algorithm.
 * The algorithm is due to Ron Rivest.  This code was
 * written by Colin Plumb in 1993, no copyright is claimed.
 * This code is in the public domain; do with it what you wish.
 *
 * Equivalent code is available from RSA Data Security, Inc.
 * This code has been tested against that, and is equivalent,
 * except that you don't need to include two pages of legalese
 * with every copy.
 */

#ifndef _MD5_H_
#define _MD5_H_

#include "attributes.h"
#include "../../../src/core.h"

#define	MD5_BLOCK_LENGTH		64
#define	MD5_DIGEST_LENGTH		16

typedef struct MD5Context {
	u_int32_t state[4];			/* state */
	u_int64_t count;			/* number of bits, mod 2^64 */
	u_int8_t buffer[MD5_BLOCK_LENGTH];	/* input buffer */
} MD5_CTX;

static void MD5Init(MD5_CTX *);
static void MD5Update(MD5_CTX *, const u_int8_t *, size_t);
	// _BOUNDED(__string__,2,3);
static void MD5Final(u_int8_t [MD5_DIGEST_LENGTH], MD5_CTX *);
	// _BOUNDED(__minbytes__,1,MD5_DIGEST_LENGTH);
static void MD5Transform(u_int32_t [4], const u_int8_t [MD5_BLOCK_LENGTH]);
	// _BOUNDED(__minbytes__,1,4)
	// _BOUNDED(__minbytes__,2,MD5_BLOCK_LENGTH);

#endif /* _MD5_H_ */
