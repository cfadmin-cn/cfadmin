#include "lcrypt.h"

/* the eight DES S-boxes */

static uint32_t SB1[64] = {
  0x01010400, 0x00000000, 0x00010000, 0x01010404,
  0x01010004, 0x00010404, 0x00000004, 0x00010000,
  0x00000400, 0x01010400, 0x01010404, 0x00000400,
  0x01000404, 0x01010004, 0x01000000, 0x00000004,
  0x00000404, 0x01000400, 0x01000400, 0x00010400,
  0x00010400, 0x01010000, 0x01010000, 0x01000404,
  0x00010004, 0x01000004, 0x01000004, 0x00010004,
  0x00000000, 0x00000404, 0x00010404, 0x01000000,
  0x00010000, 0x01010404, 0x00000004, 0x01010000,
  0x01010400, 0x01000000, 0x01000000, 0x00000400,
  0x01010004, 0x00010000, 0x00010400, 0x01000004,
  0x00000400, 0x00000004, 0x01000404, 0x00010404,
  0x01010404, 0x00010004, 0x01010000, 0x01000404,
  0x01000004, 0x00000404, 0x00010404, 0x01010400,
  0x00000404, 0x01000400, 0x01000400, 0x00000000,
  0x00010004, 0x00010400, 0x00000000, 0x01010004
};

static uint32_t SB2[64] = {
  0x80108020, 0x80008000, 0x00008000, 0x00108020,
  0x00100000, 0x00000020, 0x80100020, 0x80008020,
  0x80000020, 0x80108020, 0x80108000, 0x80000000,
  0x80008000, 0x00100000, 0x00000020, 0x80100020,
  0x00108000, 0x00100020, 0x80008020, 0x00000000,
  0x80000000, 0x00008000, 0x00108020, 0x80100000,
  0x00100020, 0x80000020, 0x00000000, 0x00108000,
  0x00008020, 0x80108000, 0x80100000, 0x00008020,
  0x00000000, 0x00108020, 0x80100020, 0x00100000,
  0x80008020, 0x80100000, 0x80108000, 0x00008000,
  0x80100000, 0x80008000, 0x00000020, 0x80108020,
  0x00108020, 0x00000020, 0x00008000, 0x80000000,
  0x00008020, 0x80108000, 0x00100000, 0x80000020,
  0x00100020, 0x80008020, 0x80000020, 0x00100020,
  0x00108000, 0x00000000, 0x80008000, 0x00008020,
  0x80000000, 0x80100020, 0x80108020, 0x00108000
};

static uint32_t SB3[64] = {
  0x00000208, 0x08020200, 0x00000000, 0x08020008,
  0x08000200, 0x00000000, 0x00020208, 0x08000200,
  0x00020008, 0x08000008, 0x08000008, 0x00020000,
  0x08020208, 0x00020008, 0x08020000, 0x00000208,
  0x08000000, 0x00000008, 0x08020200, 0x00000200,
  0x00020200, 0x08020000, 0x08020008, 0x00020208,
  0x08000208, 0x00020200, 0x00020000, 0x08000208,
  0x00000008, 0x08020208, 0x00000200, 0x08000000,
  0x08020200, 0x08000000, 0x00020008, 0x00000208,
  0x00020000, 0x08020200, 0x08000200, 0x00000000,
  0x00000200, 0x00020008, 0x08020208, 0x08000200,
  0x08000008, 0x00000200, 0x00000000, 0x08020008,
  0x08000208, 0x00020000, 0x08000000, 0x08020208,
  0x00000008, 0x00020208, 0x00020200, 0x08000008,
  0x08020000, 0x08000208, 0x00000208, 0x08020000,
  0x00020208, 0x00000008, 0x08020008, 0x00020200
};

static uint32_t SB4[64] = {
  0x00802001, 0x00002081, 0x00002081, 0x00000080,
  0x00802080, 0x00800081, 0x00800001, 0x00002001,
  0x00000000, 0x00802000, 0x00802000, 0x00802081,
  0x00000081, 0x00000000, 0x00800080, 0x00800001,
  0x00000001, 0x00002000, 0x00800000, 0x00802001,
  0x00000080, 0x00800000, 0x00002001, 0x00002080,
  0x00800081, 0x00000001, 0x00002080, 0x00800080,
  0x00002000, 0x00802080, 0x00802081, 0x00000081,
  0x00800080, 0x00800001, 0x00802000, 0x00802081,
  0x00000081, 0x00000000, 0x00000000, 0x00802000,
  0x00002080, 0x00800080, 0x00800081, 0x00000001,
  0x00802001, 0x00002081, 0x00002081, 0x00000080,
  0x00802081, 0x00000081, 0x00000001, 0x00002000,
  0x00800001, 0x00002001, 0x00802080, 0x00800081,
  0x00002001, 0x00002080, 0x00800000, 0x00802001,
  0x00000080, 0x00800000, 0x00002000, 0x00802080
};

