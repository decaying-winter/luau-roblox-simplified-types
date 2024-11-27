--!strict
local serde = zune.serde;
local crypto = zune.crypto;

local bit64 = require("../lib/bit64");

local BinaryMagicHeader = "<roblox!\x89\xff\x0d\x0a\x1a\x0a";

local BinaryChunkType = {
    INST = 0,
    PROP = 1,
    PRNT = 2,
    META = 3,
    SSTR = 4,
    SIGN = 5,
    END = 6,
};

local RobloxPropertyType = {
    Unknown = 0,
    String = 1,
    Bool = 2,
    Int = 3,
    Float = 4,
    Double = 5,
    UDim = 6,
    UDim2 = 7,
    Ray = 8,
    Faces = 9,
    Axes = 10,
    BrickColor = 11,
    Color3 = 12,
    Vector2 = 13,
    Vector3 = 14,
    -- Padded
    CFrame = 16,
    Quaternion = 17,
    Enum = 18,
    Ref = 19,
    Vector3int16 = 20,
    NumberSequence = 21,
    ColorSequence = 22,
    NumberRange = 23,
    Rect = 24,
    PhysicalProperties = 25,
    Color3uint8 = 26,
    Int64 = 27,
    SharedString = 28,
    ProtectedString = 29,
    OptionalCFrame = 30,
    UniqueId = 31,
    FontFace = 32,
    SecurityCapabilities = 33,
}

local BinaryChunkTypeMap = {
    ["INST"] = BinaryChunkType.INST,
    ["PROP"] = BinaryChunkType.PROP,
    ["PRNT"] = BinaryChunkType.PRNT,
    ["META"] = BinaryChunkType.META,
    ["SSTR"] = BinaryChunkType.SSTR,
    ["SIGN"] = BinaryChunkType.SIGN,
    ["END\0"] = BinaryChunkType.END,
}

export type ChunkInfo = {
    type: number,
    data: buffer,
    reserved: number,
    size: number,
};

export type DocumentInfo = {
    version: number,
    classes: number,
    instances: number,
    reserved: number,
};

export type Class = {
    index: number,
    name: string,
    isService: boolean,
    instances: {number},
};

export type Property = {
    type: number,
    value: any,
}

export type Instance = {
    className: string,
    referent: number,
    parent: number?,
    properties: {[string]: Property},
    isService: boolean,
};

export type Signature = {
    Type: "Ed25519",
    PublicKey: number,
    Value: string,
};

export type SharedString = {
    Lookup: {[string]: string},
    Key: string,
}

export type Document = {
    info: DocumentInfo,
    instances: {Instance},
    classes: {Class},
    metadata: {[string]: string},
    sharedstrings: {SharedString},
    signatures: {Signature}?,
};

local BinaryChunkTypeNameMap = {}
for name: string, value: number in BinaryChunkTypeMap::{[string]: number} do
    BinaryChunkTypeNameMap[value] = name:gsub('\0', '');
end

local RobloxPropertyTypeNameMap = {}
for name: string, value: number in RobloxPropertyType::{[string]: number} do
    RobloxPropertyTypeNameMap[value] = name;
end

local function getBinaryChunkTypeName(type: number): string?
    return BinaryChunkTypeNameMap[type];
end

local function getPropertyTypeName(type: number): string?
    return RobloxPropertyTypeNameMap[type];
end

local function rotatei32(b: buffer): number
    local be = buffer.fromstring(buffer.readstring(b, 0, 4):reverse());
    local value = buffer.readi32(be, 0);
    value = bit32.bxor(bit32.arshift(value, 1), -bit32.band(value, 1));
    buffer.writeu32(be, 0, value);
    return buffer.readi32(be, 0);
end

local function tou32(b: buffer): number
    return buffer.readu32(
        buffer.fromstring(buffer.readstring(b, 0, 4):reverse()),
        0
    );
end

local function rotatei64(b: buffer): buffer
    local be = buffer.fromstring(buffer.readstring(b, 0, 8):reverse());
    local n = bit64.join(buffer.readi32(be, 0), buffer.readi32(be, 4));

    local value = bit64.bxor(bit64.rshift(n, 1), -(bit64.band(n, 1)));

    local high, low = bit64.split(value);
    buffer.writei32(be, 0, high);
    buffer.writei32(be, 4, low);
    return be;
