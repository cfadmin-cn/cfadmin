local split = string.gsub
local match = string.match

local HTTP_PROTOCOL = {}

function HTTP_PROTOCOL.RESPONSE_HEAD_PARSER(HTTP, head)
	string.gsub(head, "(.-): (.-)\r\n", function (key, value)
		if key == 'Content-Length' then
			HTTP['Content-Length'] = tonumber(value)
			return
		end
		if key == 'Connection' and value == 'keep-alive' then
			HTTP[key] = value
			return 
		end
		HTTP[key] = value
	end)
end

function HTTP_PROTOCOL.RESPONSE_PROTOCOL_PARSER(HTTP, protocol)
	local VERSION, CODE, STATUS = match(protocol, "HTTP/([%d%.]+) (%d+) (%w+)")
	HTTP['VERSION'] = tonumber(VERSION)
	HTTP['CODE'] = tonumber(CODE)
	HTTP['STATUS'] = STATUS
	if not VERSION and not CODE or tonumber(CODE) < 1.0 then
		return 400
	end
	return 200
end

function HTTP_PROTOCOL.RESPONSE_BODY_PARSER(HTTP, body)
	return "BODY"
end


function HTTP_PROTOCOL.REQUEST_PARSER( ... )
	-- body
end

function HTTP_PROTOCOL.REQUEST_PARSER( ... )
	-- body
end


return HTTP_PROTOCOL