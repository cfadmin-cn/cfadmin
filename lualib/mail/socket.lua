local TCP = require "internal.TCP"

local socket = {}
-- hook connect 与 ssl connect
function socket.connect(host, port, SSL)
	local session = TCP:new()
	if not SSL then
		local ok, err = session:connect(host, port)
		if not ok then
			session:close()
			return ok, err
		end
	else
		local ok, err = session:ssl_connect(host, port)
		if not ok then
			session:close()
			return ok, err
		end
	end
	return session
end

-- hook read 与 ssl read
function socket.recv(session, bytes, SSL)
	if not SSL then
		return session:recv(bytes)
	end
	return session:ssl_recv(bytes)
end

-- hook send 与 ssl send
function socket.send(session, buf, SSL)
	if not SSL then
		return session:send(buf)
	end
	return session:ssl_send(buf)
end

-- hook close session
function socket.close(session)
	return session:close()
end

return socket
