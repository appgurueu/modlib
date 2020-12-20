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
    return dofile(get_resource(modname, file))
end

function include_env(file_or_string, env, is_string)
    setfenv(assert((is_string and loadstring or loadfile)(file_or_string)), env)()
end

function create_namespace(namespace_name, parent_namespace)
    namespace_name = namespace_name or minetest.get_current_modname()
    parent_namespace = parent_namespace or _G
    local namespace = setmetatable({}, {__index = parent_namespace})
    -- should use rawset if MT's strictness wasn't disabled in init.lua
    parent_namespace[namespace_name] = namespace
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

function configuration(modname)
    modname = modname or minetest.get_current_modname()
    local schema = modlib.schema.new(assert(include(modname, "schema.lua")))
    schema.name = schema.name or modname
    assert(schema.type == "table")
    local overrides = {}
    local conf
    local function add(path)
        for _, format in ipairs{
            {extension = "lua", read = function(text)
                assert(overrides._C == nil)
                local additions =  setfenv(assert(loadstring(text)), setmetatable(overrides, {__index = {_C = overrides}}))()
                setmetatable(overrides, nil)
                if additions == nil then
                    return overrides
                end
                return additions
            end},
            {extension = "luon", read = function(text)
                local value = {setfenv(assert(loadstring("return " .. text)), setmetatable(overrides, {}))()}
                assert(#value == 1)
                value = value[1]
                local function check_type(value)
                    local type = type(value)
                    if type == "table" then
                        assert(getmetatable(value) == nil)
                        for key, value in pairs(value) do
                            check_type(key)
                            check_type(value)
                        end
                    elseif not (type == "boolean" or type == "number" or type == "string") then
                        error("disallowed type " .. type)
                    end
                end
                check_type(value)
                return value
            end},
            {extension = "conf", read = function(text) return Settings(text):to_table() end, convert_strings = true},
            {extension = "json", read = minetest.parse_json}
        } do
            local content = modlib.file.read(path .. "." .. format.extension)
            if content then
                overrides = modlib.table.deep_add_all(overrides, format.read(content))
                conf = schema:load(overrides, {convert_strings = format.convert_strings, error_message = true})
            end
        end
    end
    add(minetest.get_worldpath() .. "/conf/" .. modname)
    add(get_resource(modname, "conf"))
    local minetest_conf = modlib.conf.settings[schema.name]
    if minetest_conf then
        overrides = modlib.table.deep_add_all(overrides, minetest_conf)
        conf = schema:load(overrides, {convert_strings = true, error_message = true})
    end
    if conf == nil then
        return schema:load({}, {error_message = true})
    end
    return conf
end