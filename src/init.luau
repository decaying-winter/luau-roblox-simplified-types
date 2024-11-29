local dom = require("./dom");
local reflection = require("./reflection");

local module = {};

module.dom = dom;
module.reflection = reflection;

function module.deserializePlace(contents: string)
    error("Not implemented");
end

function module.deserializeModel(contents: string)
    error("Not implemented");
end

function module.serializePlace(dataModel: string, xml: boolean?): string
    error("Not implemented");
end

function module.serializeModel(instances: {any}, xml: boolean?): string
    error("Not implemented");
end

function module.getReflectionDatabase(): reflection.ReflectionDatabase
    return reflection;
end

return module;