static uint32_t SB5[64] = {
  0x00000100, 0x02080100, 0x02080000, 0x42000100,
  0x00080000, 0x00000100, 0x40000000, 0x02080000,
  0x40080100, 0x00080000, 0x02000100, 0x40080100,
  0x42000100, 0x42080000, 0x00080100, 0x40000000,
  0x02000000, 0x40080000, 0x40080000, 0x00000000,
  0x40000100, 0x42080100, 0x42080100, 0x02000100,
  0x42080000, 0x40000100, 0x00000000, 0x42000000,
  0x02080100, 0x02000000, 0x42000000, 0x00080100,
  0x00080000, 0x42000100, 0x00000100, 0x02000000,
  0x40000000, 0x02080000, 0x42000100, 0x40080100,
  0x02000100, 0x40000000, 0x42080000, 0x02080100,
  0x40080100, 0x00000100, 0x02000000, 0x42080000,
  0x42080100, 0x00080100, 0x42000000, 0x42080100,
  0x02080000, 0x00000000, 0x40080000, 0x42000000,
  0x00080100, 0x02000100, 0x40000100, 0x00080000,
  0x00000000, 0x40080000, 0x02080100, 0x40000100
};

static uint32_t SB6[64] = {
  0x20000010, 0x20400000, 0x00004000, 0x20404010,
  0x20400000, 0x00000010, 0x20404010, 0x00400000,
  0x20004000, 0x00404010, 0x00400000, 0x20000010,
  0x00400010, 0x20004000, 0x20000000, 0x00004010,
  0x00000000, 0x00400010, 0x20004010, 0x00004000,
  0x00404000, 0x20004010, 0x00000010, 0x20400010,
  0x20400010, 0x00000000, 0x00404010, 0x20404000,
  0x00004010, 0x00404000, 0x20404000, 0x20000000,
  0x20004000, 0x00000010, 0x20400010, 0x00404000,
  0x20404010, 0x00400000, 0x00004010, 0x20000010,
  0x00400000, 0x20004000, 0x20000000, 0x00004010,
  0x20000010, 0x20404010, 0x00404000, 0x20400000,
  0x00404010, 0x20404000, 0x00000000, 0x20400010,
  0x00000010, 0x00004000, 0x20400000, 0x00404010,
  0x00004000, 0x00400010, 0x20004010, 0x00000000,
  0x20404000, 0x20000000, 0x00400010, 0x20004010
};

static uint32_t SB7[64] = {
  0x00200000, 0x04200002, 0x04000802, 0x00000000,
  0x00000800, 0x04000802, 0x00200802, 0x04200800,
  0x04200802, 0x00200000, 0x00000000, 0x04000002,
  0x00000002, 0x04000000, 0x04200002, 0x00000802,
  0x04000800, 0x00200802, 0x00200002, 0x04000800,
  0x04000002, 0x04200000, 0x04200800, 0x00200002,
  0x04200000, 0x00000800, 0x00000802, 0x04200802,
  0x00200800, 0x00000002, 0x04000000, 0x00200800,
  0x04000000, 0x00200800, 0x00200000, 0x04000802,
  0x04000802, 0x04200002, 0x04200002, 0x00000002,
  0x00200002, 0x04000000, 0x04000800, 0x00200000,
  0x04200800, 0x00000802, 0x00200802, 0x04200800,
  0x00000802, 0x04000002, 0x04200802, 0x04200000,
  0x00200800, 0x00000000, 0x00000002, 0x04200802,
  0x00000000, 0x00200802, 0x04200000, 0x00000800,
  0x04000002, 0x04000800, 0x00000800, 0x00200002
};