end

local function tou64(b: buffer): buffer
    return buffer.fromstring(
        buffer.readstring(b, 0, 8):reverse()
    );
end

local function rotatef32(b: buffer): number
    local be = buffer.fromstring(buffer.readstring(b, 0, 4):reverse());
    local value = buffer.readu32(be, 0);
    buffer.writei32(be, 0, bit32.bor(bit32.arshift(value, 1), bit32.lshift(value, 31)));
    return buffer.readf32(be, 0);
end

local function ReadInterleaved<T>(b: buffer, offset: number, count: number, size: number, transform: (b: buffer) -> T): {T}
    if (buffer.len(b) - offset < count * size) then
        error("Too small");
    end
    local list = table.create(count);
    for i = 1, count do
        local bytes = buffer.create(size);
        for j = 0, size - 1 do
            buffer.writeu8(bytes, j, buffer.readu8(b, offset + ((j * count) + i - 1)))
        end
        list[i] = transform(bytes);
    end
    return list;
end

local function ReadInterleavedi32(b: buffer, offset: number, count: number): {number}
    return ReadInterleaved(b, offset, count, 4, rotatei32);
end
local function ReadInterleavedu32(b: buffer, offset: number, count: number): {number}
    return ReadInterleaved(b, offset, count, 4, tou32);
end

local function ReadInterleavedi64(b: buffer, offset: number, count: number): {buffer}
    return ReadInterleaved(b, offset, count, 8, rotatei64);
end
local function ReadInterleavedu64(b: buffer, offset: number, count: number): {buffer}
    return ReadInterleaved(b, offset, count, 8, tou64);
end

local function ReadInterleavedf32(b: buffer, offset: number, count: number): {number}
    return ReadInterleaved(b, offset, count, 4, rotatef32);
end

local function ReadInstances(buffer: buffer, offset: number, count: number): {number}
    local values = ReadInterleavedi32(buffer, offset, count);
    for i = 2, count do
        values[i] += values[i - 1];
    end
    return values;
end

local function readChunk(slice: buffer, slice_pos: number)
    local pos = slice_pos;
    if (buffer.len(slice) - pos < 16) then
        error("Too small");
    end

    local chunk_type = BinaryChunkTypeMap[buffer.readstring(slice, pos, 4)];
    assert(chunk_type, "Invalid chunk type");
    pos += 4;
    local compressed_size = buffer.readu32(slice, pos);
    pos += 4;
    local size = buffer.readu32(slice, pos);
    pos += 4;
    local reserved = buffer.readu32(slice, pos);
    pos += 4;

    local data: buffer = nil;
    if (compressed_size > 0) then
        local compressed_start = pos;
        pos += compressed_size;
        local byte = buffer.readu8(slice, compressed_start);
        if (byte == 0x58 or byte == 0x78) then
            print("zlib");
            data = buffer.fromstring(
                serde.zlib.decompress(
                    buffer.readstring(slice, compressed_start, compressed_size)
                )
            );
        elseif (buffer.readstring(slice, compressed_start + 1, 3) == "\xB5\x2F\xFD") then
            print("zstd ");
            error("not supported yet")
        else
            data = buffer.fromstring(
                serde.lz4.decompress(
                    buffer.readstring(slice, compressed_start, compressed_size),
                    size
                )
            );
        end
    else
        data = buffer.fromstring(buffer.readstring(slice, pos, size));
        pos += size;
    end

    local chunk: ChunkInfo = {
        type = chunk_type,
        data = data,
        reserved = reserved,
        size = size,
    };

    return chunk, pos;
end

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

