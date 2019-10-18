local httpd = require "httpd"
local json = require "json"

local app = httpd:new("httpd")

app:use("/upload", function(content)
  return [[
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
end)

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


app:use('/qiniu_upload', function(content)
  return [[
<!DOCTYPE html>
<html>
<head>
  <title>七牛文件上传</title>
  <script type="text/javascript" src="/js/jquery.min.js"></script>
</head>
<body>
  <form action="https://up-z2.qiniup.com" method=post enctype="multipart/form-data">
    <input id="token" name="token" type="hidden">
    <input name="file" type="file" />
    <input type="submit" value="提交" />
  </form>
  <p id="print">无token</p>
</body>
<script type="text/javascript">
  $.get("http://localhost:8080/qiniu_token", {},  function(data, status) {
    $("#print").text(data.token)            // 将服务端生成的token打印出来.
    $("#token").attr("value", data.token)   // 将服务端生成的token添加到token的value中.
  })
</script>
</html>
]]
end)

local oss = require "cloud.qiniu.oss"
app:api('/qiniu_token', function (content)
  local access_key = "your_access_key"
  local secret_key = "your_secret_key"
  return json.encode {
    code = 200,
    token = oss.getUploadToken(access_key, secret_key, {
      bucket = "candymi", -- 对应bucket名称(这个必填, 其它选填)
    }),
  }
end)

app:static("static")

app:listen("0.0.0.0", 8080)

app:run()
