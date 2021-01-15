#define LUA_LIB

#include <core.h>
#include <ifaddrs.h>

#define MAX_IPV4 (4294967295L)

// 提供一个精确到微秒的时间戳
static int lnow(lua_State *L){
	lua_pushnumber(L, now());
	return 1;
}

/* 此方法可用于检查是否为有效ipv4地址*/
static int lipv4(lua_State *L){
  size_t str_len = 0;
  const char *IP = luaL_checklstring(L, 1, &str_len);
  if (!IP || str_len == 0)
    return luaL_error(L, "ipv4 error: A parameter of type string is required\n");
  lua_pushboolean(L, ipv4(IP));
  return 1;
}

/* 此方法可用于检查是否为有效ipv6地址*/
static int lipv6(lua_State *L){
  size_t str_len = 0;
  const char *IP = luaL_checklstring(L, 1, &str_len);
  if (!IP || str_len == 0)
    return luaL_error(L, "ipv6 error: A parameter of type string is required\n");
  lua_pushboolean(L, ipv6(IP));
  return 1;
}

/* string 转换为 IPv4 */ 
static int lstr2ip(lua_State *L){
  size_t str_len = 0;
  const char *IP = luaL_checklstring(L, 1, &str_len);
  if (!IP || str_len < 3 || str_len > 15)
    return luaL_error(L, "Invalid IP.");
  uint32_t addr = 0;
  if (inet_pton(AF_INET, IP, (void*)&addr) != 1)
    return 0;
  lua_pushinteger(L, addr);
  return 1;
}

/* IPv4 转换为 string */ 
static int lip2str(lua_State *L){
  lua_Unsigned IP = luaL_checkinteger(L, 1);
  if (IP > MAX_IPV4)
    return luaL_error(L, "Invalid IP.");
  char str[INET_ADDRSTRLEN];
  memset(str, 0x0, INET_ADDRSTRLEN);
  if (!inet_ntop(AF_INET, (const void*)&IP, str, INET_ADDRSTRLEN))
    return 0;
  lua_pushlstring(L, str, strlen(str));
  return 1;
}

/* 返回格式化后的时间 */
static int ldate(lua_State *L){
  size_t str_len = 0;
  const char *fmt = luaL_checklstring(L, 1, &str_len);
  if (!fmt || str_len == 0)
    return luaL_error(L, "Date: Invalid format.");

  time_t timestamp = lua_tointeger(L, 2);
  if (0 >= timestamp)
    timestamp = time(NULL);

  size_t len = 128 + str_len;
  char fmttime[len];
  memset(fmttime, 0x0, len);
  int result = strftime(fmttime, len, fmt, localtime(&timestamp));
  if (result < 0)
    return 0;
  lua_pushlstring(L, fmttime, result);
  return 1;
}

/* 返回当前操作系统类型 */
static int los(lua_State *L){
  lua_pushstring(L, os());
  return 1;
}

/* 返回主机名 */
static int lhostname(lua_State *L){
  size_t max_hostaname = 4096;
  char *hostname = lua_newuserdata(L, max_hostaname);
  memset(hostname, 0x0, max_hostaname);
  int len = gethostname(hostname, max_hostaname);
  if (0 > len)
    return 0;
  lua_pushlstring(L, hostname, strlen(hostname));
  return 1;
}

/* 创建表 */
static int lnew_tab(lua_State *L){
  // lua_Integer array_size = luaL_checkinteger(L, 1); // array 部分大小
  // lua_Integer hash_size = luaL_checkinteger(L, 2);  // hash  部分大小
  lua_createtable(L, luaL_checkinteger(L, 1), luaL_checkinteger(L, 2));
  return 1;
}

