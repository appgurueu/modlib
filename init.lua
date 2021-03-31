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
				local name = debug.getupvalue(fn, i)
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

local modules = {}
for _, file in pairs{
	"schema",
	"file",
	"func",
	"math",
	"table",
	"text",
	"vector",
	"quaternion",
	"trie",
	"kdtree",
	"heap",
	"ranked_set",
	"binary",
	"b3d",
	"bluon"
} do
	modules[file] = file
end
if minetest then
	modules.minetest = {
		"misc",
		"collisionboxes",
		"liquid",
		"raycast",
		"wielditem_change",
		"colorspec"
	}
	for _, file in pairs{
		"data",
		"log",
		"player",
		-- deprecated
		"conf"
	} do
		modules[file] = file
	end
end

local load_module, get_resource, loadfile_exports
modlib = setmetatable({
	-- TODO bump on release
	version = 61,
	modname = minetest and minetest.get_current_modname(),
	dir_delim = rawget(_G, "DIR_DELIM") or "/",
	_RG = setmetatable({}, {
		__index = function(_, index)
			return rawget(_G, index)
		end,
		__newindex = function(_, index, value)
			return rawset(_G, index, value)
		end
	}),
	assertdump = minetest and function(v, value)
		if not v then
			error(dump(value), 2)
		end
	end
}, {
	__index = function(self, module_name)
		local files = modules[module_name]
		local module
		if type(files) == "string" then
			module = load_module(files)
		elseif files then
			module = loadfile_exports(get_resource(self.modname, module_name, files[1] .. ".lua"))
			for index = 2, #files do
				self.mod.include_env(get_resource(self.modname, module_name, files[index] .. ".lua"), module)
			end
		end
		self[module_name] = module
		return module
	end
})

function get_resource(modname, resource, ...)
	if not resource then
		resource = modname
		modname = minetest.get_current_modname()
	end
	return table.concat({minetest.get_modpath(modname), resource, ...}, modlib.dir_delim)
end

function loadfile_exports(filename)
	local env = setmetatable({}, {__index = _G})
	local file = assert(loadfile(filename))
	setfenv(file, env)
	file()
	return env
end

local init_path = arg and arg[0]
local parent_dir = init_path and init_path:match"^.[/\\]" or ""
function load_module(module_name)
	local file = module_name .. ".lua"
	return loadfile_exports(minetest and get_resource(modlib.modname, file) or (parent_dir .. file))
end

modlib.mod = minetest and loadfile_exports(get_resource(modlib.modname, "mod.lua"))

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
--modlib.mod.include"test.lua"
]]

return modlib