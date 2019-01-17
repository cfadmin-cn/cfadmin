-- implementing some functions from BitOp (http://bitop.luajit.org/) on Lua 5.3

return {
	lshift = function(x, n)
		return x << n
	end,
	rshift = function(x, n)
		return x >> n
	end,
	bor = function(x1, x2)
		return x1 | x2
	end,
	band = function(x1, x2)
		return x1 & x2
	end,
}

-- vim: ts=4 sts=4 sw=4 noet ft=lua
