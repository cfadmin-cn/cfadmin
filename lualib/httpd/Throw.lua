local type = type
local assert = assert
local toint = math.tointeger

---comment 检查http code是否合法.
---@param code integer @响应内容.
---@return boolean | integer
local function check_code(code)
  code = toint(code)
  return code and code >= 400 and code < 600 and code or nil
end

---comment 检查http response是否合法.
---@param response string @响应内容.
---@return boolean | string
local function check_response (response)
  return type(response) == 'string' and response ~= '' and response or nil
end

---comment 让注册的`USE`/`API`路由可以合法的抛出异常.
---@param code    integer  @HTTP状态码.
---@param response string  @异常附带的响应体.
return function (code, response)
  return { __OPCODE__ = -256, __CODE__ = assert(check_code(code), "Invalid http code."), __MSG__ = assert(check_response(response), "Invalid http response.") }
end