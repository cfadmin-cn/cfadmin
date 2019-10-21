-- 从httpc库导入并且使用
local httpc = require "httpc"

local basic_key, basic_value = httpc.basic_authorization("myusername", "mypassword")
print(basic_key, basic_value)

local jwt_header_key, jwt_header_value = httpc.jwt("mysecret", [[{"key1":"value1","key2":"value2"}]])
print(jwt_header_key, jwt_header_value)


-- 从httpc类库中导入并且使用
local httpc_cls = require "httpc.class"
local hc = httpc_cls:new {}

local basic_key, basic_value = hc:basic_authorization("myusername", "mypassword")
print(basic_key, basic_value)

local jwt_header_key, jwt_header_value = hc:jwt("mysecret", [[{"key1":"value1","key2":"value2"}]])
print(jwt_header_key, jwt_header_value)