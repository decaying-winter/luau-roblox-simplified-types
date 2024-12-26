--!strict
--!native
--!optimize 2
if (type(_VERSION) == "string") then
    if (string.sub(_VERSION, 1, 4) == "Zune") then
        return zune.crypto.hash.blake2;
    end
end

local md5 = require("./md5");

-- TODO: replace md5 with blake2 b128
return {
    b128 = md5,
}::any;
