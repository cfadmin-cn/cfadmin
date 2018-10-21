local ti = core_timer

-- 可手动关闭的定时器(虽然提供的意义不大, 如果不需要手动关闭, 忽略返回值即可) --
local function timeout(timeout, cb, ...)
	if type(timeout) ~= "number" or timeout < 0 then
		return nil
	end
	local t = {
		closed = nil,
	}
	ti.timeout(timeout, function(...)
		if not t.closed then
			cb(...)
		end
	end)
	return t
end
