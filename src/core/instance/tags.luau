--!strict

local Stream = require("../../dom/binary/stream");

type BufferStream = Stream.BufferStream;

local function decodeTags(value: string): {string}
    return value:split("\0");
end

local function encodeTags(value: {string}): string
    local count = #value;
    if (count == 0) then
        return "";
    end
    local size = count - 1;
    for _, tag in value do
        size += #tag;
    end
    local stream = Stream.new(size);
    for i, tag in value do
        stream:writerawstring(tag);
        if (i == count) then
            break;
        end
        stream:writeu8(0);
    end
    return buffer.tostring(stream.buffer);
end

return {
    decodeTags = decodeTags,
    encodeTags = encodeTags,
}
