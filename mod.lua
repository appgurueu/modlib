-- get modpath wrapper
function get_resource(modname, resource)
    if not resource then
        resource = modname
        modname = minetest.get_current_modname()
    end
    return minetest.get_modpath(modname) .. "/" .. resource
end

-- get resource + dofile
function include(modname, file)
    if not file then
        file = modname
        modname = minetest.get_current_modname()
    end
    dofile(get_resource(modname, file))
end

function include_env(file_or_string, env, is_string)
    setfenv(assert((is_string and loadstring or loadfile)(file_or_string)), env)()
end

function create_namespace(namespace_name, parent_namespace)
    namespace_name = namespace_name or minetest.get_current_modname()
    parent_namespace = parent_namespace or _G
    local namespace = setmetatable({}, {__index = parent_namespace})
    -- prevent MT's warning
    if parent_namespace == _G then
        rawset(parent_namespace, namespace_name, namespace)
    else
        parent_namespace[namespace_name] = namespace
    end
    return namespace
end

-- formerly extend_mod
function extend(modname, file)
    if not file then
        file = modname
        modname = minetest.get_current_modname()
    end
    include_env(get_resource(modname, file .. ".lua"), _G[modname])
end

-- runs main.lua in table env
-- formerly include_mod
function init(modname)
    modname = modname or minetest.get_current_modname()
    create_namespace(modname)
    extend(modname, "main")
end

function extend_string(modname, string)
    if not string then
        string = modname
        modname = minetest.get_current_modname()
    end
    include_env(string, _G[modname], true)
end