--!strict

-- DOMProperty
local Stream = require("../../dom/binary/stream");
local datatypes = require("../../datatypes");

type BufferStream = Stream.BufferStream;

local function size(t: {[any]: any}): number
    local c = 0;
    for _ in t do
        c += 1;
    end
    return c;
end

local function validateAttributeKey(key: string): boolean
    return (key:find("[^%w_-]+")) == nil;
end

local VARIENTS = {
    Unknown = 0,
    String = 2,
    Bool = 3,
    Int = 4,
    Float = 5,
    Double = 6,
    UDim = 9,
    UDim2 = 10,
    BrickColor = 14,
    Color3 = 15,
    Vector2 = 16,
    Vector3 = 17,
    CFrame = 19,
    Enum = 21,
    NumberSequence = 23,
    ColorSequence = 25,
    NumberRange = 27,
    Rect = 28,
    Font = 33,
}

local MatricesMap = {
    [0x02] = {
        1, 0, 0,
        0, 1, 0,
        0, 0, 1,
    },
    [0x03] = {
        1, 0, 0,
        0, 0, -1,
        0, 1, 0,
    },
    [0x05] = {
        1, 0,  0,
        0, -1, 0,
        0, 0,  -1,
    },
    [0x06] = {
        1, 0,  0,
        0, 0,  1,
        0, -1, 0,
    },
    [0x07] = {
        0, 1, 0,
        1, 0, 0,
        0, 0, -1,
    },
    [0x09] = {
        0, 0, 1,
        1, 0, 0,
        0, 1, 0,
    },
    [0x0a] = {
        0, -1, 0,
        1, 0,  0,
        0, 0,  1,
    },
    [0x0c] = {
        0, 0,  -1,
        1, 0,  0,
        0, -1, 0,
    },
    [0x0d] = {
        0, 1, 0,
        0, 0, 1,
        1, 0, 0,
    },
    [0x0e] = {
        0, 0, -1,
        0, 1, 0,
        1, 0, 0,
    },
    [0x10] = {
        0, -1, 0,
        0, 0,  -1,
        1, 0,  0,
    },
    [0x11] = {
        0, 0,  1,
        0, -1, 0,
        1, 0,  0,
    },
    [0x14] = {
        -1, 0, 0,
        0,  1, 0,
        0,  0, -1,
    },
    [0x15] = {
        -1, 0, 0,
        0,  0, 1,
        0,  1, 0,
    },
    [0x17] = {
        -1, 0,  0,
        0,  -1, 0,
        0,  0,  1,
    },
    [0x18] = {
        -1, 0,  0,
        0,  0,  -1,
        0,  -1, 0,
    },
    [0x19] = {
        0,  1, 0,
        -1, 0, 0,
        0,  0, 1,
    },
    [0x1b] = {
        0,  0, 1,
        -1, 0, 0,
        0,  1, 0,
    },
    [0x1c] = {
        0,  -1, 0,
        -1, 0,  0,
        0,  0,  -1,
    },
    [0x1e] = {
        0,  0,  -1,
        -1, 0,  0,
        0,  -1, 0,
    },
    [0x1f] = {
        0,  1, 0,
        0,  0, -1,
        -1, 0, 0,
    },
    [0x20] = {
        0,  0, 1,
        0,  1, 0,
        -1, 0, 0,
    },
    [0x22] = {
        0,  -1, 0,
        0,  0,  1,
        -1, 0,  0,
    },
    [0x23] = {
        0,  0,  -1,
        0,  -1, 0,
        -1, 0,  0,
    },
}

