/*
-- This file is modified version from https://github.com/cloudwu/skynet
-- The license is under the BSD license.
-- Modified by Candy (merge sha1 and crypt into an file)
*/

#define LUA_LIB

#include "../../src/core.h"

#define SMALL_CHUNK 256

typedef struct {
    uint32_t state[5];
    uint32_t count[2];
    uint8_t  buffer[64];
} SHA1_CTX;

#define SHA1_DIGEST_SIZE 20



static void SHA1_Transform(uint32_t state[5], const uint8_t buffer[64]);

#define rol(value, bits) (((value) << (bits)) | ((value) >> (32 - (bits))))

/* blk0() and blk() perform the initial expand. */
/* I got the idea of expanding during the round function from SSLeay */
/* FIXME: can we do this in an endian-proof way? */
#ifdef WORDS_BIGENDIAN
#define blk0(i) block.l[i]
#else
#define blk0(i) (block.l[i] = (rol(block.l[i],24)&0xFF00FF00) \
    |(rol(block.l[i],8)&0x00FF00FF))
#endif
#define blk(i) (block.l[i&15] = rol(block.l[(i+13)&15]^block.l[(i+8)&15] \
    ^block.l[(i+2)&15]^block.l[i&15],1))

/* (R0+R1), R2, R3, R4 are the different operations used in SHA1 */
#define R0(v,w,x,y,z,i) z+=((w&(x^y))^y)+blk0(i)+0x5A827999+rol(v,5);w=rol(w,30);
#define R1(v,w,x,y,z,i) z+=((w&(x^y))^y)+blk(i)+0x5A827999+rol(v,5);w=rol(w,30);
#define R2(v,w,x,y,z,i) z+=(w^x^y)+blk(i)+0x6ED9EBA1+rol(v,5);w=rol(w,30);
#define R3(v,w,x,y,z,i) z+=(((w|x)&y)|(w&x))+blk(i)+0x8F1BBCDC+rol(v,5);w=rol(w,30);
#define R4(v,w,x,y,z,i) z+=(w^x^y)+blk(i)+0xCA62C1D6+rol(v,5);w=rol(w,30);

/* CRC32 TAB */
static uint32_t CRC32[] = {
 0x00000000L, 0x77073096L, 0xee0e612cL, 0x990951baL,
 0x076dc419L, 0x706af48fL, 0xe963a535L, 0x9e6495a3L,
 0x0edb8832L, 0x79dcb8a4L, 0xe0d5e91eL, 0x97d2d988L,
 0x09b64c2bL, 0x7eb17cbdL, 0xe7b82d07L, 0x90bf1d91L,
 0x1db71064L, 0x6ab020f2L, 0xf3b97148L, 0x84be41deL,
 0x1adad47dL, 0x6ddde4ebL, 0xf4d4b551L, 0x83d385c7L,
 0x136c9856L, 0x646ba8c0L, 0xfd62f97aL, 0x8a65c9ecL,
 0x14015c4fL, 0x63066cd9L, 0xfa0f3d63L, 0x8d080df5L,
 0x3b6e20c8L, 0x4c69105eL, 0xd56041e4L, 0xa2677172L,
 0x3c03e4d1L, 0x4b04d447L, 0xd20d85fdL, 0xa50ab56bL,
 0x35b5a8faL, 0x42b2986cL, 0xdbbbc9d6L, 0xacbcf940L,
 0x32d86ce3L, 0x45df5c75L, 0xdcd60dcfL, 0xabd13d59L,
 0x26d930acL, 0x51de003aL, 0xc8d75180L, 0xbfd06116L,
 0x21b4f4b5L, 0x56b3c423L, 0xcfba9599L, 0xb8bda50fL,
 0x2802b89eL, 0x5f058808L, 0xc60cd9b2L, 0xb10be924L,
 0x2f6f7c87L, 0x58684c11L, 0xc1611dabL, 0xb6662d3dL,
 0x76dc4190L, 0x01db7106L, 0x98d220bcL, 0xefd5102aL,
 0x71b18589L, 0x06b6b51fL, 0x9fbfe4a5L, 0xe8b8d433L,
 0x7807c9a2L, 0x0f00f934L, 0x9609a88eL, 0xe10e9818L,
 0x7f6a0dbbL, 0x086d3d2dL, 0x91646c97L, 0xe6635c01L,
 0x6b6b51f4L, 0x1c6c6162L, 0x856530d8L, 0xf262004eL,
 0x6c0695edL, 0x1b01a57bL, 0x8208f4c1L, 0xf50fc457L,
 0x65b0d9c6L, 0x12b7e950L, 0x8bbeb8eaL, 0xfcb9887cL,
 0x62dd1ddfL, 0x15da2d49L, 0x8cd37cf3L, 0xfbd44c65L,
 0x4db26158L, 0x3ab551ceL, 0xa3bc0074L, 0xd4bb30e2L,
 0x4adfa541L, 0x3dd895d7L, 0xa4d1c46dL, 0xd3d6f4fbL,
 0x4369e96aL, 0x346ed9fcL, 0xad678846L, 0xda60b8d0L,
 0x44042d73L, 0x33031de5L, 0xaa0a4c5fL, 0xdd0d7cc9L,
 0x5005713cL, 0x270241aaL, 0xbe0b1010L, 0xc90c2086L,
 0x5768b525L, 0x206f85b3L, 0xb966d409L, 0xce61e49fL,
 0x5edef90eL, 0x29d9c998L, 0xb0d09822L, 0xc7d7a8b4L,
 0x59b33d17L, 0x2eb40d81L, 0xb7bd5c3bL, 0xc0ba6cadL,
 0xedb88320L, 0x9abfb3b6L, 0x03b6e20cL, 0x74b1d29aL,
 0xead54739L, 0x9dd277afL, 0x04db2615L, 0x73dc1683L,
 0xe3630b12L, 0x94643b84L, 0x0d6d6a3eL, 0x7a6a5aa8L,
 0xe40ecf0bL, 0x9309ff9dL, 0x0a00ae27L, 0x7d079eb1L,
 0xf00f9344L, 0x8708a3d2L, 0x1e01f268L, 0x6906c2feL,
 0xf762575dL, 0x806567cbL, 0x196c3671L, 0x6e6b06e7L,
 0xfed41b76L, 0x89d32be0L, 0x10da7a5aL, 0x67dd4accL,
 0xf9b9df6fL, 0x8ebeeff9L, 0x17b7be43L, 0x60b08ed5L,
 0xd6d6a3e8L, 0xa1d1937eL, 0x38d8c2c4L, 0x4fdff252L,
 0xd1bb67f1L, 0xa6bc5767L, 0x3fb506ddL, 0x48b2364bL,
 0xd80d2bdaL, 0xaf0a1b4cL, 0x36034af6L, 0x41047a60L,
 0xdf60efc3L, 0xa867df55L, 0x316e8eefL, 0x4669be79L,
 0xcb61b38cL, 0xbc66831aL, 0x256fd2a0L, 0x5268e236L,
 0xcc0c7795L, 0xbb0b4703L, 0x220216b9L, 0x5505262fL,
 0xc5ba3bbeL, 0xb2bd0b28L, 0x2bb45a92L, 0x5cb36a04L,
 0xc2d7ffa7L, 0xb5d0cf31L, 0x2cd99e8bL, 0x5bdeae1dL,
 0x9b64c2b0L, 0xec63f226L, 0x756aa39cL, 0x026d930aL,
 0x9c0906a9L, 0xeb0e363fL, 0x72076785L, 0x05005713L,
 0x95bf4a82L, 0xe2b87a14L, 0x7bb12baeL, 0x0cb61b38L,
 0x92d28e9bL, 0xe5d5be0dL, 0x7cdcefb7L, 0x0bdbdf21L,
 0x86d3d2d4L, 0xf1d4e242L, 0x68ddb3f8L, 0x1fda836eL,
 0x81be16cdL, 0xf6b9265bL, 0x6fb077e1L, 0x18b74777L,
 0x88085ae6L, 0xff0f6a70L, 0x66063bcaL, 0x11010b5cL,
 0x8f659effL, 0xf862ae69L, 0x616bffd3L, 0x166ccf45L,
 0xa00ae278L, 0xd70dd2eeL, 0x4e048354L, 0x3903b3c2L,
 0xa7672661L, 0xd06016f7L, 0x4969474dL, 0x3e6e77dbL,
 0xaed16a4aL, 0xd9d65adcL, 0x40df0b66L, 0x37d83bf0L,
 0xa9bcae53L, 0xdebb9ec5L, 0x47b2cf7fL, 0x30b5ffe9L,
 0xbdbdf21cL, 0xcabac28aL, 0x53b39330L, 0x24b4a3a6L,
 0xbad03605L, 0xcdd70693L, 0x54de5729L, 0x23d967bfL,
 0xb3667a2eL, 0xc4614ab8L, 0x5d681b02L, 0x2a6f2b94L,
 0xb40bbe37L, 0xc30c8ea1L, 0x5a05df1bL, 0x2d02ef8dL
};

