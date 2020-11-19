local lprotobuf = require "lprotobuf"


local lprotobuf_tohex = lprotobuf.tohex

local lprotobuf_clear = lprotobuf.clear

local lprotobuf_load = lprotobuf.load
local lprotobuf_loadfile = lprotobuf.loadfile

local lprotobuf_encode = lprotobuf.encode
local lprotobuf_decode = lprotobuf.decode


local pb = {}

-- 转化为16进制可读字符串
function pb.tohex (pb_string)
  return lprotobuf_tohex(pb_string)
end

-- 从字符串中读取
function pb.load (pb_cp_string)
  return lprotobuf_load(pb_cp_string)
end

-- 从文件中读取
function pb.loadfile (filename)
  return lprotobuf_loadfile(filename)
end

-- 序列化
function pb.encode (pb_registey, table)
  return lprotobuf_encode(pb_registey, table)
end

-- 反序列化
function pb.decode (pb_registey, pb_string)
  return lprotobuf_decode(pb_registey, pb_string)
end

-- 清理
-- When you passed A not exists message struct will get Segmentation fault.
function pb.clear (...)
  return lprotobuf_clear(...)
end

-- require ("logging"):new():DEBUG(lprotobuf)

return pb