local function cframeDeserializer(type: number, values: {any}, len: number, chunk: ChunkInfo, pos: number)
    local data = chunk.data;
    if (type == RobloxPropertyType.OptionalCFrame) then
        local byte = buffer.readu8(data, pos);
        pos += 1;
        if (byte ~= RobloxPropertyType.CFrame) then
            for i = 1, len do
                values[i] = { OptionalCFrame = nil };
            end
            return;
        end
    end
    local matrices = table.create(len);
    for i = 1, len do
        local orient_id = buffer.readu8(data, pos);
        pos += 1;
        if (orient_id > 0) then
            local matrix = MatricesMap[orient_id] or error("Unknown CFrame Rotation Id");
            matrices[i] = matrix;
        elseif (type == RobloxPropertyType.Quaternion) then
            local qx = buffer.readf32(data, pos);
            pos += 4;
            local qy = buffer.readf32(data, pos);
            pos += 4;
            local qz = buffer.readf32(data, pos);
            pos += 4;
            local qw = buffer.readf32(data, pos);
            pos += 4;

            local xc = qx * 2;
            local yc = qy * 2;
            local zc = qz * 2;

            local xx = qx * xc;
            local xy = qx * yc;
            local xz = qx * zc;

            local wx = qw * xc;
            local wy = qw * yc;
            local wz = qw * zc;

            local yy = qy * yc;
            local yz = qy * zc;
            local zz = qz * zc;

            matrices[i] = {
                1 - (yy + zz), xy - wz, xz + wy,
                xy + wx, 1 - (xx + zz), yz - wx,
                xz - wy, yz + wx, 1 - (xx + yy),
            };
        else
            local matrix = table.create(9);
            for j = 1, 9 do
                matrix[j] = buffer.readf32(data, pos);
                pos += 4;
            end
            matrices[i] = matrix;
        end
    end
    local step = len * 4;
    local cxs = ReadInterleavedf32(data, pos, len);
    pos += step;
    local cys = ReadInterleavedf32(data, pos, len);
    pos += step;
    local czs = ReadInterleavedf32(data, pos, len);
    pos += step;

    local cframes = table.create(len);
    for i = 1, len do
        cframes[i] = {
            cxs[i], cys[i], czs[i],
            unpack(matrices[i])
        }
    end

    if (type == RobloxPropertyType.OptionalCFrame) then
        local byte = buffer.readu8(data, pos);
        pos += 1;
        if (byte ~= RobloxPropertyType.Bool) then
            for i = 1, len do
                values[i] = { OptionalCFrame = cframes[i] };
            end
        else
            for i = 1, len do
                local exists = buffer.readu8(data, pos) ~= 0;
                pos += 1;
                if (not exists) then
                    values[i] = { OptionalCFrame = nil };
                    continue;
                end
                values[i] = cframes[i];
            end
        end
    else
        for i = 1, len do
            values[i] = cframes[i];
        end
    end
end