/* CRC64 TAB */
static uint64_t CRC64[] = {
    0x0000000000000000, 0x7ad870c830358979,
    0xf5b0e190606b12f2, 0x8f689158505e9b8b,
    0xc038e5739841b68f, 0xbae095bba8743ff6,
    0x358804e3f82aa47d, 0x4f50742bc81f2d04,
    0xab28ecb46814fe75, 0xd1f09c7c5821770c,
    0x5e980d24087fec87, 0x24407dec384a65fe,
    0x6b1009c7f05548fa, 0x11c8790fc060c183,
    0x9ea0e857903e5a08, 0xe478989fa00bd371,
    0x7d08ff3b88be6f81, 0x07d08ff3b88be6f8,
    0x88b81eabe8d57d73, 0xf2606e63d8e0f40a,
    0xbd301a4810ffd90e, 0xc7e86a8020ca5077,
    0x4880fbd87094cbfc, 0x32588b1040a14285,
    0xd620138fe0aa91f4, 0xacf86347d09f188d,
    0x2390f21f80c18306, 0x594882d7b0f40a7f,
    0x1618f6fc78eb277b, 0x6cc0863448deae02,
    0xe3a8176c18803589, 0x997067a428b5bcf0,
    0xfa11fe77117cdf02, 0x80c98ebf2149567b,
    0x0fa11fe77117cdf0, 0x75796f2f41224489,
    0x3a291b04893d698d, 0x40f16bccb908e0f4,
    0xcf99fa94e9567b7f, 0xb5418a5cd963f206,
    0x513912c379682177, 0x2be1620b495da80e,
    0xa489f35319033385, 0xde51839b2936bafc,
    0x9101f7b0e12997f8, 0xebd98778d11c1e81,
    0x64b116208142850a, 0x1e6966e8b1770c73,
    0x8719014c99c2b083, 0xfdc17184a9f739fa,
    0x72a9e0dcf9a9a271, 0x08719014c99c2b08,
    0x4721e43f0183060c, 0x3df994f731b68f75,
    0xb29105af61e814fe, 0xc849756751dd9d87,
    0x2c31edf8f1d64ef6, 0x56e99d30c1e3c78f,
    0xd9810c6891bd5c04, 0xa3597ca0a188d57d,
    0xec09088b6997f879, 0x96d1784359a27100,
    0x19b9e91b09fcea8b, 0x636199d339c963f2,
    0xdf7adabd7a6e2d6f, 0xa5a2aa754a5ba416,
    0x2aca3b2d1a053f9d, 0x50124be52a30b6e4,
    0x1f423fcee22f9be0, 0x659a4f06d21a1299,
    0xeaf2de5e82448912, 0x902aae96b271006b,
    0x74523609127ad31a, 0x0e8a46c1224f5a63,
    0x81e2d7997211c1e8, 0xfb3aa75142244891,
    0xb46ad37a8a3b6595, 0xceb2a3b2ba0eecec,
    0x41da32eaea507767, 0x3b024222da65fe1e,
    0xa2722586f2d042ee, 0xd8aa554ec2e5cb97,
    0x57c2c41692bb501c, 0x2d1ab4dea28ed965,
    0x624ac0f56a91f461, 0x1892b03d5aa47d18,
    0x97fa21650afae693, 0xed2251ad3acf6fea,
    0x095ac9329ac4bc9b, 0x7382b9faaaf135e2,
    0xfcea28a2faafae69, 0x8632586aca9a2710,
    0xc9622c4102850a14, 0xb3ba5c8932b0836d,
    0x3cd2cdd162ee18e6, 0x460abd1952db919f,
    0x256b24ca6b12f26d, 0x5fb354025b277b14,
    0xd0dbc55a0b79e09f, 0xaa03b5923b4c69e6,
    0xe553c1b9f35344e2, 0x9f8bb171c366cd9b,
    0x10e3202993385610, 0x6a3b50e1a30ddf69,
    0x8e43c87e03060c18, 0xf49bb8b633338561,
    0x7bf329ee636d1eea, 0x012b592653589793,
    0x4e7b2d0d9b47ba97, 0x34a35dc5ab7233ee,
    0xbbcbcc9dfb2ca865, 0xc113bc55cb19211c,
    0x5863dbf1e3ac9dec, 0x22bbab39d3991495,
    0xadd33a6183c78f1e, 0xd70b4aa9b3f20667,
    0x985b3e827bed2b63, 0xe2834e4a4bd8a21a,
    0x6debdf121b863991, 0x1733afda2bb3b0e8,
    0xf34b37458bb86399, 0x8993478dbb8deae0,
    0x06fbd6d5ebd3716b, 0x7c23a61ddbe6f812,
    0x3373d23613f9d516, 0x49aba2fe23cc5c6f,
    0xc6c333a67392c7e4, 0xbc1b436e43a74e9d,
    0x95ac9329ac4bc9b5, 0xef74e3e19c7e40cc,
    0x601c72b9cc20db47, 0x1ac40271fc15523e,
    0x5594765a340a7f3a, 0x2f4c0692043ff643,
    0xa02497ca54616dc8, 0xdafce7026454e4b1,
    0x3e847f9dc45f37c0, 0x445c0f55f46abeb9,
    0xcb349e0da4342532, 0xb1eceec59401ac4b,
    0xfebc9aee5c1e814f, 0x8464ea266c2b0836,
    0x0b0c7b7e3c7593bd, 0x71d40bb60c401ac4,
    0xe8a46c1224f5a634, 0x927c1cda14c02f4d,
    0x1d148d82449eb4c6, 0x67ccfd4a74ab3dbf,
    0x289c8961bcb410bb, 0x5244f9a98c8199c2,
    0xdd2c68f1dcdf0249, 0xa7f41839ecea8b30,
    0x438c80a64ce15841, 0x3954f06e7cd4d138,
    0xb63c61362c8a4ab3, 0xcce411fe1cbfc3ca,
    0x83b465d5d4a0eece, 0xf96c151de49567b7,
    0x76048445b4cbfc3c, 0x0cdcf48d84fe7545,
    0x6fbd6d5ebd3716b7, 0x15651d968d029fce,
    0x9a0d8ccedd5c0445, 0xe0d5fc06ed698d3c,
    0xaf85882d2576a038, 0xd55df8e515432941,
    0x5a3569bd451db2ca, 0x20ed197575283bb3,
    0xc49581ead523e8c2, 0xbe4df122e51661bb,
    0x3125607ab548fa30, 0x4bfd10b2857d7349,
    0x04ad64994d625e4d, 0x7e7514517d57d734,
    0xf11d85092d094cbf, 0x8bc5f5c11d3cc5c6,
    0x12b5926535897936, 0x686de2ad05bcf04f,
    0xe70573f555e26bc4, 0x9ddd033d65d7e2bd,
    0xd28d7716adc8cfb9, 0xa85507de9dfd46c0,
    0x273d9686cda3dd4b, 0x5de5e64efd965432,
    0xb99d7ed15d9d8743, 0xc3450e196da80e3a,
    0x4c2d9f413df695b1, 0x36f5ef890dc31cc8,
    0x79a59ba2c5dc31cc, 0x037deb6af5e9b8b5,
    0x8c157a32a5b7233e, 0xf6cd0afa9582aa47,
    0x4ad64994d625e4da, 0x300e395ce6106da3,
    0xbf66a804b64ef628, 0xc5bed8cc867b7f51,
    0x8aeeace74e645255, 0xf036dc2f7e51db2c,
    0x7f5e4d772e0f40a7, 0x05863dbf1e3ac9de,
    0xe1fea520be311aaf, 0x9b26d5e88e0493d6,
    0x144e44b0de5a085d, 0x6e963478ee6f8124,
    0x21c640532670ac20, 0x5b1e309b16452559,
    0xd476a1c3461bbed2, 0xaeaed10b762e37ab,
    0x37deb6af5e9b8b5b, 0x4d06c6676eae0222,
    0xc26e573f3ef099a9, 0xb8b627f70ec510d0,
    0xf7e653dcc6da3dd4, 0x8d3e2314f6efb4ad,
    0x0256b24ca6b12f26, 0x788ec2849684a65f,
    0x9cf65a1b368f752e, 0xe62e2ad306bafc57,
    0x6946bb8b56e467dc, 0x139ecb4366d1eea5,
    0x5ccebf68aecec3a1, 0x2616cfa09efb4ad8,
    0xa97e5ef8cea5d153, 0xd3a62e30fe90582a,
    0xb0c7b7e3c7593bd8, 0xca1fc72bf76cb2a1,
    0x45775673a732292a, 0x3faf26bb9707a053,
    0x70ff52905f188d57, 0x0a2722586f2d042e,
    0x854fb3003f739fa5, 0xff97c3c80f4616dc,
    0x1bef5b57af4dc5ad, 0x61372b9f9f784cd4,
    0xee5fbac7cf26d75f, 0x9487ca0fff135e26,
    0xdbd7be24370c7322, 0xa10fceec0739fa5b,
    0x2e675fb4576761d0, 0x54bf2f7c6752e8a9,
    0xcdcf48d84fe75459, 0xb71738107fd2dd20,
    0x387fa9482f8c46ab, 0x42a7d9801fb9cfd2,
    0x0df7adabd7a6e2d6, 0x772fdd63e7936baf,
    0xf8474c3bb7cdf024, 0x829f3cf387f8795d,
    0x66e7a46c27f3aa2c, 0x1c3fd4a417c62355,
    0x935745fc4798b8de, 0xe98f353477ad31a7,
    0xa6df411fbfb21ca3, 0xdc0731d78f8795da,
    0x536fa08fdfd90e51, 0x29b7d047efec8728,
};


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

