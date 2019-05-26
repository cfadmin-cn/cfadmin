local wc = require "protocol.websocket.client"

-- local w = wc:new {url = "wss://[::1]/ws"}
-- local w = wc:new {url = "wss://[::1]:8080/ws"}
local w = wc:new {url = "ws://localhost:8080/ws"}
local ok, ret = w:connect()
if not ok then
	return print(ok, ret)
end

w:ping('ping')

print(w:recv())

while 1 do
	local data, typ = w:recv()
	print(data, typ)
	if not data then
		break
	end
end

w:close()