local TYPE_DECODER = {
    [VARIENTS.Unknown] = function(stream: BufferStream): any
        error("Unknown Property Type not supported.")
    end,
    [VARIENTS.String] = function(stream: BufferStream): any
        return stream:readstring();
    end,
    [VARIENTS.Bool] = function(stream: BufferStream): any
        return stream:readu8() ~= 0;
    end,
    [VARIENTS.Int] = function(stream: BufferStream): any
        return stream:readi32();
    end,
    [VARIENTS.Float] = function(stream: BufferStream): any
        return stream:readf32();
    end,
    [VARIENTS.Double] = function(stream: BufferStream): any
        return stream:readf64();
    end,
    [VARIENTS.UDim] = function(stream: BufferStream): any
        return datatypes.UDim.Deserialize(stream:readf32(), stream:readi32());
    end,
    [VARIENTS.UDim2] = function(stream: BufferStream): any
        return datatypes.UDim2.Deserialize(stream:readf32(), stream:readi32(), stream:readf32(), stream:readi32());
    end,
    [VARIENTS.BrickColor] = function(stream: BufferStream): any
        return datatypes.BrickColor.Deserialize(stream:readu32());
    end,
    [VARIENTS.Color3] = function(stream: BufferStream): any
        return datatypes.Color3.Deserialize(stream:readf32(), stream:readf32(), stream:readf32(), false);
    end,
    [VARIENTS.Vector2] = function(stream: BufferStream): any
        return datatypes.Vector2.Deserialize(stream:readf32(), stream:readf32());
    end,
    [VARIENTS.Vector3] = function(stream: BufferStream): any
        return datatypes.Vector3.Deserialize(stream:readf32(), stream:readf32(), stream:readf32());
    end,
    [VARIENTS.CFrame] = function(stream: BufferStream): any
        local x = stream:readf32();
        local y = stream:readf32();
        local z = stream:readf32();
        local orient_id = stream:readu8();
        local rotation;
        if (orient_id > 0) then
            rotation = MatricesMap[orient_id] or error("Unknown CFrame Rotation Id");
        else
            rotation = {
                stream:readf32(), stream:readf32(), stream:readf32(),
                stream:readf32(), stream:readf32(), stream:readf32(),
                stream:readf32(), stream:readf32(), stream:readf32(),
            };
        end
        return datatypes.CFrame.Deserialize(x, y, z, unpack(rotation));
    end,
    [VARIENTS.Enum] = function(stream: BufferStream): any
        local enum_type = stream:readstring();
        local value = stream:readu32();
        local enum = datatypes.Enums.DataType[enum_type];
        if (not enum) then
            error(`Unknown Enum type: '{enum_type}'`);
        end
        local items = enum:GetEnumItems();
        return (assert(items[value], `Invalid EnumArrayId: {value} ({enum_type})`));
    end,
    [VARIENTS.ColorSequence] = function(stream: BufferStream): any
        local keys = stream:readu32();
        local points = table.create(keys);
        for j = 1, keys do
            local envelope = stream:readf32();
            local time = stream:readf32();
            local r = stream:readf32();
            local g = stream:readf32();
            local b = stream:readf32();
            points[j] = datatypes.ColorSequenceKeypoint.Deserialize(
                time, datatypes.Color3.Deserialize(r, g, b, false), envelope
            );
        end
        return datatypes.ColorSequence.Deserialize(points);
    end,
    [VARIENTS.NumberRange] = function(stream: BufferStream): any
        return datatypes.NumberRange.Deserialize(stream:readf32(), stream:readf32());
    end,
    [VARIENTS.Rect] = function(stream: BufferStream): any
        return datatypes.Rect.Deserialize(
            stream:readf32(),
            stream:readf32(),
            stream:readf32(),
            stream:readf32()
        );
    end,
    [VARIENTS.NumberSequence] = function(stream: BufferStream): any
        local keys = stream:readu32();
        local points = table.create(keys);
        for j = 1, keys do
            local time = stream:readf32();
            local value = stream:readf32();
            local envelope = stream:readf32();
            points[j] = datatypes.NumberSequenceKeypoint.Deserialize(
                time, value, envelope
            );
        end
        return datatypes.NumberSequence.Deserialize(points);
    end,
    [VARIENTS.Font] = function(stream: BufferStream): any
        local weight = stream:readu16();
        local style = stream:readu8();
        local family = stream:readstring();
        local cache_id = stream:readstring();
        return datatypes.Font.Deserialize(family, weight, style, cache_id);
    end,
};

