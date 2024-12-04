--!strict
local object = require("./object");
local roblox = require("./types/roblox");

local dom = require("../dom");
local reflection = require("../reflection");

local manager = {};

function manager.instanceFromDOM(instance: dom.DOMInstance): roblox.Instance
    local obj = object.raw(instance.className);
    local object_properties = obj["@properties"];
    for name, property in instance.properties do
        object_properties[name] = property;
    end
    object.LoadDefaultProperties(obj, instance.className);
    return obj::any;
end

function manager.instancesFromDOM(doc: dom.DOM): {roblox.Instance}
    local instances = table.create(doc.info.instances);
    for _, instance in doc.instances do
        instances[instance.referent] = manager.instanceFromDOM(instance);
    end
    local valid = doc.info.instances;
    for _, instance in doc.instances do
        local object = instances[instance.referent];
        if (instance.parent) then
            (object::any)["@parent"] = instances[instance.parent];
            valid -= 1;
        end
    end
    for _, instance in instances do
        for name, property in (instance::any)["@properties"] do
            if (property.type == dom.roblox.PropertyTypes.Ref and property.value) then
                property.value = instances[property.value];
            elseif (property.type == dom.roblox.PropertyTypes.SharedString and property.value) then
                property.value = doc.sharedstrings[property.value];
            end
        end
    end
    local list = table.create(valid);
    for _, instance in instances do
        if ((instance::any)["@parent"] == nil) then
            table.insert(list, instance);
        end
    end
    return list;
end

function manager.modelFromDOM(doc: dom.DOM): {roblox.Instance}
    return manager.instancesFromDOM(doc);
end

function manager.placeFromDom(doc: dom.DOM): roblox.DataModel
    local datamodel = object.raw("DataModel");
    datamodel["@properties"]["Name"] = {
        value = "DataModel",
        type = dom.roblox.PropertyTypes.String,
    };
    local instances = manager.instancesFromDOM(doc);
    for _, instance in instances do
        (instance::any)["@parent"] = datamodel;
    end
    return datamodel::any;
end

function manager.domFromInstances(
    descendants: {roblox.Instance},
    descendants_map: {[roblox.Instance]: number},
    ignoreParent: roblox.Instance?
): dom.DOM
    local sharedstrings = {};

    local instances: {dom.DOMInstance} = table.create(#descendants);
    local classes: {dom.DOMClass} = {}; do
        local map = {};
        local index = 1;
        for i, descendant in descendants do
            local class_name = (descendant::any)["@class"];
            local class: dom.DOMClass = map[class_name];
            if (not class) then
                local api_class = reflection:GetClass(class_name);
                local is_service =
                    if (api_class and api_class.Tags) then
                        table.find(api_class.Tags, "Service") ~= nil
                    else
                        false;
                class = {
                    index = index;
                    name = class_name,
                    instances = {},
                    isService = is_service,
                };
                index += 1;
                map[class_name] = class;
                table.insert(classes, class::any);
            end
            table.insert(class.instances, i);
        end
        for i, descendant in descendants do
            local class = map[(descendant::any)["@class"]];
            local dom_instance: dom.DOMInstance = {
                referent = i,
                className = (descendant::any)["@class"],
                properties = {},
                isService = class.isService,
                parent = nil,
            };
            for name, property in (descendant::any)["@properties"] do
                if (not property.serialize or not property.type) then
                    continue;
                end
                local value = property.value;
                if (property.type == dom.roblox.PropertyTypes.Ref and value) then
                    value = descendants_map[value];
                    if (not value) then
                        error(`Reference to non-existent instance at '{descendant:GetFullName()}' (from another DataModel?)`);
                    end
                elseif (property.type == dom.roblox.PropertyTypes.SharedString) then
                    if (type(property.value) ~= "table") then
                        print("[rbx-manager] SharedString not set");
                        continue;
                    end
                    if (not table.find(sharedstrings, property.value)) then
                        assert(type(property.value) == "table", "Internal Error, SharedString not set");
                        table.insert(sharedstrings, property.value);
                    end
                    value = table.find(sharedstrings, property.value);
                    assert(value, "SharedString not found");
                end
                dom_instance.properties[name] = {
                    value = value,
                    type = property.type,
                };
            end
            local parent = descendant.Parent;
            if (parent and parent ~= ignoreParent) then
                dom_instance.parent = descendants_map[parent];
                assert(dom_instance.parent, "Parent instance not found (failed to reference)");
            end
            table.insert(instances, dom_instance);
        end
    end

    return {
        info = {
            version = 0,
            instances = #instances,
            classes = #classes,
            reserved = buffer.create(8),
        },
        instances = instances,
        classes = classes,
        metadata = {},
        sharedstrings = sharedstrings,
    };
end
function manager.domFromPlace(datamodel: roblox.DataModel): dom.DOM
    assert(
        object.is(datamodel) and datamodel:IsA("DataModel"),
        "argument #1 must be a DataModel instance"
    );
    local descendants_map = {};
    local descendants = datamodel:GetDescendants(); do
        local filtered = table.create(#descendants);
        local index = 1;
        for _, descendant in descendants do
            if (descendant.Archivable) then
                table.insert(filtered, descendant);
                descendants_map[descendant] = index;
                index += 1;
            end
        end
        descendants = filtered;
    end
    return manager.domFromInstances(descendants, descendants_map, datamodel);
end

function manager.domFromModel(instances: {roblox.Instance}): dom.DOM
    local descendants = {};
    local descendants_map = {};
    local index = 1;
    for _, instance in instances do
        assert(
            object.is(instance) and instance:IsA("Instance"),
            "argument #1 must be a Instance"
        );
        table.insert(descendants, instance);
        descendants_map[instance] = index;
        index += 1;
        for _, descendant in instance:GetDescendants() do
            if (descendant.Archivable) then
                table.insert(descendants, descendant);
                descendants_map[descendant] = index;
                index += 1;
            end
        end
    end
    return manager.domFromInstances(descendants, descendants_map);
end

local instance = {};

local function instanceNew(className: string, parent: roblox.Instance?): roblox.Instance
    return object.new(className, parent);
end

instance.New = (instanceNew::any)::roblox.NewConstructor;

manager.Instance = instance;

manager.typeof = function(value: any)
    if (object.is(value)) then
        return "Instance";
    end
    return typeof(value);
end;

manager.type = function(value: any)
    if (object.is(value)) then
        return "userdata";
    end
    return type(value);
end;

return manager;
