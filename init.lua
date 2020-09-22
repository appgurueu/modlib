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

-- TODO get rid of code duplication
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
    class = {},
    conf = {},
    data = {},
    file = {},
    func = {},
    log = {},
    minetest = {},
    number = {},
    player = {},
    table = {},
    text = {string = "local"},
    threading = {},
    vector = {}
}

modlib = {}

for component, additional in pairs(components) do
    local comp = loadfile_exports(get_resource(component .. ".lua"))
    modlib[component] = comp
    for alias, scope in pairs(additional) do
        if scope == "global" then
            _G[alias] = comp
        else
            modlib[alias] = comp
        end
    end
end

modlib.conf.build_setting_tree()

modlib.mod.loadfile_exports = loadfile_exports

_ml = modlib

--[[
--modlib.mod.include("test.lua")
]]