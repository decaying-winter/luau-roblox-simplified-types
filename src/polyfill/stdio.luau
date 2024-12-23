--!strict
--!native
--!optimize 2
if (type(_VERSION) == "string") then
    if (string.sub(_VERSION, 1, 4) == "Zune") then
        return zune.stdio;
    elseif (string.sub(_VERSION, 1, 4) == "Lune") then
        local stdio = require("@lune/stdio")::any;
        return {
            color = function(name: string)
                return stdio.color(name);
            end,
            style = function(style: string)
                return stdio.style(style);
            end,
            reset = function(_: string?)
                return stdio.style("reset");
            end,
        }::any;
    end
end

local COLORS = {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
}

local STYLES = {
    reset = 0,
    bold = 1,
    underline = 4,
    blink = 5,
    reverse = 7,
    hidden = 8,
}

return {
    color = function(name: string)
        assert(COLORS[name], "Unknown color");
        return `\x1b[{COLORS[name]}m`
    end,
    style = function(kind: string)
        assert(STYLES[kind], "Unknown style");
        return `\x1b[{STYLES[kind]}m`
    end,
    reset = function(kind: string?)
        return `\x1b[0m`;
    end,
}::any;
