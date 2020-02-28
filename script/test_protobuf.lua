local Log = require "logging"

local pb = require "protobuf"

--[[
测试与使用指南:

  1. 安装protobuf的命令行二进制生成工具protoc.

  2. 使用命令 protoc Person.proto -o Person.pb 生成协议文件.

  3. 使用loadfile读取生成的协议文件Person.pb后就完成了数据结构注册与导入.

  4. 这有时候就可以开始使用encode/decode方法进行代码测试.

  5. 需要注意的是: protobuf协议需要"先定义(注册), 后使用", 支持protobuf v2/v3版本语法.
]]

Log:DEBUG(pb.loadfile("Person.pb"))

local pb_string = pb.encode("Person", {
  name = "CandyMi",
  age = 2^32 - 1,
  hand = {
    left = "左手",
    right = "右手",
  },
  foot = {
    left = "左脚",
    right = "右脚",
  }
})
Log:DEBUG(pb.tohex(pb_string))

Log:DEBUG(pb.decode("Person", pb_string))

Log:DEBUG(pb.clear("Person"))
