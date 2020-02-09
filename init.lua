-- Lua version check
if _VERSION then
    if _VERSION < "Lua 5" then
        error("Outdated Lua version! modlib requires Lua 5 or greater.")
    end
    if _VERSION > "Lua 5.1" then -- TODO automatically use _ENV instead of s/getfenv if _VERSION > 5.1
        -- not throwing error("Too new Lua version! modlib requires Lua 5.1 or smaller.") anymore
        loadstring = load
        function setfenv(fn, env)
            local i = 1
            while true do
                name = debug.getupvalue(fn, i)
                if name == "_ENV" then
                    debug.setupvalue(fn, i, env)
                    break
                elseif not name then
                    break
                end
            end
            return fn
        end
        function getfenv(fn)
            local i = 1
            local name, val
            repeat
                name, val = debug.getupvalue(fn, i)
                if name == "_ENV" then
                    return val
                end
                i = i + 1
            until not name
        end
    end
end

-- MT shorthands
mt = minetest
MT = mt

-- TODO automatically know current mod

-- get modpath wrapper
function get_resource(modname, resource)
    return minetest.get_modpath(modname) .. "/" .. resource
end

-- get resource + dofile
function include(modname, file)
    dofile(get_resource(modname, file))
end

function loadfile_exports(filename)
    local env = setmetatable({}, {__index = _G, __call = _G})
    local file = assert(loadfile(filename))
    setfenv(file, env)
    file()
    return env
end

-- loadfile with table env
function include_class(classname, filename)
    _G[classname] = setmetatable(_G[classname] or {}, {__index = _G, __call = _G})
    local class = assert(loadfile(filename))
    setfenv(class, _G[classname])
    class()
    return _G[classname]
end

-- runs main.lua in table env
function include_mod(modname)
    include_class(modname, get_resource(modname, "main.lua"))
end

function extend_mod(modname, filename)
    include_class(modname, get_resource(modname, filename .. ".lua"))
end

function extend_mod_string(modname, string)
    _G[modname] = setmetatable(_G[modname] or {}, {__index = _G, __call = _G})
    local string = assert(loadstring(string))
    setfenv(string, _G[modname])
    string()
    return _G[modname]
end

local components = {
    class = {class = "global"},
    conf = {conf = "global"},
    data = {data = "global"},
    file = {file_ext = "global"},
    log = {log = "global"},
    minetest = {mt_ext = "global"},
    number = {number_ext = "global"},
    player = {player_ext = "global"},
    table = {table_ext = "global"},
    text = {string_ext = "global"},
    threading = {threading_ext = "global"}
}

modlib = {}

for component, additional in pairs(components) do
    local comp = loadfile_exports(get_resource("modlib", component .. ".lua"))
    modlib[component] = comp
    for alias, scope in pairs(additional) do
        if scope == "global" then
            _G[alias] = comp
        else
            modlib[alias] = comp
        end
    end
end

_ml = modlib