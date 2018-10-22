local class = require "class"
local req = require "internal.req"
local resp = require "internal.resp"

local socket = core_socket
local ti = core_timer

local co_create = coroutine.create
local co_resume = coroutine.resume
local co_yield = coroutine.yield
local co_status = coroutine.status


local httpc = class("httpc")

local http = class("http")

function http:ctor(opt)
	self.fd   = opt.fd
	self.addr = opt.addr
	self.req  = req:new()
	self.resp = resp:new()
end

function httpc:ctor(opt)
	-- body
end