local PropertyDeserializerMap = {
    [RobloxPropertyType.Unknown] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        error("Unknown Property Type not supported.")
    end,
    [RobloxPropertyType.String] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local str_len = buffer.readu32(data, pos);
            pos += 4;
            values[i] = buffer.readstring(data, pos, str_len);
            pos += str_len;
        end
    end,
    [RobloxPropertyType.Bool] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            values[i] = buffer.readu8(data, pos) ~= 0;
            pos += 1;
        end
    end,
    [RobloxPropertyType.Int] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local list = ReadInterleavedi32(chunk.data, pos, len);
        for i = 1, len do
            values[i] = list[i];
        end
    end,
    [RobloxPropertyType.Float] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local list = ReadInterleavedf32(chunk.data, pos, len);
        for i = 1, len do
            values[i] = list[i];
        end
    end,
    [RobloxPropertyType.Double] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            values[i] = buffer.readf64(data, pos + i - 1)
        end
    end,
    [RobloxPropertyType.UDim] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local step = len * 4;
        local scales = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local offsets = ReadInterleavedi32(chunk.data, pos, len);
        pos += step;
        for i = 1, len do
            values[i] = { Scale = scales[i], Offset = offsets[i] };
        end
    end,
    [RobloxPropertyType.UDim2] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local step = len * 4;
        local scales_x = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local scales_y = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local offsets_x = ReadInterleavedi32(chunk.data, pos, len);
        pos += step;
        local offsets_y = ReadInterleavedi32(chunk.data, pos, len);
        pos += step;
        for i = 1, len do
            values[i] = {
                X = { Scale = scales_x[i], Offset = offsets_x[i] },
                Y = { Scale = scales_y[i], Offset = offsets_y[i] },
            };
        end
    end,
    [RobloxPropertyType.Ray] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local pos_x = buffer.readf32(data, pos);
            pos += 4;
            local pos_y = buffer.readf32(data, pos);
            pos += 4;
            local pos_z = buffer.readf32(data, pos);
            pos += 4;
            local dir_x = buffer.readf32(data, pos);
            pos += 4;
            local dir_y = buffer.readf32(data, pos);
            pos += 4;
            local dir_z = buffer.readf32(data, pos);
            pos += 4;
            values[i] = { pos_x, pos_y, pos_z, dir_x, dir_y, dir_z };
        end
    end,
    [RobloxPropertyType.Faces] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            values[i] = buffer.readu8(data, pos + i - 1);
        end
    end,
    [RobloxPropertyType.Axes] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            values[i] = buffer.readu8(data, pos + i - 1);
        end
    end,
    [RobloxPropertyType.BrickColor] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local list = ReadInterleavedi32(chunk.data, pos, len);
        for i = 1, len do
            values[i] = list[i];
        end
    end,
    [RobloxPropertyType.Color3] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local step = len * 4;
        local rs = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local gs = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local bs = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        for i = 1, len do
            values[i] = { rs[i], gs[i], bs[i] };
        end
    end,
    [RobloxPropertyType.Vector2] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local step = len * 4;
        local xs = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local ys = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        for i = 1, len do
            values[i] = { xs[i], ys[i] };
        end
    end,
    [RobloxPropertyType.Vector3] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local step = len * 4;
        local xs = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local ys = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local zs = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        for i = 1, len do
            values[i] = vector.create(xs[i], ys[i], zs[i]);
        end
    end,
    [RobloxPropertyType.CFrame] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        cframeDeserializer(RobloxPropertyType.CFrame, values, len, chunk, pos);
    end,
    [RobloxPropertyType.Quaternion] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        cframeDeserializer(RobloxPropertyType.Quaternion, values, len, chunk, pos);
    end,
    [RobloxPropertyType.Enum] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local list = ReadInterleavedu32(chunk.data, pos, len);
        for i = 1, len do
            values[i] = list[i];
        end
    end,
    [RobloxPropertyType.Ref] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local list = ReadInstances(chunk.data, pos, len);
        for i = 1, len do
            values[i] = if (list[i] > 0) then list[i] else nil;
        end
    end,
    [RobloxPropertyType.Vector3int16] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local x = buffer.readi16(data, pos);
            pos += 2;
            local y = buffer.readi16(data, pos);
            pos += 2;
            local z = buffer.readi16(data, pos);
            pos += 2;
            values[i] = { x, y, z };
        end
    end,
    [RobloxPropertyType.NumberSequence] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local keys = buffer.readu32(data, pos);
            pos += 4;
            local points = table.create(keys);
            for j = 1, keys do
                local time = buffer.readf32(data, pos);
                pos += 4;
                local value = buffer.readf32(data, pos);
                pos += 4;
                local envelope = buffer.readf32(data, pos);
                pos += 4;
                points[j] = { Time = time, Value = value, Envelope = envelope };
            end
            values[i] = points;
        end
    end,
    [RobloxPropertyType.ColorSequence] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local keys = buffer.readu32(data, pos);
            pos += 4;
            local points = table.create(keys);
            for j = 1, keys do
                local time = buffer.readf32(data, pos);
                pos += 4;
                local r = buffer.readf32(data, pos);
                pos += 4;
                local g = buffer.readf32(data, pos);
                pos += 4;
                local b = buffer.readf32(data, pos);
                pos += 4;
                local envelope = buffer.readf32(data, pos);
                pos += 4;
                points[j] = { Time = time, Value = { r, g, b }, Envelope = envelope };
            end
            values[i] = points;
        end
    end,
    [RobloxPropertyType.NumberRange] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local min = buffer.readf32(data, pos);
            pos += 4;
            local max = buffer.readf32(data, pos);
            pos += 4;
            values[i] = {Min = min, Max = max};
        end
    end,
    [RobloxPropertyType.Rect] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local step = len * 4;
        local x0s = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local y0s = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local x1s = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        local y1s = ReadInterleavedf32(chunk.data, pos, len);
        pos += step;
        for i = 1, len do
            values[i] = { x0s[i], y0s[i], x1s[i], y1s[i] };
        end
    end,
    [RobloxPropertyType.PhysicalProperties] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local exists = buffer.readu8(data, pos) ~= 0;
            pos += 1;
            local value = nil;
            if (exists) then
                local density = buffer.readf32(data, pos);
                pos += 4;
                local friction = buffer.readf32(data, pos);
                pos += 4;
                local elasticity = buffer.readf32(data, pos);
                pos += 4;
                local friction_weight = buffer.readf32(data, pos);
                pos += 4;
                local elasticity_weight = buffer.readf32(data, pos);
                pos += 4;
                value = {
                    Density = density,
                    Friction = friction,
                    Elasticity = elasticity,
                    FrictionWeight = friction_weight,
                    ElasticityWeight = elasticity_weight,
                };
            end
            values[i] = value;
        end
    end,
    [RobloxPropertyType.Color3uint8] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local twice = (len * 2);
        for i = 0, len - 1 do
            local r = buffer.readu8(chunk.data, pos + i);
            local g = buffer.readu8(chunk.data, pos + len + i);
            local b = buffer.readu8(chunk.data, pos + twice + i);
            values[i + 1] = { r, g, b };
        end
    end,
    [RobloxPropertyType.Int64] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local list = ReadInterleavedi64(chunk.data, pos, len);
        for i = 1, len do
            values[i] = list[i];
        end
    end,
    [RobloxPropertyType.SharedString] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local keys = ReadInterleavedu32(chunk.data, pos, len);
        for i = 1, len do
            values[i] = keys[i];
        end
    end,
    [RobloxPropertyType.ProtectedString] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local size = buffer.readu32(data, pos);
            pos += 4;
            local value = buffer.create(size);
            buffer.copy(value, 0, data, pos, size);
            values[i] = value;
        end
    end,
    [RobloxPropertyType.OptionalCFrame] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        cframeDeserializer(RobloxPropertyType.OptionalCFrame, values, len, chunk, pos);
    end,
    [RobloxPropertyType.UniqueId] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local ids = ReadInterleaved(chunk.data, pos, len, 16, function(b: buffer)
            local random = buffer.create(8);
            buffer.copy(random, 0, b, 8, 8);
            return {
                index = buffer.readu32(b, 0),
                time = buffer.readu32(b, 4),
                random = random,
            }
        end)
        for i = 1, len do
            values[i] = ids[i];
        end
    end,
    [RobloxPropertyType.FontFace] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local data = chunk.data;
        for i = 1, len do
            local family_size = buffer.readu32(data, pos);
            pos += 4;
            local family = buffer.readstring(data, pos, family_size);
            pos += family_size;
            local weight = buffer.readu16(data, pos);
            pos += 2;
            local style = buffer.readu8(data, pos);
            pos += 1;
            local cache_size = buffer.readu32(data, pos);
            pos += 4;
            local cache_id = buffer.readstring(data, pos, cache_size);
            pos += cache_size;
            values[i] = { Family = family, Weight = weight, Style = style, CacheId = cache_id };
        end
    end,
    [RobloxPropertyType.SecurityCapabilities] = function(values: {any}, len: number, chunk: ChunkInfo, pos: number)
        local capabilities = ReadInterleavedu64(chunk.data, pos, len);
        for i = 1, len do
            values[i] = capabilities[i];
        end
    end,
}

