# 最低版本号
cmake_minimum_required(VERSION 2.8...3.13)

# 项目名称
project("cfadmin luaclib")

if(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
  set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
endif()

set(cf_luaclib
  sys
  tcp
  udp
  task
  pack
  timer
  child
  cjson
  laio
  lz
  lfs
  lpeg
  lcrypt
  lmsgpack
  lprotobuf
  lhttpparser  
)

# sys库
FILE(GLOB sys src/lsys.c)
add_library(sys SHARED ${sys})
target_link_libraries(sys PRIVATE core)

# tcp库
FILE(GLOB tcp src/ltcp.c)
add_library(tcp SHARED ${tcp})
target_link_libraries(tcp PRIVATE core crypto ssl)

# udp库
FILE(GLOB udp src/ludp.c)
add_library(udp SHARED ${udp})
target_link_libraries(udp PRIVATE core)

# task库
FILE(GLOB task src/ltask.c)
add_library(task SHARED ${task})
target_link_libraries(task PRIVATE core)

# pack库
FILE(GLOB pack src/lpack.c)
add_library(pack SHARED ${pack})
target_link_libraries(pack PRIVATE core)

# child库
FILE(GLOB child src/lchild.c)
add_library(child SHARED ${child})
target_link_libraries(child PRIVATE core)

# timer库
FILE(GLOB timer src/ltimer.c)
add_library(timer SHARED ${timer})
target_link_libraries(timer PRIVATE core)


# aio库
FILE(GLOB laio src/laio.c)
add_library(laio SHARED ${laio})
target_link_libraries(laio PRIVATE core eio)

# lz库
FILE(GLOB lz src/lz/*.c)
add_library(lz SHARED ${lz})
target_link_libraries(lz PRIVATE core)

# lfs库
FILE(GLOB lfs src/lfs/*.c)
add_library(lfs SHARED ${lfs})
target_link_libraries(lfs PRIVATE core)

# pbc库
FILE(GLOB lprotobuf src/lpbc/*.c)
add_library(lprotobuf SHARED ${lprotobuf})
target_link_libraries(lprotobuf PRIVATE core)

# peg库
FILE(GLOB lpeg src/lpeg/*.c)
add_library(lpeg SHARED ${lpeg})
target_link_libraries(lpeg PRIVATE core)

# cjson库
FILE(GLOB cjson src/lcjson/*.c)
add_library(cjson SHARED ${cjson})
target_link_libraries(cjson PRIVATE core)

# crypt库
FILE(GLOB lcrypt src/lcrypt/*.c)
add_library(lcrypt SHARED ${lcrypt})
target_link_libraries(lcrypt PRIVATE core crypto ssl)

# httpparser库
FILE(GLOB lhttpparser src/lhttpparser/*.c)
add_library(lhttpparser SHARED ${lhttpparser})
target_link_libraries(lhttpparser PRIVATE core)

# msgpack库
FILE(GLOB lmsgpack src/lmsgpack/*.c)
add_library(lmsgpack SHARED ${lmsgpack})
target_link_libraries(lmsgpack PRIVATE core)

# 配置属性
set_target_properties(
  ${cf_luaclib} PROPERTIES
    C_EXTENSIONS ON C_STANDARD 99
    INSTALL_RPATH ${cf_rpath}
    LINK_FLAGS ${cf_rpath}
    PREFIX ""
)

  # 安装luaclib
install(
  TARGETS ${cf_luaclib}
  RUNTIME DESTINATION luaclib
  LIBRARY DESTINATION luaclib
)