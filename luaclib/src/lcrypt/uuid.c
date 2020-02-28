#include "lcrypt.h"

#define UUID_V4_LENGTH 36

static inline int uuid_v4_gen(char *buffer)
{
  union {
    struct {
      uint32_t time_low;
      uint16_t time_mid;
      uint16_t time_hi_and_version;
      uint8_t  clk_seq_hi_res;
      uint8_t  clk_seq_low;
      uint8_t  node[6];
    };
    uint8_t __rnd[16];
  } uuid;

  int rc = RAND_bytes(uuid.__rnd, sizeof(uuid));

  uuid.clk_seq_hi_res = (uint8_t) ((uuid.clk_seq_hi_res & 0x3F) | 0x80);
  uuid.time_hi_and_version = (uint16_t) ((uuid.time_hi_and_version & 0x0FFF) | 0x4000);

  snprintf(buffer, UUID_V4_LENGTH, "%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
    uuid.time_low, uuid.time_mid, uuid.time_hi_and_version,
    uuid.clk_seq_hi_res, uuid.clk_seq_low,
    uuid.node[0], uuid.node[1], uuid.node[2],
    uuid.node[3], uuid.node[4], uuid.node[5]
  );

  return rc;
}

int luuid(lua_State *L) {
  luaL_Buffer b;
  char *UUID = luaL_buffinitsize(L, &b, UUID_V4_LENGTH);
  uuid_v4_gen(UUID);
  luaL_pushresultsize(&b, UUID_V4_LENGTH);
  return 1;
}