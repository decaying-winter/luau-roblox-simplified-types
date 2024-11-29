--!strict
local Helper = require("./Helper");

local Vector2 = {};

local isFn = Helper.DataTypeIsFn(Vector2);

Vector2.__newindex = function()
    error("Cannot change");
end

local CACHE = setmetatable({}, {__mode = "v"});

function Vector2.new(X: number?, Y: number?): Vector2
    local hash = Helper.ValuesHash(X or 0, Y or 0);
    local cached = CACHE[hash];
    if (cached) then
        return cached;
    end
    local self = setmetatable({
        X = X or 0,
        Y = Y or 0,
    }, Vector2);
    CACHE[hash] = self;
    return self;
end

export type Vector2 = typeof(Vector2.new(0, 0));

function Vector2.__add(self: Vector2, b: Vector2): Vector2
    assert(isFn(b), "Invalid argument #1, expected Vector2");
    return Vector2.new(self.X + b.X, self.Y + b.Y);
end

function Vector2.__sub(self: Vector2, b: Vector2): Vector2
    assert(isFn(b), "Invalid argument #1, expected Vector2");
    return Vector2.new(self.X - b.X, self.Y - b.Y);
end

local function Serialize(value: Vector2): (number, number)
    return value.X, value.Y;
end

local function Deserialize(x: number, y: number): Vector2
    return Vector2.new(x, y)
end

return {
    DataType = Vector2,
    Serialize = Serialize,
    Deserialize = Deserialize,
    Is = isFn,
};