#define GET_UINT32(n,b,i)                      \
{                                              \
    (n) = ( (uint32_t) (b)[(i)  ] << 24 )      \
        | ( (uint32_t) (b)[(i) + 1] << 16 )    \
        | ( (uint32_t) (b)[(i) + 2] <<  8 )    \
        | ( (uint32_t) (b)[(i) + 3]    );     \
}

#define PUT_UINT32(n,b,i)                      \
{                                              \
    (b)[(i) ] = (uint8_t) ( (n) >> 24 );       \
    (b)[(i) + 1] = (uint8_t) ( (n) >> 16 );    \
    (b)[(i) + 2] = (uint8_t) ( (n) >>  8 );    \
    (b)[(i) + 3] = (uint8_t) ( (n)     );      \
}

/* Initial Permutation macro */

#define DES_IP(X,Y)                                          \
{                                                              \
    T = ((X >>  4) ^ Y) & 0x0F0F0F0F; Y ^= T; X ^= (T <<  4);   \
    T = ((X >> 16) ^ Y) & 0x0000FFFF; Y ^= T; X ^= (T << 16);   \
    T = ((Y >>  2) ^ X) & 0x33333333; X ^= T; Y ^= (T <<  2);   \
    T = ((Y >>  8) ^ X) & 0x00FF00FF; X ^= T; Y ^= (T <<  8);   \
    Y = ((Y << 1) | (Y >> 31)) & 0xFFFFFFFF;                    \
    T = (X ^ Y) & 0xAAAAAAAA; Y ^= T; X ^= T;                  \
    X = ((X << 1) | (X >> 31)) & 0xFFFFFFFF;                    \
}

