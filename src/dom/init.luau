--!strict
local roblox = require("./roblox");
local binary = require("./binary");

local BINARY_HEADER_LEN = #binary.header;

local dom = {};

function dom.deserialize(data: string | buffer): roblox.Document
    if (type(data) == "string") then
        data = buffer.fromstring(data);
    end
    assert(type(data) == "buffer", "Internal DOM Error");

    if (
        buffer.len(data) > BINARY_HEADER_LEN
        and buffer.readstring(data, 0, BINARY_HEADER_LEN) == binary.header
    ) then
        -- Binary
        return binary.deserialize(data, BINARY_HEADER_LEN);
    else
        -- XML
        error("Not implemented");
    end
end

function dom.serialize(document: roblox.Document, format: ("XML" | "BINARY")?): string
    format = format or "BINARY";
    if (format == "BINARY") then
        local buf = binary.serialize(document);
        return buffer.tostring(buf);
    else
        error("Not implemented");
    end
end

return dom;