local DeserializerMap = {
    [BinaryChunkType.INST] = function(document: Document, chunk: ChunkInfo)
        local pos = 0;
        local data = chunk.data;

        local class_index = buffer.readu32(data, pos);
        pos += 4;
        local class_name_len = buffer.readu32(data, pos);
        pos += 4;
        local class_name = buffer.readstring(data, pos, class_name_len);
        pos += class_name_len;
        local is_service = buffer.readu8(data, pos) ~= 0;
        pos += 1;
        local instances_len = buffer.readu32(data, pos);
        pos += 4;

        local instances = ReadInstances(data, pos, instances_len);

        for i = 1, instances_len do
            local id = instances[i];
            local inst: Instance = {
                referent = id,
                className = class_name,
                isService = is_service,
                properties = {},
            };
            if (is_service) then
                pos += 1;
            end
            document.instances[id  + 1] = inst;
        end

        document.classes[class_index] = {
            index = class_index,
            instances = instances,
            name = class_name,
            isService = is_service,
        };

        return false;
    end,
    [BinaryChunkType.PROP] = function(document: Document, chunk: ChunkInfo)
        local pos = 0;
        local data = chunk.data;
        local class_index = buffer.readu32(data, pos);
        pos += 4;
        local name_len = buffer.readu32(data, pos);
        pos += 4;
        local name = buffer.readstring(data, pos, name_len);
        pos += name_len;

        local class = document.classes[class_index];
        assert(class, "Deserializer property class not found: " .. name);

        local type_byte = buffer.readu8(data, pos);
        pos += 1;

        local length = #class.instances;
        local values = table.create(length);

        local deserializer = PropertyDeserializerMap[type_byte];
        assert(deserializer, "Unsupported Property type: " .. (getPropertyTypeName(type_byte) or "?"));

        deserializer(values, length, chunk, pos);

        for i = 1, length do
            local id = class.instances[i];
            local instance = document.instances[id + 1];
            local value = values[i];
            instance.properties[name] = value;
        end

        return false;
    end,
    [BinaryChunkType.PRNT] = function(document: Document, chunk: ChunkInfo)
        local pos = 0;
        local data = chunk.data;

        local format = buffer.readu8(data, pos);
        pos += 1;
        local count = buffer.readu32(data, pos);
        pos += 4;

        if (format ~= 0) then
            error("Unsupported PRNT format: " .. format);
        end

        local step = count * 4;
        local childs = ReadInstances(data, pos, count);
        pos += step;
        local parents = ReadInstances(data, pos, count);
        pos += step;

        for i = 1, count do
            local child_id = childs[i];
            local parent_id = parents[i];
            if (parent_id >= 0) then
                document.instances[child_id + 1].parent = parent_id;
            end
        end

        return false;
    end,
    [BinaryChunkType.SSTR] = function(document: Document, chunk: ChunkInfo)
        local pos = 0;
        local data = chunk.data;
        local format = buffer.readi32(data, pos);
        pos += 4;
        local hash_len = buffer.readu32(data, pos);
        pos += 4;

        if (format ~= 0) then
            error("Bad SharedString format");
        end

        for i = 1, hash_len do
            pos += 16;
            local data_len = buffer.readu32(data, pos);
            pos += 4;
            local key = buffer.readstring(data, pos, data_len);
            pos += data_len;
            local hash = crypto.hash.blake2.b128(key);
            local hash_base64 = serde.base64.encode(hash);
            local lookup = {
                [hash_base64] = key,
            };
            table.insert(document.sharedstrings, {
                Lookup = lookup,
                Key = hash_base64,
            });
        end
        return false;
    end,
    [BinaryChunkType.END] = function(document: Document, chunk: ChunkInfo)
        return true;
    end,
};

