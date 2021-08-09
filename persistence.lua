local require = ... or require
-- TODO consider moving serializers in this namespace
local function load(module_name)
	return assert(loadfile(modlib.mod.get_resource(modlib.modname, "persistence", module_name .. ".lua")))
end
local _ENV = setmetatable({}, {__index = function(_ENV, module_name)
	if module_name == "lua_log_file" then
		local module = load(module_name)()
		_ENV[module_name] = module
		return module
	end
	if module_name == "sqlite3" then
		local func = load(module_name)
		local module = function(sqlite3)
			if sqlite3 then
				return func(sqlite3)
			end
			return func(require"lsqlite3")
		end
		_ENV[module_name] = module
		return module
	end
end})
return _ENV