static uint32_t SB8[64] = {
  0x10001040, 0x00001000, 0x00040000, 0x10041040,
  0x10000000, 0x10001040, 0x00000040, 0x10000000,
  0x00040040, 0x10040000, 0x10041040, 0x00041000,
  0x10041000, 0x00041040, 0x00001000, 0x00000040,
  0x10040000, 0x10000040, 0x10001000, 0x00001040,
  0x00041000, 0x00040040, 0x10040040, 0x10041000,
  0x00001040, 0x00000000, 0x00000000, 0x10040040,
  0x10000040, 0x10001000, 0x00041040, 0x00040000,
  0x00041040, 0x00040000, 0x10041000, 0x00001000,
  0x00000040, 0x10040040, 0x00001000, 0x00041040,
  0x10001000, 0x00000040, 0x10000040, 0x10040000,
  0x10040040, 0x10000000, 0x00040000, 0x10001040,
  0x00000000, 0x10041040, 0x00040040, 0x10000040,
  0x10040000, 0x10001000, 0x10001040, 0x00000000,
  0x10041040, 0x00041000, 0x00041000, 0x00001040,
  0x00001040, 0x00040040, 0x10000000, 0x10041000
};

/* PC1: left and right halves bit-swap */

static uint32_t LHs[16] = {
  0x00000000, 0x00000001, 0x00000100, 0x00000101,
  0x00010000, 0x00010001, 0x00010100, 0x00010101,
  0x01000000, 0x01000001, 0x01000100, 0x01000101,
  0x01010000, 0x01010001, 0x01010100, 0x01010101
};

static uint32_t RHs[16] = {
  0x00000000, 0x01000000, 0x00010000, 0x01010000,
  0x00000100, 0x01000100, 0x00010100, 0x01010100,
  0x00000001, 0x01000001, 0x00010001, 0x01010001,
  0x00000101, 0x01000101, 0x00010101, 0x01010101,
};

/* platform-independant 32-bit integer manipulation macros */

#define GET_UINT32(n,b,i)            \
{                        \
  (n) = ( (uint32_t) (b)[(i)  ] << 24 )    \
    | ( (uint32_t) (b)[(i) + 1] << 16 )    \
    | ( (uint32_t) (b)[(i) + 2] <<  8 )    \
    | ( (uint32_t) (b)[(i) + 3]    );   \
}

#define PUT_UINT32(n,b,i)            \
{                        \
  (b)[(i) ] = (uint8_t) ( (n) >> 24 );     \
  (b)[(i) + 1] = (uint8_t) ( (n) >> 16 );    \
  (b)[(i) + 2] = (uint8_t) ( (n) >>  8 );    \
  (b)[(i) + 3] = (uint8_t) ( (n)     );    \
}

/* Initial Permutation macro */

#define DES_IP(X,Y)                      \
{                                \
  T = ((X >>  4) ^ Y) & 0x0F0F0F0F; Y ^= T; X ^= (T <<  4);   \
  T = ((X >> 16) ^ Y) & 0x0000FFFF; Y ^= T; X ^= (T << 16);   \
  T = ((Y >>  2) ^ X) & 0x33333333; X ^= T; Y ^= (T <<  2);   \
  T = ((Y >>  8) ^ X) & 0x00FF00FF; X ^= T; Y ^= (T <<  8);   \
  Y = ((Y << 1) | (Y >> 31)) & 0xFFFFFFFF;          \
  T = (X ^ Y) & 0xAAAAAAAA; Y ^= T; X ^= T;          \
  X = ((X << 1) | (X >> 31)) & 0xFFFFFFFF;          \
}

/* Final Permutation macro */

#define DES_FP(X,Y)                      \
{                                \
  X = ((X << 31) | (X >> 1)) & 0xFFFFFFFF;          \
  T = (X ^ Y) & 0xAAAAAAAA; X ^= T; Y ^= T;          \
  Y = ((Y << 31) | (Y >> 1)) & 0xFFFFFFFF;          \
  T = ((Y >>  8) ^ X) & 0x00FF00FF; X ^= T; Y ^= (T <<  8);   \
  T = ((Y >>  2) ^ X) & 0x33333333; X ^= T; Y ^= (T <<  2);   \
  T = ((X >> 16) ^ Y) & 0x0000FFFF; Y ^= T; X ^= (T << 16);   \
  T = ((X >>  4) ^ Y) & 0x0F0F0F0F; Y ^= T; X ^= (T <<  4);   \
}

/* DES round macro */

