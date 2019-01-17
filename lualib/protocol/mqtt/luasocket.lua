-- DOC: http://w3.impa.br/~diego/software/luasocket/tcp.html

-- module table
local luasocket = {}

local socket = require("socket")

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function luasocket.connect(conn)
	local sock, err = socket.connect(conn.host, conn.port)
	if not sock then
		return false, "socket.connect failed: "..err
	end
	conn.sock = sock
	return true
end

-- Shutdown network connection
function luasocket.shutdown(conn)
	conn.sock:shutdown()
end

-- Send data to network connection
function luasocket.send(conn, data, i, j)
	-- print("send:", require("mqtt.tools").hex(data))
	return conn.sock:send(data, i, j)
end

-- Receive given amount of data from network connection
function luasocket.receive(conn, size)
	local ok, err = conn.sock:receive(size)
	-- if ok then
	-- 	print("receive:", size, require("mqtt.tools").hex(ok))
	-- end
	return ok, err
end

-- export module table
return luasocket

-- vim: ts=4 sts=4 sw=4 noet ft=lua
