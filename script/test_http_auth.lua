-- 从httpc库导入并且使用
local httpc = require "httpc"

local basic_key, basic_value = httpc.basic_authorization("myusername", "mypassword")
print(basic_key, basic_value)

-- 从httpc类库中导入并且使用
local httpc_cls = require "httpc.class"
local hc = httpc_cls:new {}

local basic_key, basic_value = hc:basic_authorization("myusername", "mypassword")
print(basic_key, basic_value)

-- 从json.jwt导出
local jwt = require "json.jwt"
local raw = '{"name":"Hello world."}'
local enc = jwt.encode(raw, "secret", "HS256")
local dec = jwt.decode(enc, "secret", "HS256")
print("jwt test:", raw == dec, enc)