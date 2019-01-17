-- DOC: http://w3.impa.br/~diego/software/luasocket/tcp.html

-- module table
local luasocket_ssl = {}

local ssl = require("ssl")
local luasocket = require("mqtt.luasocket")

-- Open network connection to .host and .port in conn table
-- Store opened socket to conn table
-- Returns true on success, or false and error text on failure
function luasocket_ssl.connect(conn)
	assert(type(conn.ssl_params) == "table", "expecting .ssl_params to be a table")
	-- open usual TCP connection
	local ok, err = luasocket.connect(conn)
	if not ok then
		return false, "luasocket connect failed: "..err
	end
	local wrapped
	-- TLS/SSL initialization
	wrapped, err = ssl.wrap(conn.sock, conn.ssl_params)
	if not wrapped then
		conn.sock:shutdown()
		return false, "ssl.wrap() failed: "..err
	end
	ok, err = wrapped:dohandshake()
	if not ok then
		conn.sock:shutdown()
		return false, "ssl dohandshake failed: "..err
	end
	-- replace sock in connection table with wrapped secure socket
	conn.sock = wrapped
	return true
end

-- Shutdown network connection
function luasocket_ssl.shutdown(conn)
	conn.sock:close()
end

-- Copy original send/receive methods from mqtt.luasocket module
luasocket_ssl.send = luasocket.send
luasocket_ssl.receive = luasocket.receive

-- export module table
return luasocket_ssl

-- vim: ts=4 sts=4 sw=4 noet ft=lua