/* Final Permutation macro */

#define DES_FP(X,Y)                                          \
{                                                              \
    X = ((X << 31) | (X >> 1)) & 0xFFFFFFFF;                    \
    T = (X ^ Y) & 0xAAAAAAAA; X ^= T; Y ^= T;                  \
    Y = ((Y << 31) | (Y >> 1)) & 0xFFFFFFFF;                    \
    T = ((Y >>  8) ^ X) & 0x00FF00FF; X ^= T; Y ^= (T <<  8);   \
    T = ((Y >>  2) ^ X) & 0x33333333; X ^= T; Y ^= (T <<  2);   \
    T = ((X >> 16) ^ Y) & 0x0000FFFF; Y ^= T; X ^= (T << 16);   \
    T = ((X >>  4) ^ Y) & 0x0F0F0F0F; Y ^= T; X ^= (T <<  4);   \
}

/* DES round macro */

#define DES_ROUND(X,Y)                        \
{                                              \
    T = *SK++ ^ X;                            \
    Y ^= SB8[ (T      ) & 0x3F ] ^            \
         SB6[ (T >>  8) & 0x3F ] ^            \
         SB4[ (T >> 16) & 0x3F ] ^            \
         SB2[ (T >> 24) & 0x3F ];              \
                                                \
    T = *SK++ ^ ((X << 28) | (X >> 4));      \
    Y ^= SB7[ (T      ) & 0x3F ] ^            \
         SB5[ (T >>  8) & 0x3F ] ^            \
         SB3[ (T >> 16) & 0x3F ] ^            \
         SB1[ (T >> 24) & 0x3F ];              \
}

/* DES key schedule */




/* Hash a single 512-bit block. This is the core of the algorithm. */
static void SHA1_Transform(uint32_t state[5], const uint8_t buffer[64])
{
    uint32_t a, b, c, d, e;
    typedef union {
        uint8_t c[64];
        uint32_t l[16];
    } CHAR64LONG16;
    CHAR64LONG16 block;

    memcpy(&block, buffer, 64);

    /* Copy context->state[] to working vars */
    a = state[0];
    b = state[1];
    c = state[2];
    d = state[3];
    e = state[4];

    /* 4 rounds of 20 operations each. Loop unrolled. */
    R0(a,b,c,d,e, 0); R0(e,a,b,c,d, 1); R0(d,e,a,b,c, 2); R0(c,d,e,a,b, 3);
    R0(b,c,d,e,a, 4); R0(a,b,c,d,e, 5); R0(e,a,b,c,d, 6); R0(d,e,a,b,c, 7);
    R0(c,d,e,a,b, 8); R0(b,c,d,e,a, 9); R0(a,b,c,d,e,10); R0(e,a,b,c,d,11);
    R0(d,e,a,b,c,12); R0(c,d,e,a,b,13); R0(b,c,d,e,a,14); R0(a,b,c,d,e,15);
    R1(e,a,b,c,d,16); R1(d,e,a,b,c,17); R1(c,d,e,a,b,18); R1(b,c,d,e,a,19);
    R2(a,b,c,d,e,20); R2(e,a,b,c,d,21); R2(d,e,a,b,c,22); R2(c,d,e,a,b,23);
    R2(b,c,d,e,a,24); R2(a,b,c,d,e,25); R2(e,a,b,c,d,26); R2(d,e,a,b,c,27);
    R2(c,d,e,a,b,28); R2(b,c,d,e,a,29); R2(a,b,c,d,e,30); R2(e,a,b,c,d,31);
    R2(d,e,a,b,c,32); R2(c,d,e,a,b,33); R2(b,c,d,e,a,34); R2(a,b,c,d,e,35);
    R2(e,a,b,c,d,36); R2(d,e,a,b,c,37); R2(c,d,e,a,b,38); R2(b,c,d,e,a,39);
    R3(a,b,c,d,e,40); R3(e,a,b,c,d,41); R3(d,e,a,b,c,42); R3(c,d,e,a,b,43);
    R3(b,c,d,e,a,44); R3(a,b,c,d,e,45); R3(e,a,b,c,d,46); R3(d,e,a,b,c,47);
    R3(c,d,e,a,b,48); R3(b,c,d,e,a,49); R3(a,b,c,d,e,50); R3(e,a,b,c,d,51);
    R3(d,e,a,b,c,52); R3(c,d,e,a,b,53); R3(b,c,d,e,a,54); R3(a,b,c,d,e,55);
    R3(e,a,b,c,d,56); R3(d,e,a,b,c,57); R3(c,d,e,a,b,58); R3(b,c,d,e,a,59);
    R4(a,b,c,d,e,60); R4(e,a,b,c,d,61); R4(d,e,a,b,c,62); R4(c,d,e,a,b,63);
    R4(b,c,d,e,a,64); R4(a,b,c,d,e,65); R4(e,a,b,c,d,66); R4(d,e,a,b,c,67);
    R4(c,d,e,a,b,68); R4(b,c,d,e,a,69); R4(a,b,c,d,e,70); R4(e,a,b,c,d,71);
    R4(d,e,a,b,c,72); R4(c,d,e,a,b,73); R4(b,c,d,e,a,74); R4(a,b,c,d,e,75);
    R4(e,a,b,c,d,76); R4(d,e,a,b,c,77); R4(c,d,e,a,b,78); R4(b,c,d,e,a,79);

    /* Add the working vars back into context.state[] */
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;

    /* Wipe variables */
    a = b = c = d = e = 0;
}


