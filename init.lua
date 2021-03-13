-- Lua version check
if _VERSION then
    if _VERSION < "Lua 5" then
        error("Outdated Lua version! modlib requires Lua 5 or greater.")
    end
    if _VERSION > "Lua 5.1" then
        -- not throwing error("Too new Lua version! modlib requires Lua 5.1 or smaller.") anymore
        unpack = unpack or table.unpack -- unpack was moved to table.unpack in Lua 5.2
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

modlib = {
    dir_delim = rawget(_G, "DIR_DELIM") or "/",
    _RG = setmetatable({}, {
        __index = function(_, index)
            return rawget(_G, index)
        end,
        __newindex = function(_, index, value)
            return rawset(_G, index, value)
        end
    })
}

local function get_resource(modname, resource, ...)
    if not resource then
        resource = modname
        modname = minetest.get_current_modname()
    end
    return table.concat({minetest.get_modpath(modname), resource, ...}, modlib.dir_delim)
end

local function loadfile_exports(filename)
    local env = setmetatable({}, {__index = _G})
    local file = assert(loadfile(filename))
    setfenv(file, env)
    file()
    return env
end

local minetest_only = {
    mod = true,
    minetest = true,
    data = true,
    log = true,
    player = true,
    -- not actually minetest-only, but a deprecated component
    conf = true
}
for _, component in ipairs{
    "mod",
    "conf",
    "schema",
    "data",
    "file",
    "func",
    "log",
    "math",
    "player",
    "table",
    "text",
    "vector",
    "quaternion",
    "minetest",
    "trie",
    "kdtree",
    "heap",
    "ranked_set",
    "binary",
    "b3d",
    "bluon"
} do
    if minetest or not minetest_only[component] then
        local path = minetest and get_resource(component .. ".lua") or component .. ".lua"
        modlib[component] = loadfile_exports(path)
    end
end

-- Aliases
modlib.string = modlib.text
modlib.number = modlib.math

if minetest then
    modlib.conf.build_setting_tree()

    modlib.mod.get_resource = get_resource
    modlib.mod.loadfile_exports = loadfile_exports
end

_ml = modlib

--[[
--modlib.mod.include("test.lua")
]]

return modlib