local function deserialize(slice: buffer, slice_pos: number): Document
    local pos = slice_pos;
    if (buffer.len(slice) - pos < 18) then
        error("Bad Chunk");
    end

    local version = buffer.readu16(slice, pos);
    pos += 2;
    local classes = buffer.readu32(slice, pos);
    pos += 4;
    local instances = buffer.readu32(slice, pos);
    pos += 4;
    local reserved = 0; -- 8 bytes
    pos += 8;

    local document: Document = {
        info = {
            version = version,
            instances = instances,
            classes = classes,
            reserved = reserved,
        },
        classes = table.create(classes),
        instances = table.create(instances),
        sharedstrings = {},
        metadata = {},
        signatures = nil,
    }

    while (true) do
        local chunk, new_pos = readChunk(slice, pos);

        pos = new_pos;

        local deserializer = DeserializerMap[chunk.type];
        assert(deserializer, "Unsupported chunk type: ".. (getBinaryChunkTypeName(chunk.type) or "?"))
        if (deserializer(document, chunk)) then
            break;
        end
    end

    return document;
end

if zune.testing.running then
    local fs = zune.fs
    local testing = zune.testing

    local test = testing.test

    test("deserialize baseplate 566", function()
        local buf = fs.readFile("./rbx-test-files/places/baseplate-566/binary.rbxl", true);
        assert(buffer.readstring(buf, 0, 14) == BinaryMagicHeader, "Mismatch")
        local start = os.clock();
        local doc = deserialize(buf, 14);
        print(doc)
        local endt = os.clock();
        print(`Completed in {endt - start} seconds`)
    end)
end

return {
    deserialize = deserialize;
    serialize = nil;
};
