local type = type
local assert = assert

local aio = require "aio"
local aio_stat = aio.stat

---@comment Httpd响应构造器
local Response = { __VERSION__ = 0.1 }

---@comment 文件类型
---@param filename   string   @合法且完整的`文件路径`(如: `static/index.html`)
---@param filetype   string   @合法且完整的`文件类型`(如: `text/css`)
---@param fileinline boolean  @响应的文件是否需要内嵌到浏览器
---@return table              @`文件`响应构造器
function Response.file_response(filename, filetype, fileinline)
  assert(type(filename) == 'string' and filename ~= '', "[http `make_file` response] : file name does not exist.")
  local info = aio_stat(filename)
  if type(info) ~= 'table' or info.mode ~= 'file' then
    return assert(nil, "[http `make_file` response] : can't find file or invalid file type.")
  end
  return { __OPCODE__ = -128, __CODE__ = 200, __FILEINLINE__ = fileinline, __FILENAME__ = filename, __FILETYPE__ = type(filetype) == 'string' and filetype or nil, __FILESIZE__ = aio_stat(filename).size }
end

---@comment 文本类型
---@param ctext string   @合法且完整的`响应内容`(如: `<html>Hello World.</html>`)
---@param ctype string   @合法且完整的`响应类型`(如: `text/html`)
---@return table         @`文本`响应构造器
function Response.text_response(ctext, ctype)
  assert(type(ctype) == 'string' and type(ctext)  == 'string', "[http `make_text` response] : Invalid content type or response content.")
  return { __OPCODE__ = -128, __CODE__ = 200, __TYPE__ = ctype, __MSG__ = ctext }
end

return Response