#define DES_ROUND(X,Y)              \
{                        \
  T = *SK++ ^ X;                \
  Y ^= SB8[ (T    ) & 0x3F ] ^        \
     SB6[ (T >>  8) & 0x3F ] ^        \
     SB4[ (T >> 16) & 0x3F ] ^        \
     SB2[ (T >> 24) & 0x3F ];        \
                        \
  T = *SK++ ^ ((X << 28) | (X >> 4));    \
  Y ^= SB7[ (T    ) & 0x3F ] ^        \
     SB5[ (T >>  8) & 0x3F ] ^        \
     SB3[ (T >> 16) & 0x3F ] ^        \
     SB1[ (T >> 24) & 0x3F ];        \
}

/* DES key schedule */

static inline void des_main_ks( uint32_t SK[32], const uint8_t key[8] ) {
  int i;
  uint32_t X, Y, T;

  GET_UINT32( X, key, 0 );
  GET_UINT32( Y, key, 4 );

  /* Permuted Choice 1 */

  T =  ((Y >>  4) ^ X) & 0x0F0F0F0F;  X ^= T; Y ^= (T <<  4);
  T =  ((Y    ) ^ X) & 0x10101010;  X ^= T; Y ^= (T   );

  X =   (LHs[ (X    ) & 0xF] << 3) | (LHs[ (X >>  8) & 0xF ] << 2)
    | (LHs[ (X >> 16) & 0xF] << 1) | (LHs[ (X >> 24) & 0xF ]   )
    | (LHs[ (X >>  5) & 0xF] << 7) | (LHs[ (X >> 13) & 0xF ] << 6)
    | (LHs[ (X >> 21) & 0xF] << 5) | (LHs[ (X >> 29) & 0xF ] << 4);

  Y =   (RHs[ (Y >>  1) & 0xF] << 3) | (RHs[ (Y >>  9) & 0xF ] << 2)
    | (RHs[ (Y >> 17) & 0xF] << 1) | (RHs[ (Y >> 25) & 0xF ]   )
    | (RHs[ (Y >>  4) & 0xF] << 7) | (RHs[ (Y >> 12) & 0xF ] << 6)
    | (RHs[ (Y >> 20) & 0xF] << 5) | (RHs[ (Y >> 28) & 0xF ] << 4);

  X &= 0x0FFFFFFF;
  Y &= 0x0FFFFFFF;

  /* calculate subkeys */

  for( i = 0; i < 16; i++ )
  {
    if( i < 2 || i == 8 || i == 15 )
    {
      X = ((X <<  1) | (X >> 27)) & 0x0FFFFFFF;
      Y = ((Y <<  1) | (Y >> 27)) & 0x0FFFFFFF;
    }
    else
    {
      X = ((X <<  2) | (X >> 26)) & 0x0FFFFFFF;
      Y = ((Y <<  2) | (Y >> 26)) & 0x0FFFFFFF;
    }

    *SK++ =   ((X <<  4) & 0x24000000) | ((X << 28) & 0x10000000)
        | ((X << 14) & 0x08000000) | ((X << 18) & 0x02080000)
        | ((X <<  6) & 0x01000000) | ((X <<  9) & 0x00200000)
        | ((X >>  1) & 0x00100000) | ((X << 10) & 0x00040000)
        | ((X <<  2) & 0x00020000) | ((X >> 10) & 0x00010000)
        | ((Y >> 13) & 0x00002000) | ((Y >>  4) & 0x00001000)
        | ((Y <<  6) & 0x00000800) | ((Y >>  1) & 0x00000400)
        | ((Y >> 14) & 0x00000200) | ((Y    ) & 0x00000100)
        | ((Y >>  5) & 0x00000020) | ((Y >> 10) & 0x00000010)
        | ((Y >>  3) & 0x00000008) | ((Y >> 18) & 0x00000004)
        | ((Y >> 26) & 0x00000002) | ((Y >> 24) & 0x00000001);

    *SK++ =   ((X << 15) & 0x20000000) | ((X << 17) & 0x10000000)
        | ((X << 10) & 0x08000000) | ((X << 22) & 0x04000000)
        | ((X >>  2) & 0x02000000) | ((X <<  1) & 0x01000000)
        | ((X << 16) & 0x00200000) | ((X << 11) & 0x00100000)
        | ((X <<  3) & 0x00080000) | ((X >>  6) & 0x00040000)
        | ((X << 15) & 0x00020000) | ((X >>  4) & 0x00010000)
        | ((Y >>  2) & 0x00002000) | ((Y <<  8) & 0x00001000)
        | ((Y >> 14) & 0x00000808) | ((Y >>  9) & 0x00000400)
        | ((Y   ) & 0x00000200) | ((Y <<  7) & 0x00000100)
        | ((Y >>  7) & 0x00000020) | ((Y >>  3) & 0x00000011)
        | ((Y <<  2) & 0x00000004) | ((Y >> 21) & 0x00000002);
  }
}

