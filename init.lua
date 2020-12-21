-- Silence builtin/strict.lua
setmetatable(_G, {})
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

local function get_resource(modname, resource)
    if not resource then
        resource = modname
        modname = minetest.get_current_modname()
    end
    return minetest.get_modpath(modname) .. "/" .. resource
end

local function loadfile_exports(filename)
    local env = setmetatable({}, {__index = _G})
    local file = assert(loadfile(filename))
    setfenv(file, env)
    file()
    return env
end

local components = {
    mod = {},
    conf = {},
    schema = {},
    data = {},
    file = {},
    func = {},
    log = {},
    minetest = {},
    math = {"number"},
    player = {},
    table = {},
    text = {"string"},
    vector = {},
    trie = {}
}

modlib = {}

for component, aliases in pairs(components) do
    local comp = loadfile_exports(get_resource(component .. ".lua"))
    modlib[component] = comp
    for _, alias in pairs(aliases) do
        modlib[alias] = comp
    end
end

modlib.conf.build_setting_tree()

modlib.mod.get_resource = get_resource
modlib.mod.loadfile_exports = loadfile_exports

_ml = modlib

--[[
--modlib.mod.include("test.lua")
]]