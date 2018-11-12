local spliter = string.gsub
local match = string.match

local HTTP_PROTOCOL = {}

function HTTP_PROTOCOL.RESPONSE_HEAD_PARSER(head)
	local HEAD = {}
	spliter(head, "(.-): (.-)\r\n", function (key, value)
		if key == 'Content-Length' then
			HEAD['Content-Length'] = tonumber(value)
			return
		end
		HEAD[key] = value
	end)
	return HEAD
end

function HTTP_PROTOCOL.RESPONSE_PROTOCOL_PARSER(protocol)
	local VERSION, CODE, STATUS = match(protocol, "HTTP/([%d%.]+) (%d+) (.+)\r\n")
	return tonumber(CODE)
end

function HTTP_PROTOCOL.REQUEST_PARSER( ... )
	-- body
end

function HTTP_PROTOCOL.REQUEST_PARSER( ... )
	-- body
end


return HTTP_PROTOCOL