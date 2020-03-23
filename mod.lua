-- get modpath wrapper
function get_resource(modname, resource)
    return minetest.get_modpath(modname) .. "/" .. resource
end

-- get resource + dofile
function include(modname, file)
    dofile(get_resource(modname, file))
end

-- loadfile with table env
function include_namespace(classname, filename, parent_namespace)
    parent_namespace = parent_namespace or _G
    parent_namespace[classname] = setmetatable(parent_namespace[classname] or {}, {__index = parent_namespace, __call = parent_namespace})
    local class = assert(loadfile(filename))
    setfenv(class, parent_namespace[classname])
    class()
    return parent_namespace[classname]
end

-- runs main.lua in table env
-- formerly include_mod
function init(modname)
    include_namespace(modname, get_resource(modname, "main.lua"))
end

-- formerly extend_mod
function extend(modname, filename)
    include_namespace(modname, get_resource(modname, filename .. ".lua"))
end

-- formerly extend_mod_string
function extend_string(modname, string)
    _G[modname] = setmetatable(_G[modname] or {}, {__index = _G, __call = _G})
    local string = assert(loadstring(string))
    setfenv(string, _G[modname])
    string()
    return _G[modname]
end