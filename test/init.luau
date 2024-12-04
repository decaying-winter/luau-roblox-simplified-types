--!strict
local fs = zune.fs
local process = zune.process
local testing = zune.testing

local test = testing.test

local lib = require("@roblox");

test("Deserialize and serialize place", function()
    local file = fs.readFile("./rbx-test-files/places/baseplate-566/binary.rbxl");
    local datamodel = lib.deserializePlace(file);
    local serialized = lib.serializePlace(datamodel);
    print(datamodel, serialized);
end)

test("Deserialize and serialize model", function()
    local file = fs.readFile("./rbx-test-files/models/attributes/binary.rbxm");
    local model = lib.deserializeModel(file);
    local serialized = lib.serializeModel(model);
    print(model, serialized);
end)

if (process.args[2] == "--all") then
    require("./dom/binary");
end
