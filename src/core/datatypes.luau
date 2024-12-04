--!strict
local datatypes = require("../datatypes");
local enums = require("./types/roblox_enums");

local types = {}

type DataType = {
    new: (...any) -> any,
};

for type, datatype in datatypes do
    types[type::string] = (datatype::any).DataType::DataType;
end

return (types::any)::{
    Enum: enums.Enums,
    [string]: DataType,
};
