local httpd = require "httpd"
local json = require "json"

local app = httpd:new("httpd")

--[[
<!DOCTYPE html>
<html>
<head>
    <title>本地文件上传</title>
</head>
<body>
    <form action="http://localhost:8080/upload_local" method=post enctype="multipart/form-data">
        <input type="file" name="点击上传" value="上传文件①" />
            <br>
        <input type="file" name="点击上传" value="上传文件②" />
            <br>
        <input type="submit" value="提交" />
    </form>
</body>
</html>
]]

app:api("/upload_local", function (content)
  if content.files then
    for _, item in ipairs(content.files) do
      local f, err = io.open("static/"..item.filename, "w+")
      if f then
        f:write(item.file)
        f:flush()
        f:close()
      else
        print("ERROR: " .. err)
      end
    end
    return json.encode { code = 200, status = "OK" }
  end
  return json.encode { code = 404, status = "没有上传内容." }
end)

app:static("static", 30)

app:listen("0.0.0.0", 8080)

app:run()