/* SHA1Init - Initialize new context */
static void sat_SHA1_Init(SHA1_CTX* context)
{
    /* SHA1 initialization constants */
    context->state[0] = 0x67452301;
    context->state[1] = 0xEFCDAB89;
    context->state[2] = 0x98BADCFE;
    context->state[3] = 0x10325476;
    context->state[4] = 0xC3D2E1F0;
    context->count[0] = context->count[1] = 0;
}


/* Run your data through this. */
static void sat_SHA1_Update(SHA1_CTX* context,  const uint8_t* data, const size_t len)
{
    size_t i, j;

#ifdef VERBOSE
    SHAPrintContext(context, "before");
#endif

    j = (context->count[0] >> 3) & 63;
    if ((context->count[0] += len << 3) < (len << 3)) context->count[1]++;
    context->count[1] += (len >> 29);
    if ((j + len) > 63) {
        memcpy(&context->buffer[j], data, (i = 64-j));
        SHA1_Transform(context->state, context->buffer);
        for ( ; i + 63 < len; i += 64) {
            SHA1_Transform(context->state, data + i);
        }
        j = 0;
    }
    else i = 0;
    memcpy(&context->buffer[j], &data[i], len - i);

#ifdef VERBOSE
    SHAPrintContext(context, "after ");
#endif
}


/* Add padding and return the message digest. */
static void sat_SHA1_Final(SHA1_CTX* context, uint8_t digest[SHA1_DIGEST_SIZE])
{
    uint32_t i;
    uint8_t  finalcount[8];

    for (i = 0; i < 8; i++) {
        finalcount[i] = (unsigned char)((context->count[(i >= 4 ? 0 : 1)]
         >> ((3-(i & 3)) * 8) ) & 255);  /* Endian independent */
    }
    sat_SHA1_Update(context, (uint8_t *)"\200", 1);
    while ((context->count[0] & 504) != 448) {
        sat_SHA1_Update(context, (uint8_t *)"\0", 1);
    }
    sat_SHA1_Update(context, finalcount, 8);  /* Should cause a SHA1_Transform() */
    for (i = 0; i < SHA1_DIGEST_SIZE; i++) {
        digest[i] = (uint8_t)
         ((context->state[i>>2] >> ((3-(i & 3)) * 8) ) & 255);
    }

    /* Wipe variables */
    i = 0;
    memset(context->buffer, 0, 64);
    memset(context->state, 0, 20);
    memset(context->count, 0, 8);
    memset(finalcount, 0, 8);   /* SWR */
}

int
lsha1(lua_State *L) {
    size_t sz = 0;
    const uint8_t * buffer = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    uint8_t digest[SHA1_DIGEST_SIZE];
    SHA1_CTX ctx;
    sat_SHA1_Init(&ctx);
    sat_SHA1_Update(&ctx, buffer, sz);
    sat_SHA1_Final(&ctx, digest);
    lua_pushlstring(L, (const char *)digest, SHA1_DIGEST_SIZE);

    return 1;
}

#define BLOCKSIZE 64

static inline void
xor_key(uint8_t key[BLOCKSIZE], uint32_t xor) {
    int i;
    for (i=0;i<BLOCKSIZE;i+=sizeof(uint32_t)) {
        uint32_t * k = (uint32_t *)&key[i];
        *k ^= xor;
    }
}

LUAMOD_API int
lhmac_sha1(lua_State *L) {
    size_t key_sz = 0;
    const uint8_t * key = (const uint8_t *)luaL_checklstring(L, 1, &key_sz);
    size_t text_sz = 0;
    const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 2, &text_sz);
    SHA1_CTX ctx1, ctx2;
    uint8_t digest1[SHA1_DIGEST_SIZE];
    uint8_t digest2[SHA1_DIGEST_SIZE];
    uint8_t rkey[BLOCKSIZE];
    memset(rkey, 0, BLOCKSIZE);

    if (key_sz > BLOCKSIZE) {
        SHA1_CTX ctx;
        sat_SHA1_Init(&ctx);
        sat_SHA1_Update(&ctx, key, key_sz);
        sat_SHA1_Final(&ctx, rkey);
        key_sz = SHA1_DIGEST_SIZE;
    } else {
        memcpy(rkey, key, key_sz);
    }

    xor_key(rkey, 0x5c5c5c5c);
    sat_SHA1_Init(&ctx1);
    sat_SHA1_Update(&ctx1, rkey, BLOCKSIZE);

    xor_key(rkey, 0x5c5c5c5c ^ 0x36363636);
    sat_SHA1_Init(&ctx2);
    sat_SHA1_Update(&ctx2, rkey, BLOCKSIZE);
    sat_SHA1_Update(&ctx2, text, text_sz);
    sat_SHA1_Final(&ctx2, digest2);

    sat_SHA1_Update(&ctx1, digest2, SHA1_DIGEST_SIZE);
    sat_SHA1_Final(&ctx1, digest1);

    lua_pushlstring(L, (const char *)digest1, SHA1_DIGEST_SIZE);

    return 1;
}

static void
des_main_ks( uint32_t SK[32], const uint8_t key[8] ) {
    int i;
    uint32_t X, Y, T;

    GET_UINT32( X, key, 0 );
    GET_UINT32( Y, key, 4 );

    /* Permuted Choice 1 */

    T =  ((Y >>  4) ^ X) & 0x0F0F0F0F;  X ^= T; Y ^= (T <<  4);
    T =  ((Y      ) ^ X) & 0x10101010;  X ^= T; Y ^= (T   );

    X =   (LHs[ (X    ) & 0xF] << 3) | (LHs[ (X >>  8) & 0xF ] << 2)
        | (LHs[ (X >> 16) & 0xF] << 1) | (LHs[ (X >> 24) & 0xF ]     )
        | (LHs[ (X >>  5) & 0xF] << 7) | (LHs[ (X >> 13) & 0xF ] << 6)
        | (LHs[ (X >> 21) & 0xF] << 5) | (LHs[ (X >> 29) & 0xF ] << 4);

    Y =   (RHs[ (Y >>  1) & 0xF] << 3) | (RHs[ (Y >>  9) & 0xF ] << 2)
        | (RHs[ (Y >> 17) & 0xF] << 1) | (RHs[ (Y >> 25) & 0xF ]     )
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
                | ((Y >> 14) & 0x00000200) | ((Y      ) & 0x00000100)
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
                | ((Y     ) & 0x00000200) | ((Y <<  7) & 0x00000100)
                | ((Y >>  7) & 0x00000020) | ((Y >>  3) & 0x00000011)
                | ((Y <<  2) & 0x00000004) | ((Y >> 21) & 0x00000002);
    }
}

