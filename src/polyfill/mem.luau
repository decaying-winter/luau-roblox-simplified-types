--!strict
--!native
--!optimize 2

local mem = {};

function mem.reverse(buf: buffer, position: number, count: number)
    local half = count // 2;
    local m1 = count - 1;
    for i = 0, half - 1 do
        local a = position + i
        local b = position + m1 - i
        local temp_a = buffer.readu8(buf, a);
        local temp_b = buffer.readu8(buf, b);
        buffer.writeu8(buf, a, temp_b);
        buffer.writeu8(buf, b, temp_a);
    end
end

return mem;
