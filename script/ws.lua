local class = require "class"
local cf = require "cf"
require "utils"
local websocket = class("websocket")


function websocket:ctor(opt)
    self.ws = opt.ws             -- websocket对象
    self.args = opt.args         -- GET传递的参数
    self.headers = opt.headers   -- HTTP请求头部
    self.send_masked = false     -- 掩码(默认为false, 不建议修改或者使用)
    self.max_payload_len = 65535 -- 最大有效载荷长度(默认为65535, 不建议修改或者使用)
    self.timeout = 15            -- 默认为一直等待, 非number类型会导致异常.
    self.count = 0
    var_dump(self.args)
    var_dump(self.headers)
end

function websocket:on_open()
    print('on_open')
    self.timer = cf.at(0.01, function ( ... ) -- 定时器
        self.count = self.count + 1
        self.ws:send(tostring(self.count))
    end)
end

function websocket:on_message(data, typ)
    print('on_message', self.ws, data)
    self.ws:send('welcome')
    -- self.ws:close(data)
end

function websocket:on_error(error)
    print('on_error', self.ws, error)
end

function websocket:on_close(data)
    print('on_close', self.ws, data)
    if self.timer then -- 清理定时器
      print("清理定时器")
      self.timer:stop()
      self.timer = nil
    end
end

return websocket
