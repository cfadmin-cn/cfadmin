local class = require "class"


local r1 = class("r1")

function r1:ctor(opt)
    
end

function r1:get()
    return 'this request build-in '..self.__name
end

return r1