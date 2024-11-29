--!strict
local serde = zune.serde;

local dump = require("./generated");

local api_dump: dump.ApiDump = serde.json.decode(dump.DumpJson);

local ReflectionDatabase = {};

export type ReflectionDatabase = typeof(ReflectionDatabase);

function ReflectionDatabase.GetApiDump(self: ReflectionDatabase)
    return api_dump;
end

function ReflectionDatabase.GetClassNames(self: ReflectionDatabase): {string}
    local names = table.create(#api_dump.Classes);
    for _, class in api_dump.Classes do
        table.insert(names, class.Name);
    end
    return names;
end

function ReflectionDatabase.GetEnumNames(self: ReflectionDatabase): {string}
    local names = table.create(#api_dump.Enums);
    for _, enum in api_dump.Enums do
        table.insert(names, enum.Name);
    end
    return names;
end

function ReflectionDatabase.GetClass(self: ReflectionDatabase, name: string): dump.ClassInfo?
    for _, class in api_dump.Classes do
        if (class.Name == name) then
            return class;
        end
    end
    return;
end

function ReflectionDatabase.GetEnum(self: ReflectionDatabase, name: string): dump.EnumInfo?
    for _, enum in api_dump.Enums do
        if (enum.Name == name) then
            return enum;
        end
    end
    return;
end

function ReflectionDatabase.FindClass(self: ReflectionDatabase, name: string): dump.ClassInfo?
    name = name:lower();
    for _, class in api_dump.Classes do
        if (class.Name:lower() == name) then
            return class;
        end
    end
    return;
end

function ReflectionDatabase.FindEnum(self: ReflectionDatabase, name: string): dump.EnumInfo?
    name = name:lower();
    for _, enum in api_dump.Enums do
        if (enum.Name:lower() == name) then
            return enum;
        end
    end
    return;
end

return ReflectionDatabase;
