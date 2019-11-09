local httpparser = require "httpparser"
local PARSER_HTTP_REQUEST = httpparser.parser_http_request
local PARSER_HTTP_RESPONSE = httpparser.parser_http_response
local RESPONSE_CHUNKED_PARSER = httpparser.parser_response_chunked

local pcall = pcall

local http_parser = {}

function http_parser.PARSER_HTTP_REQUEST (buffer)
  local ok, method, path, version, header = pcall(PARSER_HTTP_REQUEST, buffer)
  if not ok then
    return nil
  end
  return method, path, version, header
end

-- 解析http回应
function http_parser.PARSER_HTTP_RESPONSE (buffer)
  local ok, version, code, status, header = pcall(PARSER_HTTP_RESPONSE, buffer)
  if not ok then
    return nil
  end
  return version, code, status, header
end

-- 解析回应chunked
function http_parser.RESPONSE_CHUNKED_PARSER (data)
  local ok, data, pos = pcall(RESPONSE_CHUNKED_PARSER, data)
  if not ok then
    return nil, -1
  end
  return data, pos
end

return http_parser