--!strict
local impl = {};
impl.method = {};
impl.property = {};
impl.property.get = {};
impl.property.set = {};

function impl.method.IsA(self: any, className: string)
    local classMap = self["@internal_map"];
    if (self["@class"] == className) then
        return true;
    end
    local class = classMap[self["@class"]];
    while (class.Superclass ~= "<<<ROOT>>") do
        if (class.Superclass == className) then
            return true;
        end
        class = classMap[class.Superclass];
        if (not class) then
            break;
        end
    end
    return false;
end

function impl.property.get.ClassName(self: any)
    return self["@class"];
end
function impl.property.get.className(self: any)
    return self["@class"];
end

return impl;
