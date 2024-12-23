--!strict
--!native
--!optimize 2
if (type(_VERSION) == "string") then
    if (string.sub(_VERSION, 1, 4) == "Zune") then
        return zune.crypto.hash.blake2;
    end
end

return {
    b128 = function(...)
        error("Not implemented")
    end::any,
}::any;