/* DES 64-bit block encryption/decryption */

static inline void des_crypt( const uint32_t SK[32], const uint8_t input[8], uint8_t output[8] ) {
  uint32_t X, Y, T;

  GET_UINT32( X, input, 0 );
  GET_UINT32( Y, input, 4 );

  DES_IP( X, Y );

  DES_ROUND( Y, X );  DES_ROUND( X, Y );
  DES_ROUND( Y, X );  DES_ROUND( X, Y );
  DES_ROUND( Y, X );  DES_ROUND( X, Y );
  DES_ROUND( Y, X );  DES_ROUND( X, Y );
  DES_ROUND( Y, X );  DES_ROUND( X, Y );
  DES_ROUND( Y, X );  DES_ROUND( X, Y );
  DES_ROUND( Y, X );  DES_ROUND( X, Y );
  DES_ROUND( Y, X );  DES_ROUND( X, Y );

  DES_FP( Y, X );

  PUT_UINT32( Y, output, 0 );
  PUT_UINT32( X, output, 4 );
}

static inline void des_key(lua_State *L, uint32_t SK[32]) {
  size_t keysz = 0;
  const void * key = luaL_checklstring(L, 1, &keysz);
  if (keysz != 8) {
    luaL_error(L, "Invalid key size %d, need 8 bytes", (int)keysz);
  }
  des_main_ks(SK, key);
}

int ldesencode(lua_State *L) {
  uint32_t SK[32];
  des_key(L, SK);

  size_t textsz = 0;
  const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 2, &textsz);
  size_t chunksz = (textsz + 8) & ~7;
  uint8_t tmp[SMALL_CHUNK];
  uint8_t *buffer = tmp;
  if (chunksz > SMALL_CHUNK) {
    buffer = lua_newuserdata(L, chunksz);
  }
  int i;
  for (i=0;i<(int)textsz-7;i+=8) {
    des_crypt(SK, text+i, buffer+i);
  }
  int bytes = textsz - i;
  uint8_t tail[8];
  int j;
  for (j=0;j<8;j++) {
    if (j < bytes) {
      tail[j] = text[i+j];
    } else if (j==bytes) {
      tail[j] = 0x80;
    } else {
      tail[j] = 0;
    }
  }
  des_crypt(SK, tail, buffer+i);
  lua_pushlstring(L, (const char *)buffer, chunksz);

  return 1;
}

int ldesdecode(lua_State *L) {
  uint32_t ESK[32];
  des_key(L, ESK);
  uint32_t SK[32];
  int i;
  for( i = 0; i < 32; i += 2 ) {
    SK[i] = ESK[30 - i];
    SK[i + 1] = ESK[31 - i];
  }
  size_t textsz = 0;
  const uint8_t *text = (const uint8_t *)luaL_checklstring(L, 2, &textsz);
  if ((textsz & 7) || textsz == 0) {
    return luaL_error(L, "Invalid des crypt text length %d", (int)textsz);
  }
  uint8_t tmp[SMALL_CHUNK];
  uint8_t *buffer = tmp;
  if (textsz > SMALL_CHUNK) {
    buffer = lua_newuserdata(L, textsz);
  }
  for (i=0;i<textsz;i+=8) {
    des_crypt(SK, text+i, buffer+i);
  }
  int padding = 1;
  for (i=textsz-1;i>=textsz-8;i--) {
    if (buffer[i] == 0) {
      padding++;
    } else if (buffer[i] == 0x80) {
      break;
    } else {
      return luaL_error(L, "Invalid des crypt text");
    }
  }
  if (padding > 8) {
    return luaL_error(L, "Invalid des crypt text");
  }
  lua_pushlstring(L, (const char *)buffer, textsz - padding);
  return 1;
}

static inline const EVP_CIPHER * des_get_cipher(size_t mode) {
  switch(mode){
    case 0:
      return EVP_desx_cbc();
    case 1:
      return EVP_des_cbc();
    case 2:
      return EVP_des_ecb();
    case 3:
      return EVP_des_cfb();
    case 4:
      return EVP_des_ofb();
    case 5:
      return EVP_des_ede();
    case 6:
      return EVP_des_ede3();
    case 7:
      return EVP_des_ede_ecb();
    case 8:
      return EVP_des_ede3_ecb();
  }
  return NULL;
}

