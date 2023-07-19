# 作者信息
message("======================================")
message("Project Name   : cfadmin")
message("Author  Name   : CandyMi")
message("Author  Email  : 869646063@qq.com")
message("Author  Github : github.com/CandyMi")
message("======================================")

# 最低版本号
cmake_minimum_required(VERSION 2.8...3.13)

# 项目名称
project("cfadmin")

if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  set(CMAKE_MACOSX_RPATH 1)
else()
  set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
endif()


# 依赖openssl
find_package(OpenSSL 1.0.1 REQUIRED)

# 头文件存放位置
include_directories( ${CMAKE_CURRENT_SOURCE_DIR}/src /usr/local/include )
# 库文件存放路径
link_directories( ${CMAKE_CURRENT_SOURCE_DIR} /usr/local/lib )

set(cf_rpath
  "-Wl,-rpath,./"
  "-Wl,-rpath,../"
  "-Wl,-rpath,/usr/local/lib"
)

set(cf_core
  src/core.c
  src/core_ev.c
  src/core_sys.c
  src/core_memory.c
)

set(cf_admin
  src/core_start.c
)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu99 -Wno-implicit-fallthrough -minline-all-stringops")

# 编译版本
if (CMAKE_BUILD_TYPE STREQUAL Release)
  add_compile_options(-O2 -g -W -Wall -Wno-unused-parameter -Wno-unused-function -Wno-sign-compare)
else()
  add_compile_options(-O0 -g -W -Wall -Wno-unused-parameter -Wno-unused-function -Wno-sign-compare)
  add_definitions(-DDEBUG=1)
endif()

add_definitions(-D_GNU_SOURCE=1)

# 构建libcore
add_library(core SHARED ${cf_core})
set_target_properties(
  core PROPERTIES
    INSTALL_RPATH ${cf_rpath}
    LINK_FLAGS ${cf_rpath}
  core PROPERTIES
    PREFIX "lib"
  core PROPERTIES
    C_EXTENSIONS ON
)

# 内存分配器
if(USE_MIMALLOC OR MIMALLOC)
  target_link_libraries(core PRIVATE ev PRIVATE eio PRIVATE lua PRIVATE dl PRIVATE m PRIVATE pthread PRIVATE mimalloc)
  add_definitions(-DUSE_ALLOCATOR=1 -DUSE_MIMALLOC=1)
elseif(USE_JEMALLOC OR JEMALLOC)
  target_link_libraries(core PRIVATE ev PRIVATE eio PRIVATE lua PRIVATE dl PRIVATE m PRIVATE pthread PRIVATE jemalloc)
  add_definitions(-DUSE_ALLOCATOR=1 -DUSE_JEMALLOC=1)
elseif(USE_TCMALLOC OR TCMALLOC)
  target_link_libraries(core PRIVATE ev PRIVATE eio PRIVATE lua PRIVATE dl PRIVATE m PRIVATE pthread PRIVATE tcmalloc)
  add_definitions(-DUSE_ALLOCATOR=1 -DUSE_TCMALLOC=1)
else()
  target_link_libraries(core PRIVATE ev PRIVATE eio PRIVATE lua PRIVATE dl PRIVATE m PRIVATE pthread)
endif()

# cfadmin可执行文件
add_executable(cfadmin ${cf_admin})
target_link_libraries(cfadmin PRIVATE core)
set_target_properties(
  cfadmin PROPERTIES
    LINK_FLAGS ${cf_rpath}
    INSTALL_RPATH "${cf_rpath}"
)

# 构建`luaclib`
add_subdirectory( luaclib )

# 调试环境
file(COPY ${PROJECT_SOURCE_DIR}/lualib DESTINATION ${PROJECT_SOURCE_DIR}/build)
file(COPY ${PROJECT_SOURCE_DIR}/script DESTINATION ${PROJECT_SOURCE_DIR}/build)

# 安装`lualib`/`script`
install(
  DIRECTORY
    ${PROJECT_SOURCE_DIR}/script
    ${PROJECT_SOURCE_DIR}/lualib
  DESTINATION
    ${CMAKE_INSTALL_PREFIX}
)

# 安装头文件、动态库、可执行文件
install(
  TARGETS cfadmin core
  RUNTIME  DESTINATION ${CMAKE_INSTALL_PREFIX} # cfadmin.exe
  LIBRARY  DESTINATION ${CMAKE_INSTALL_PREFIX} # libcore
)