local TYPE_ENCODER = {
    [VARIENTS.Unknown] = function(stream: BufferStream, value: any): ()
        error("Unknown Property Type not supported.")
    end,
    [VARIENTS.String] = function(stream: BufferStream, value: string): ()
        stream:writestring(value);
    end,
    [VARIENTS.Bool] = function(stream: BufferStream, value: boolean): ()
        stream:writeu8(if (value) then 1 else 0);
    end,
    [VARIENTS.Int] = function(stream: BufferStream, value: number): ()
        stream:writei32(value);
    end,
    [VARIENTS.Float] = function(stream: BufferStream, value: number): ()
        stream:writef32(value);
    end,
    [VARIENTS.Double] = function(stream: BufferStream, value: number): ()
        stream:writef64(value);
    end,
    [VARIENTS.UDim] = function(stream: BufferStream, value: datatypes.UDim): ()
        local scale, offset = datatypes.UDim.Serialize(value);
        stream:writef32(scale);
        stream:writei32(offset);
    end,
    [VARIENTS.UDim2] = function(stream: BufferStream, value: datatypes.UDim2): ()
        local x_scale, x_offset, y_scale, y_offset = datatypes.UDim2.Serialize(value);
        stream:writef32(x_scale);
        stream:writei32(x_offset);
        stream:writef32(y_scale);
        stream:writei32(y_offset);
    end,
    [VARIENTS.BrickColor] = function(stream: BufferStream, value: datatypes.BrickColor): ()
        stream:writeu32(datatypes.BrickColor.Serialize(value));
    end,
    [VARIENTS.Color3] = function(stream: BufferStream, value: datatypes.Color3): ()
        local r, g, b = datatypes.Color3.Serialize(value, false);
        stream:writef32(r);
        stream:writef32(g);
        stream:writef32(b);
    end,
    [VARIENTS.Vector2] = function(stream: BufferStream, value: datatypes.Vector2): ()
        local x, y = datatypes.Vector2.Serialize(value);
        stream:writef32(x);
        stream:writef32(y);
    end,
    [VARIENTS.Vector3] = function(stream: BufferStream, value: datatypes.Vector3): ()
        local x, y, z = datatypes.Vector3.Serialize(value);
        stream:writef32(x);
        stream:writef32(y);
        stream:writef32(z);
    end,
    [VARIENTS.CFrame] = function(stream: BufferStream, value: datatypes.CFrame): ()
        local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = datatypes.CFrame.Serialize(value);
        stream:writef32(x);
        stream:writef32(y);
        stream:writef32(z);

        -- TODO: Implement CFrame Rotation Id
        stream:writeu8(0);

        stream:writef32(r00); stream:writef32(r01); stream:writef32(r02);
        stream:writef32(r10); stream:writef32(r11); stream:writef32(r12);
        stream:writef32(r20); stream:writef32(r21); stream:writef32(r22);
    end,
    [VARIENTS.Enum] = function(stream: BufferStream, value: datatypes.EnumItem): ()
        stream:writestring(value.EnumType["@name"]);
        stream:writeu32(value.Value);
    end,
    [VARIENTS.ColorSequence] = function(stream: BufferStream, value: datatypes.ColorSequence): ()
        local points = datatypes.ColorSequence.Serialize(value);
        stream:expandToSize(stream.position + (#points * 20) + 4) -- preallocate
        stream:writeu32(#points);
        for _, point in points do
            local time, color, envelope = datatypes.ColorSequenceKeypoint.Serialize(point);
            local r, g, b = datatypes.Color3.Serialize(color, false);
            stream:writef32(envelope);
            stream:writef32(time);
            stream:writef32(r);
            stream:writef32(g);
            stream:writef32(b);
        end
    end,
    [VARIENTS.NumberRange] = function(stream: BufferStream, value: datatypes.NumberRange): ()
        local min, max = datatypes.NumberRange.Serialize(value);
        stream:writef32(min);
        stream:writef32(max);
    end,
    [VARIENTS.Rect] = function(stream: BufferStream, value: datatypes.Rect): ()
        local x0, y0, x1, y1 = datatypes.Rect.Serialize(value);
        stream:writef32(x0);
        stream:writef32(y0);
        stream:writef32(x1);
        stream:writef32(y1);
    end,
    [VARIENTS.NumberSequence] = function(stream: BufferStream, value: datatypes.NumberSequence): ()
        local points = datatypes.NumberSequence.Serialize(value);
        stream:expandToSize(stream.position + (#points * 12) + 4) -- preallocate
        stream:writeu32(#points);
        for _, point in points do
            local time, nvalue, envelope = datatypes.NumberSequenceKeypoint.Serialize(point);
            stream:writef32(time);
            stream:writef32(nvalue);
            stream:writef32(envelope);
        end
    end,
    [VARIENTS.Font] = function(stream: BufferStream, value: datatypes.Font): ()
        local weight = stream:readu16();
        local style = stream:readu8();
        local family = stream:readstring();
        local cache_id = stream:readstring();
        return datatypes.Font.Deserialize(family, weight, style, cache_id);
    end,
};

local function decodeAttributes(value: string): {[string]: any}
    local stream = Stream.fromBuffer(buffer.fromstring(value));
    if (not stream:couldRead(4)) then
        return {};
    end
    local len = stream:readu32();
    local attributes = {};
    for i = 1, len do
        local key = stream:readstring();
        if (not validateAttributeKey(key)) then
            error(`Attribute Name: "{key}" contains illegal characters`);
        end
        local type_id = stream:readu8();
        local decoder = TYPE_DECODER[type_id];
        if (not decoder) then
            error(`Unknown Attribute Value Type: ({type_id}) for key '{key}'`);
        end
        attributes[key] = {
            type = type_id,
            value = decoder(stream),
        };
    end
    return attributes;
end

local function encodeAttributes(attributes: {[string]: any}): string
    local stream = Stream.new(4);
    stream:writeu32(size(attributes));
    for key, value in attributes do
        stream:writestring(key);
        stream:writeu8(value.type);
        local encoder = TYPE_ENCODER[value.type];
        if (not encoder) then
            error(`Failed to Encode Attribute Value Type: ({value.type}) for key '{key}'`);
        end
        encoder(stream, value.value);
    end
    stream:trim();
    return buffer.tostring(stream.buffer);
end

local DATATYPE_MAP: {[any]: number} = {
    [datatypes.UDim.DataType] = VARIENTS.UDim,
    [datatypes.UDim2.DataType] = VARIENTS.UDim2,
    [datatypes.BrickColor.DataType] = VARIENTS.BrickColor,
    [datatypes.Color3.DataType] = VARIENTS.Color3,
    [datatypes.Vector2.DataType] = VARIENTS.Vector2,
    [datatypes.Vector3.DataType] = VARIENTS.Vector3,
    [datatypes.CFrame.DataType] = VARIENTS.CFrame,
    [datatypes.EnumItem.DataType] = VARIENTS.Enum,
    [datatypes.NumberSequence.DataType] = VARIENTS.NumberSequence,
    [datatypes.ColorSequence.DataType] = VARIENTS.ColorSequence,
    [datatypes.NumberRange.DataType] = VARIENTS.NumberRange,
    [datatypes.Rect.DataType] = VARIENTS.Rect,
    [datatypes.Font.DataType] = VARIENTS.Font,
};

local function getTypeIdOf(value: any): number
    if (typeof(value) == "string") then
        return VARIENTS.String;
    elseif (typeof(value) == "boolean") then
        return VARIENTS.Bool;
    elseif (typeof(value) == "number") then
        local min, max = -3.402823e+38, 3.402823e+38;
        if (value >= min and value <= max) then
            return VARIENTS.Float;
        end
        return VARIENTS.Double;
    elseif (typeof(value) == "table" or typeof(value) == "userdata") then
        local type_id = DATATYPE_MAP[getmetatable(value)];
        if (type_id) then
            return type_id;
        end
    end
    error(`Unknown Attribute Value Type: ({typeof(value)})`);
end

return {
    getTypeIdOf = getTypeIdOf,
    decodeAttributes = decodeAttributes,
    validateAttributeKey = validateAttributeKey,
    encodeAttributes = encodeAttributes,
}
