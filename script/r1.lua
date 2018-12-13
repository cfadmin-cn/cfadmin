local class = require "class"


local route = class("route")


function route:ctor( ... )

end

function route:route( ... )
    return "<html><head></head><body><strong>hello world</strong></body></html>"
end

return route