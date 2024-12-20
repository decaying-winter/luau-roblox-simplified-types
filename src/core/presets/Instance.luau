--!strict
local impl = {};
impl.object = nil::any;
impl.default = {};
impl.method = {};
impl.property = {};
impl.property.get = {};
impl.property.set = {};

function impl.default.Archivable(self: any): boolean
    return true;
end

function impl.method.GetFullName(self: any): string
    local name = self.Name;
    if (not name) then
        return "";
    end
    local parent = rawget(self, "@parent");
    if (not parent) then
        return name;
    end
    return `{parent:GetFullName()}.{name}`;
end

function impl.method.GetChildren(self: any): {any}
    return table.clone(self["@children"]);
end

function impl.method.FindFirstChild(self: any, name: string): any?
    for _, child in self["@children"] do
        if (child.Name == name) then
            return child;
        end
    end
    return nil;
end

function impl.method.FindFirstChildOfClass(self: any, className: string): any?
    for _, child in self["@children"] do
        if (child["@instance"].className == className) then
            return child;
        end
    end
    return nil;
end

function impl.method.FindFirstAncestor(self: any, name: string): any?
    local parent = rawget(self, "@parent");
    while (parent) do
        if (parent.Name == name) then
            return parent;
        end
        parent = rawget(parent, "@parent");
    end
    return;
end

function impl.method.FindFirstAncestorOfClass(self: any, className: string): any?
    local parent = rawget(self, "@parent");
    while (parent) do
        if (parent["@instance"].className == className) then
            return parent;
        end
        parent = rawget(parent, "@parent");
    end
    return;
end

function impl.method.FindFirstAncestorWhichIsA(self: any, className: string): any?
    local parent = rawget(self, "@parent");
    while (parent) do
        if (parent:IsA(className)) then
            return parent;
        end
        parent = rawget(parent, "@parent");
    end
    return;
end

local function applyChilds(instance: any, descendants: {any})
    for _, child in instance["@children"] do
        table.insert(descendants, child);
        applyChilds(child, descendants);
    end
end
function impl.method.GetDescendants(self: any): {any}
    local descendants = {};
    applyChilds(self, descendants);
    return table.clone(descendants);
end

function impl.method.IsDescendantOf(self: any, ancestor: any): boolean
    local parent = rawget(self, "@parent");
    while (parent) do
        if (parent == ancestor) then
            return true;
        end
        parent = rawget(parent, "@parent");
    end
    return false;
end

function impl.method.IsAncestorOf(self: any, child: any): boolean
    local parent = rawget(child, "@parent");
    while (parent) do
        if (parent == self) then
            return true;
        end
        parent = rawget(parent, "@parent");
    end
    return false;
end

-- TODO: Implement Attributes
function impl.method.GetAttribute(self: any, name: string): any
    error("Not implemented");
end
function impl.method.SetAttribute(self: any, name: string, value: any): any
    error("Not implemented");
end
function impl.method.GetAttributes(self: any, name: string, value: any): any
    error("Not implemented");
end

function impl.method.Clone(self: any): any
    local copy = impl.object.raw(self["@instance"].className);
    copy["@instance"] = table.clone(self["@instance"]);
    copy["@instance"].properties = table.clone(self["@instance"].properties);
    for _, child in self["@children"] do
        table.insert(copy["@children"], child:Clone());
    end
    return copy;
end

function impl.method.ClearAllChildren(self: any): ()
    local childs = self["@children"];
    for _, child in childs do
        rawset(child, "@parent", nil);
    end
    table.clear(childs);
end

function impl.method.Destroy(self: any): ()
    if (rawget(self, "@parent")) then
        self.Parent = nil;
    end
    rawset(self, "@destroyed", true);
end

function impl.property.get.Name(self: any)
    local property = self["@instance"].properties["Name"];
    if (not property) then
        return nil;
    end
    return property.value;
end
function impl.property.get.Archivable(self: any)
    local property = self["@instance"].properties["Archivable"];
    if (not property) then
        return nil;
    end
    return property.value;
end
function impl.property.get.className(self: any)
    return self["@instance"].className;
end

return impl;
