#define LUA_LIB

#include <core.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/hmac.h>
#include <openssl/rand.h>

#define SMALL_CHUNK 256

int luuid(lua_State *L);
int lguid(lua_State *L);

int ltohex(lua_State *L);
int lfromhex(lua_State *L);

int lcrc32(lua_State *L);
int lcrc64(lua_State *L);

int lb64encode(lua_State *L);
int lb64decode(lua_State *L);

int lurlencode(lua_State *L);
int lurldecode(lua_State *L);

int ldesencode(lua_State *L);
int ldesdecode(lua_State *L);

int ldes_encrypt(lua_State *L);
int ldes_decrypt(lua_State *L);

int ldhsecret(lua_State *L);
int ldhexchange(lua_State *L);

int lhashkey(lua_State *L);
int lhmac_hash(lua_State *L);

int lhmac64(lua_State *L);
int lhmac64_md5(lua_State *L);

int lmd5(lua_State *L);
int lsha128(lua_State *L);
int lsha224(lua_State *L);
int lsha256(lua_State *L);
int lsha384(lua_State *L);
int lsha512(lua_State *L);

int lhmac_md5(lua_State *L);
int lhmac_sha128(lua_State *L);
int lhmac_sha224(lua_State *L);
int lhmac_sha256(lua_State *L);
int lhmac_sha384(lua_State *L);
int lhmac_sha512(lua_State *L);

int laes_ecb_encrypt(lua_State *L);
int laes_cbc_encrypt(lua_State *L);
int laes_cfb_encrypt(lua_State *L);
int laes_ofb_encrypt(lua_State *L);
int laes_ctr_encrypt(lua_State *L);
int laes_gcm_encrypt(lua_State *L);

int laes_ecb_decrypt(lua_State *L);
int laes_cbc_decrypt(lua_State *L);
int laes_cfb_decrypt(lua_State *L);
int laes_ofb_decrypt(lua_State *L);
int laes_ctr_decrypt(lua_State *L);
int laes_gcm_decrypt(lua_State *L);

int lrsa_public_key_encode(lua_State *L);
int lrsa_private_key_decode(lua_State *L);

int lrsa_private_key_encode(lua_State *L);
int lrsa_public_key_decode(lua_State *L);


int lrsa_sign(lua_State *L);
int lrsa_verify(lua_State *L);

int lsm3(lua_State *L);
int lhmac_sm3(lua_State *L);

int lsm2keygen(lua_State *L);

int lsm2sign(lua_State *L);
int lsm2verify(lua_State *L);

int lsm4_cbc_encrypt(lua_State *L);
int lsm4_cbc_decrypt(lua_State *L);

int lsm4_ecb_encrypt(lua_State *L);
int lsm4_ecb_decrypt(lua_State *L);

int lsm4_ofb_encrypt(lua_State *L);
int lsm4_ofb_decrypt(lua_State *L);

int lsm4_ctr_encrypt(lua_State *L);
int lsm4_ctr_decrypt(lua_State *L);