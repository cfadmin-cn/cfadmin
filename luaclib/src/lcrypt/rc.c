#include "lcrypt.h"

// RC4 对称加密/解密算法
int lrc4(lua_State *L) {
  size_t ksize = 0; size_t tsize = 0;

  const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &ksize);
  if (!key || ksize <= 0)
    return luaL_error(L, "Invalid rc4 key.");
  
  const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &tsize);
  if (!text || tsize <= 0)
    return luaL_error(L, "Invalid rc4 text.");

  char *buffer = lua_newuserdata(L, tsize);
  memset(buffer, 0x00, tsize);

  RC4_KEY rc4key;
  // 设置密钥
  RC4_set_key(&rc4key, ksize, key);
  // 加密/解密数据
  RC4(&rc4key, tsize, text, (uint8_t *)buffer);

  // 返回解密/解密的数据
  lua_pushlstring(L, buffer, tsize);

  return 1;
}