/* 高效替换字符串 */
static int lstrrep(lua_State *L){
  size_t src_len = 0;
  const char *src = (const char *)luaL_checklstring(L, 1, &src_len);
  if (!src || src_len == 0)
    return luaL_error(L, "Invalid source string.");

  lua_Integer pos = luaL_checkinteger(L, 2);
  if (pos < 1 || pos > src_len)
    return luaL_error(L, "Invalid source pos.");

  size_t rep_len = 0;
  const char *rep = (const char *)luaL_checklstring(L, 3, &rep_len);
  if (!rep || rep_len == 0 || rep_len > src_len || rep_len > (src_len - pos + 1))
    return luaL_error(L, "Invalid rep string.");

  luaL_Buffer B;
  char* str = luaL_buffinitsize(L, &B, src_len);
  /* 将源字符串拷贝到开辟空间 */
  memmove(str, src, src_len);
  /* 将替换内容覆盖原先的内存 */
  memmove(str + (pos - 1), rep, rep_len);
  luaL_pushresultsize(&B, src_len);
  return 1;
}

static int linterface(lua_State *L){
  struct ifaddrs *ifc, *ifc1;
  if(getifaddrs(&ifc))
    return 0;
  lua_createtable(L, 32, 0);
  ifc1 = ifc;
  int index = 1;
  for(; NULL != ifc; ifc = (*ifc).ifa_next) {
    if ((*ifc).ifa_addr && (*ifc).ifa_netmask && (*ifc).ifa_name) {
      char ip[64] = {0};
      char mask[64] = {0};
      // IPv4
      if ((*ifc).ifa_addr->sa_family == AF_INET && (*ifc).ifa_netmask->sa_family == AF_INET) {
        inet_ntop(AF_INET, &(((struct sockaddr_in*)((*ifc).ifa_addr))->sin_addr), ip, 64);
        inet_ntop(AF_INET, &(((struct sockaddr_in*)((*ifc).ifa_netmask))->sin_addr), mask, 64);
        if (0 != strncmp("0.0.0.0", ip, strlen(ip)) && 0 != strncmp("0.0.0.0", mask, strlen(mask))){
          lua_createtable(L, 0, 4);
          lua_pushliteral(L, "Interface"); lua_pushstring(L, (*ifc).ifa_name); lua_rawset(L, -3);
          lua_pushliteral(L, "IP"); lua_pushstring(L, ip); lua_rawset(L, -3);
          lua_pushliteral(L, "Mask"); lua_pushstring(L, mask); lua_rawset(L, -3);
          lua_pushliteral(L, "Version"); lua_pushliteral(L, "IPv4"); lua_rawset(L, -3);
          lua_rawseti(L, -2, index++);
        }
      }
      // IPv6
      if ((*ifc).ifa_addr->sa_family == AF_INET6 && (*ifc).ifa_netmask->sa_family == AF_INET6) {
        inet_ntop(AF_INET6, &(((struct sockaddr_in6*)((*ifc).ifa_addr))->sin6_addr), ip, 64);
        inet_ntop(AF_INET6, &(((struct sockaddr_in6*)((*ifc).ifa_netmask))->sin6_addr), mask, 64);
        if (0 != strncmp("::", ip, strlen(ip)) && 0 != strncmp(ip, "fe80", 4)) {
          lua_createtable(L, 0, 4);
          lua_pushliteral(L, "Interface"); lua_pushstring(L, (*ifc).ifa_name); lua_rawset(L, -3);
          lua_pushliteral(L, "IP"); lua_pushstring(L, ip); lua_rawset(L, -3);
          lua_pushliteral(L, "Mask"); lua_pushstring(L, mask); lua_rawset(L, -3);
          lua_pushliteral(L, "Version"); lua_pushliteral(L, "IPv6"); lua_rawset(L, -3);
          lua_rawseti(L, -2, index++);
        }
      }
    }
  }
  freeifaddrs(ifc1);
  return 1;
}

LUAMOD_API int luaopen_sys(lua_State *L){
  luaL_checkversion(L);
  luaL_Reg sys_libs[] = {
    {"os", los},
    {"now", lnow},
    {"date", ldate},
    {"ipv4", lipv4},
    {"ipv6", lipv6},
    {"strrep", lstrrep},
    {"str2ip", lstr2ip},
    {"ip2str", lip2str},
    {"hostname", lhostname},
    {"interface", linterface},
    {"new_tab", lnew_tab},
    {NULL, NULL}
  };
  luaL_newlib(L, sys_libs);
  return 1;
}
