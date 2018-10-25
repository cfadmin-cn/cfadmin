require "internal.coroutine"

-- local callback = require "internal.callback"

local io = core_socket

local IO = {}

function IO.new()
	return io.new()
end

function IO.listen(ip, port, co)
	local server = IO.new()
	if not server then
		return
    end
	return server:listen(ip, port, co)
end

return IO