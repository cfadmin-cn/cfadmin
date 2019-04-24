-- 对xml2lua的简单封装, 简化xml2lua调用流程
local xml2lua = require "xml2lua.xml2lua"
local xml2lua_handler = require "xml2lua.xmlhandler.tree"


local xml = {}

-- xml字符串解析
function xml.parser(xml_data)
  local cls = xml2lua.parser(xml2lua_handler:new())
  cls:parse(xml_data)
  return cls.handler.root
end

-- xml文件读取
function xml.load(xml_path)
  if type(xml_path) ~= 'string' or xml_path == '' then
    return nil, '无效的xml文件路径.'
  end
  local xfile, error = xml2lua.loadFile(xml_path)
  if xfile then
    return xml.parser(xfile)
  end
  return xfile, error
end

return xml
