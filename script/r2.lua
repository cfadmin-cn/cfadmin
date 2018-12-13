local class = require "class"


local route = class("route")


function route:ctor( ... )

end

function route:route( ... )
    return '{"username":"admin", "password":"admin"}'
end

return route