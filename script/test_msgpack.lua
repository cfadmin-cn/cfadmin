local Log = require ("logging"):new()

local msgpack = require "msgpack"

local msg = msgpack.encode({1, 2, 3, 4, name = "CandyMi"})
Log:DEBUG("序列化完成:"..msg)

Log:DEBUG(msgpack.decode(msg))