// 加密函数
static inline int do_des_encrypt(lua_State *L, size_t des_mode, const uint8_t *key, const uint8_t *iv, const uint8_t *text, size_t tsize) {

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  EVP_CIPHER_CTX_set_padding(ctx, 0);

  if (1 != EVP_EncryptInit_ex(ctx, des_get_cipher(des_mode), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "des_encrypt_init failed.");
    return 2;
  }

  EVP_CIPHER_CTX_set_key_length(ctx, EVP_MAX_KEY_LENGTH);

  int out_size = tsize + EVP_MAX_BLOCK_LENGTH;
  uint8_t *out = lua_newuserdata(L, out_size);

  int update_len = out_size;
  if (0 == EVP_EncryptUpdate(ctx, out, &update_len, text, tsize)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "des_encrypt_update failed.");
    return 2;
  }

  int final_len = out_size;
  if (0 == EVP_EncryptFinal(ctx, out + update_len, &final_len)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "des_encrypt_final failed.");
    return 2;
  }

  lua_pushlstring(L, (const char*)out, update_len + final_len);
  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

// 解密函数
static inline int do_des_decrypt(lua_State *L, size_t des_mode, const uint8_t *key, const uint8_t *iv, const uint8_t *cipher, size_t csize) {

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  if (!ctx)
    return luaL_error(L, "allocate EVP failed.");

  EVP_CIPHER_CTX_set_padding(ctx, 0);

  if (1 != EVP_DecryptInit_ex(ctx, des_get_cipher(des_mode), NULL, key, iv)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "des_decrypt_init failed.");
    return 2;
  }

  EVP_CIPHER_CTX_set_key_length(ctx, EVP_MAX_KEY_LENGTH);

  int out_size = csize + EVP_MAX_BLOCK_LENGTH;
  uint8_t *out = lua_newuserdata(L, out_size);

  int update_len = out_size;
  if (1 != EVP_DecryptUpdate(ctx, out, &update_len, cipher, csize)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "des_decrypt_update failed.");
    return 2;
  }

  int final_len = out_size;
  if (1 != EVP_DecryptFinal_ex(ctx, out + update_len, &final_len)){
    EVP_CIPHER_CTX_cleanup(ctx);
    EVP_CIPHER_CTX_free(ctx);
    lua_pushnil(L);
    lua_pushstring(L, "des_decrypt_final failed.");
    return 2;
  }

  lua_pushlstring(L, (const char*)out, update_len + final_len);
  EVP_CIPHER_CTX_cleanup(ctx);
  EVP_CIPHER_CTX_free(ctx);
  return 1;
}

static inline int lua_getargs(lua_State *L, size_t *des_mode, uint8_t **text, size_t *tsize, uint8_t **iv, uint8_t **key) {
  *des_mode = luaL_checkinteger(L, 1);
  if (*des_mode > 8)
    return luaL_error(L, "Invalid des_mode");

  *key = (uint8_t *)luaL_checkstring(L, 2);
  if (!key)
    return luaL_error(L, "Invalid key");

  size_t size = 0;
  *text = (uint8_t *)luaL_checklstring(L, 3, &size);
  if (!text)
    return luaL_error(L, "Invalid text");
  *tsize = size;

  *iv = (uint8_t *)luaL_checkstring(L, 4);
  if (!iv)
    return luaL_error(L, "Invalid iv");

  return 1;
}

int ldes_encrypt(lua_State *L) {
  size_t text_sz = 0; size_t mode = 0;

  uint8_t* iv = NULL; uint8_t* key = NULL; uint8_t* text = NULL;

  return lua_getargs(L, &mode, &text, &text_sz, &iv, &key) && do_des_encrypt(L, mode, (const uint8_t*)key, (const uint8_t*)iv, (const uint8_t*)text, text_sz);
}

int ldes_decrypt(lua_State *L) {
  size_t cipher_sz = 0; size_t mode = 0;

  uint8_t* iv = NULL; uint8_t* key = NULL; uint8_t* cipher = NULL;

  return lua_getargs(L, &mode, &cipher, &cipher_sz, &iv, &key) && do_des_decrypt(L, mode, (const uint8_t*)key, (const uint8_t*)iv, (const uint8_t*)cipher, cipher_sz);
}