/* DES 64-bit block encryption/decryption */

static void
des_crypt( const uint32_t SK[32], const uint8_t input[8], uint8_t output[8] ) {
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

static int
lrandomkey(lua_State *L) {
    char tmp[8];
    int i;
    char x = 0;
    for (i=0;i<8;i++) {
        tmp[i] = random() & 0xff;
        x ^= tmp[i];
    }
    if (x==0) {
        tmp[0] |= 1;    // avoid 0
    }
    lua_pushlstring(L, tmp, 8);
    return 1;
}

static void
des_key(lua_State *L, uint32_t SK[32]) {
    size_t keysz = 0;
    const void * key = luaL_checklstring(L, 1, &keysz);
    if (keysz != 8) {
        luaL_error(L, "Invalid key size %d, need 8 bytes", (int)keysz);
    }
    des_main_ks(SK, key);
}

static int
ldesencode(lua_State *L) {
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

static int
ldesdecode(lua_State *L) {
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


static void
Hash(const char * str, int sz, uint8_t key[8]) {
    uint32_t djb_hash = 5381L;
    uint32_t js_hash = 1315423911L;

    int i;
    for (i=0;i<sz;i++) {
        uint8_t c = (uint8_t)str[i];
        djb_hash += (djb_hash << 5) + c;
        js_hash ^= ((js_hash << 5) + c + (js_hash >> 2));
    }

    key[0] = djb_hash & 0xff;
    key[1] = (djb_hash >> 8) & 0xff;
    key[2] = (djb_hash >> 16) & 0xff;
    key[3] = (djb_hash >> 24) & 0xff;

    key[4] = js_hash & 0xff;
    key[5] = (js_hash >> 8) & 0xff;
    key[6] = (js_hash >> 16) & 0xff;
    key[7] = (js_hash >> 24) & 0xff;
}

static int
lhashkey(lua_State *L) {
    size_t sz = 0;
    const char * key = luaL_checklstring(L, 1, &sz);
    uint8_t realkey[8];
    Hash(key,(int)sz,realkey);
    lua_pushlstring(L, (const char *)realkey, 8);
    return 1;
}

static int
ltohex(lua_State *L) {
    static char hex[] = "0123456789abcdef";
    size_t sz = 0;
    const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    char tmp[SMALL_CHUNK];
    char *buffer = tmp;
    if (sz > SMALL_CHUNK/2) {
        buffer = lua_newuserdata(L, sz * 2);
    }
    int i;
    for (i=0;i<sz;i++) {
        buffer[i*2] = hex[text[i] >> 4];
        buffer[i*2+1] = hex[text[i] & 0xf];
    }
    lua_pushlstring(L, buffer, sz * 2);
    return 1;
}

#define HEX(v,c) { char tmp = (char) c; if (tmp >= '0' && tmp <= '9') { v = tmp-'0'; } else { v = tmp - 'a' + 10; } }

static int
lfromhex(lua_State *L) {
    size_t sz = 0;
    const char * text = luaL_checklstring(L, 1, &sz);
    if (sz & 1) {
        return luaL_error(L, "Invalid hex text size %d", (int)sz);
    }
    char tmp[SMALL_CHUNK];
    char *buffer = tmp;
    if (sz > SMALL_CHUNK*2) {
        buffer = lua_newuserdata(L, sz / 2);
    }
    int i;
    for (i=0;i<sz;i+=2) {
        uint8_t hi,low;
        HEX(hi, text[i]);
        HEX(low, text[i+1]);
        if (hi > 16 || low > 16) {
            return luaL_error(L, "Invalid hex text", text);
        }
        buffer[i/2] = hi<<4 | low;
    }
    lua_pushlstring(L, buffer, i/2);
    return 1;
}

// Constants are the integer part of the sines of integers (in radians) * 2^32.
static const uint32_t k[64] = {
0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee ,
0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501 ,
0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be ,
0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821 ,
0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa ,
0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8 ,
0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed ,
0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a ,
0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c ,
0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70 ,
0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05 ,
0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665 ,
0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039 ,
0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1 ,
0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1 ,
0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391 };

// r specifies the per-round shift amounts
static const uint32_t r[] = {7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
                      5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
                      4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
                      6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21};

// leftrotate function definition
#define LEFTROTATE(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

static void
digest_md5(uint32_t w[16], uint32_t result[4]) {
    uint32_t a, b, c, d, f, g, temp;
    int i;

    a = 0x67452301u;
    b = 0xefcdab89u;
    c = 0x98badcfeu;
    d = 0x10325476u;

    for(i = 0; i<64; i++) {
        if (i < 16) {
            f = (b & c) | ((~b) & d);
            g = i;
        } else if (i < 32) {
            f = (d & b) | ((~d) & c);
            g = (5*i + 1) % 16;
        } else if (i < 48) {
            f = b ^ c ^ d;
            g = (3*i + 5) % 16;
        } else {
            f = c ^ (b | (~d));
            g = (7*i) % 16;
        }

        temp = d;
        d = c;
        c = b;
        b = b + LEFTROTATE((a + f + k[i] + w[g]), r[i]);
        a = temp;
    }

    result[0] = a;
    result[1] = b;
    result[2] = c;
    result[3] = d;
}

// hmac64 use md5 algorithm without padding, and the result is (c^d .. a^b)
static void
hmac(uint32_t x[2], uint32_t y[2], uint32_t result[2]) {
    uint32_t w[16];
    uint32_t r[4];
    int i;
    for (i=0;i<16;i+=4) {
        w[i] = x[1];
        w[i+1] = x[0];
        w[i+2] = y[1];
        w[i+3] = y[0];
    }

    digest_md5(w,r);

    result[0] = r[2]^r[3];
    result[1] = r[0]^r[1];
}

static void
hmac_md5(uint32_t x[2], uint32_t y[2], uint32_t result[2]) {
    uint32_t w[16];
    uint32_t r[4];
    int i;
    for (i=0;i<12;i+=4) {
        w[i] = x[0];
        w[i+1] = x[1];
        w[i+2] = y[0];
        w[i+3] = y[1];
    }

    w[12] = 0x80;
    w[13] = 0;
    w[14] = 384;
    w[15] = 0;

    digest_md5(w,r);

    result[0] = (r[0] + 0x67452301u) ^ (r[2] + 0x98badcfeu);
    result[1] = (r[1] + 0xefcdab89u) ^ (r[3] + 0x10325476u);
}

static void
read64(lua_State *L, uint32_t xx[2], uint32_t yy[2]) {
    size_t sz = 0;
    const uint8_t *x = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    if (sz != 8) {
        luaL_error(L, "Invalid uint64 x");
    }
    const uint8_t *y = (const uint8_t *)luaL_checklstring(L, 2, &sz);
    if (sz != 8) {
        luaL_error(L, "Invalid uint64 y");
    }
    xx[0] = x[0] | x[1]<<8 | x[2]<<16 | x[3]<<24;
    xx[1] = x[4] | x[5]<<8 | x[6]<<16 | x[7]<<24;
    yy[0] = y[0] | y[1]<<8 | y[2]<<16 | y[3]<<24;
    yy[1] = y[4] | y[5]<<8 | y[6]<<16 | y[7]<<24;
}

static int
pushqword(lua_State *L, uint32_t result[2]) {
    uint8_t tmp[8];
    tmp[0] = result[0] & 0xff;
    tmp[1] = (result[0] >> 8 )& 0xff;
    tmp[2] = (result[0] >> 16 )& 0xff;
    tmp[3] = (result[0] >> 24 )& 0xff;
    tmp[4] = result[1] & 0xff;
    tmp[5] = (result[1] >> 8 )& 0xff;
    tmp[6] = (result[1] >> 16 )& 0xff;
    tmp[7] = (result[1] >> 24 )& 0xff;

    lua_pushlstring(L, (const char *)tmp, 8);
    return 1;
}

static int
lhmac64(lua_State *L) {
    uint32_t x[2], y[2];
    read64(L, x, y);
    uint32_t result[2];
    hmac(x,y,result);
    return pushqword(L, result);
}

/*
  h1 = crypt.hmac64_md5(a,b)
  m = md5.sum((a..b):rep(3))
  h2 = crypt.xor_str(m:sub(1,8), m:sub(9,16))
  assert(h1 == h2)
 */
static int
lhmac64_md5(lua_State *L) {
    uint32_t x[2], y[2];
    read64(L, x, y);
    uint32_t result[2];
    hmac_md5(x,y,result);
    return pushqword(L, result);
}

/*
    8bytes key
    string text
 */
static int
lhmac_hash(lua_State *L) {
    uint32_t key[2];
    size_t sz = 0;
    const uint8_t *x = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    if (sz != 8) {
        luaL_error(L, "Invalid uint64 key");
    }
    key[0] = x[0] | x[1]<<8 | x[2]<<16 | x[3]<<24;
    key[1] = x[4] | x[5]<<8 | x[6]<<16 | x[7]<<24;
    const char * text = luaL_checklstring(L, 2, &sz);
    uint8_t h[8];
    Hash(text,(int)sz,h);
    uint32_t htext[2];
    htext[0] = h[0] | h[1]<<8 | h[2]<<16 | h[3]<<24;
    htext[1] = h[4] | h[5]<<8 | h[6]<<16 | h[7]<<24;
    uint32_t result[2];
    hmac(htext,key,result);
    return pushqword(L, result);
}

// powmodp64 for DH-key exchange

// The biggest 64bit prime
#define P 0xffffffffffffffc5ull

static inline uint64_t
mul_mod_p(uint64_t a, uint64_t b) {
    uint64_t m = 0;
    while(b) {
        if(b&1) {
            uint64_t t = P-a;
            if ( m >= t) {
                m -= t;
            } else {
                m += a;
            }
        }
        if (a >= P - a) {
            a = a * 2 - P;
        } else {
            a = a * 2;
        }
        b>>=1;
    }
    return m;
}

static inline uint64_t
pow_mod_p(uint64_t a, uint64_t b) {
    if (b==1) {
        return a;
    }
    uint64_t t = pow_mod_p(a, b>>1);
    t = mul_mod_p(t,t);
    if (b % 2) {
        t = mul_mod_p(t, a);
    }
    return t;
}

// calc a^b % p
static uint64_t
powmodp(uint64_t a, uint64_t b) {
    if (a > P)
        a%=P;
    return pow_mod_p(a,b);
}

static void
push64(lua_State *L, uint64_t r) {
    uint8_t tmp[8];
    tmp[0] = r & 0xff;
    tmp[1] = (r >> 8 )& 0xff;
    tmp[2] = (r >> 16 )& 0xff;
    tmp[3] = (r >> 24 )& 0xff;
    tmp[4] = (r >> 32 )& 0xff;
    tmp[5] = (r >> 40 )& 0xff;
    tmp[6] = (r >> 48 )& 0xff;
    tmp[7] = (r >> 56 )& 0xff;

    lua_pushlstring(L, (const char *)tmp, 8);
}

static int
ldhsecret(lua_State *L) {
    uint32_t x[2], y[2];
    read64(L, x, y);
    uint64_t xx = (uint64_t)x[0] | (uint64_t)x[1]<<32;
    uint64_t yy = (uint64_t)y[0] | (uint64_t)y[1]<<32;
    if (xx == 0 || yy == 0)
        return luaL_error(L, "Can't be 0");
    uint64_t r = powmodp(xx, yy);

    push64(L, r);

    return 1;
}

#define G 5

static int
ldhexchange(lua_State *L) {
    size_t sz = 0;
    const uint8_t *x = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    if (sz != 8) {
        luaL_error(L, "Invalid dh uint64 key");
    }
    uint32_t xx[2];
    xx[0] = x[0] | x[1]<<8 | x[2]<<16 | x[3]<<24;
    xx[1] = x[4] | x[5]<<8 | x[6]<<16 | x[7]<<24;

    uint64_t x64 = (uint64_t)xx[0] | (uint64_t)xx[1]<<32;
    if (x64 == 0)
        return luaL_error(L, "Can't be 0");

    uint64_t r = powmodp(G, x64);
    push64(L, r);
    return 1;
}

// base64

static int
lb64encode(lua_State *L) {
    static const char* encoding = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    size_t sz = 0;
    const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    int encode_sz = (sz + 2)/3*4;
    char tmp[SMALL_CHUNK];
    char *buffer = tmp;
    if (encode_sz > SMALL_CHUNK) {
        buffer = lua_newuserdata(L, encode_sz);
    }
    int i,j;
    j=0;
    for (i=0;i<(int)sz-2;i+=3) {
        uint32_t v = text[i] << 16 | text[i+1] << 8 | text[i+2];
        buffer[j] = encoding[v >> 18];
        buffer[j+1] = encoding[(v >> 12) & 0x3f];
        buffer[j+2] = encoding[(v >> 6) & 0x3f];
        buffer[j+3] = encoding[(v) & 0x3f];
        j+=4;
    }
    int padding = sz-i;
    uint32_t v;
    switch(padding) {
    case 1 :
        v = text[i];
        buffer[j] = encoding[v >> 2];
        buffer[j+1] = encoding[(v & 3) << 4];
        buffer[j+2] = '=';
        buffer[j+3] = '=';
        break;
    case 2 :
        v = text[i] << 8 | text[i+1];
        buffer[j] = encoding[v >> 10];
        buffer[j+1] = encoding[(v >> 4) & 0x3f];
        buffer[j+2] = encoding[(v & 0xf) << 2];
        buffer[j+3] = '=';
        break;
    }
    lua_pushlstring(L, buffer, encode_sz);
    return 1;
}

static inline int
b64index(uint8_t c) {
    static const int decoding[] = {62,-1,-1,-1,63,52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-2,-1,-1,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,-1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51};
    int decoding_size = sizeof(decoding)/sizeof(decoding[0]);
    if (c<43) {
        return -1;
    }
    c -= 43;
    if (c>=decoding_size)
        return -1;
    return decoding[c];
}

static int
lb64decode(lua_State *L) {
    size_t sz = 0;
    const uint8_t * text = (const uint8_t *)luaL_checklstring(L, 1, &sz);
    int decode_sz = (sz+3)/4*3;
    char tmp[SMALL_CHUNK];
    char *buffer = tmp;
    if (decode_sz > SMALL_CHUNK) {
        buffer = lua_newuserdata(L, decode_sz);
    }
    int i,j;
    int output = 0;
    for (i=0;i<sz;) {
        int padding = 0;
        int c[4];
        for (j=0;j<4;) {
            if (i>=sz) {
                return luaL_error(L, "Invalid base64 text");
            }
            c[j] = b64index(text[i]);
            if (c[j] == -1) {
                ++i;
                continue;
            }
            if (c[j] == -2) {
                ++padding;
            }
            ++i;
            ++j;
        }
        uint32_t v;
        switch (padding) {
        case 0:
            v = (unsigned)c[0] << 18 | c[1] << 12 | c[2] << 6 | c[3];
            buffer[output] = v >> 16;
            buffer[output+1] = (v >> 8) & 0xff;
            buffer[output+2] = v & 0xff;
            output += 3;
            break;
        case 1:
            if (c[3] != -2 || (c[2] & 3)!=0) {
                return luaL_error(L, "Invalid base64 text");
            }
            v = (unsigned)c[0] << 10 | c[1] << 4 | c[2] >> 2 ;
            buffer[output] = v >> 8;
            buffer[output+1] = v & 0xff;
            output += 2;
            break;
        case 2:
            if (c[3] != -2 || c[2] != -2 || (c[1] & 0xf) !=0)  {
                return luaL_error(L, "Invalid base64 text");
            }
            v = (unsigned)c[0] << 2 | c[1] >> 4;
            buffer[output] = v;
            ++ output;
            break;
        default:
            return luaL_error(L, "Invalid base64 text");
        }
    }
    lua_pushlstring(L, buffer, output);
    return 1;
}

static int
lxor_str(lua_State *L) {
    size_t len1,len2;
    const char *s1 = luaL_checklstring(L,1,&len1);
    const char *s2 = luaL_checklstring(L,2,&len2);
    if (len2 == 0) {
        return luaL_error(L, "Can't xor empty string");
    }
    luaL_Buffer b;
    char * buffer = luaL_buffinitsize(L, &b, len1);
    int i;
    for (i=0;i<len1;i++) {
        buffer[i] = s1[i] ^ s2[i % len2];
    }
    luaL_addsize(&b, len1);
    luaL_pushresult(&b);
    return 1;
}

static int
lcrc32(lua_State *L){
  size_t len;
  const char *str = luaL_checklstring(L, 1, &len);
  if (len <= 0) return luaL_error(L, "#1 need a string");

  uint32_t i = 0;
  uint32_t crc = 0xFFFFFFFF;

  for (i = 0; i < len; i++) crc = CRC32[ (crc ^ str[i]) & 0xff ] ^ (crc >> 8);
  lua_pushinteger(L, crc ^ 0xFFFFFFFF);
  return 1;
};

static int
lcrc64(lua_State *L){
  size_t len;
  const char *str = luaL_checklstring(L, 1, &len);
  if (len <= 0) return luaL_error(L, "#1 need a string");

  uint32_t i = 0;
  uint64_t crc = 0x0;
  for (i = 0; i < len; i++) crc = CRC64[(uint8_t)crc ^ (uint8_t)str[i]] ^ (crc >> 8);
  lua_pushnumber(L, crc);
  return 1;
};

LUAMOD_API int
luaopen_lcrypt(lua_State *L) {
    luaL_checkversion(L);
    static int init = 0;
    if (!init) {
        // Don't need call srandom more than once.
        init = 1 ;
        srandom((random() << 8) ^ (time(NULL) << 16) ^ getpid());
    }
    luaL_Reg crypt_libs[] = {
        { "hashkey", lhashkey },
        { "randomkey", lrandomkey },
        { "desencode", ldesencode },
        { "desdecode", ldesdecode },
        { "hexencode", ltohex },
        { "hexdecode", lfromhex },
        { "hmac64", lhmac64 },
        { "hmac64_md5", lhmac64_md5 },
        { "dhexchange", ldhexchange },
        { "dhsecret", ldhsecret },
        { "base64encode", lb64encode },
        { "base64decode", lb64decode },
        { "sha1", lsha1 },
        { "hmac_sha1", lhmac_sha1 },
        { "hmac_hash", lhmac_hash },
        { "xor_str", lxor_str },
        { "crc32", lcrc32 },
        { "crc64", lcrc64 },
        { NULL, NULL },
    };
    luaL_newlib(L, crypt_libs);
    return 1;
}
