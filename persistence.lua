-- Localize globals
local assert, error, io, ipairs, loadfile, math, minetest, modlib, pairs, setfenv, setmetatable, table, type = assert, error, io, ipairs, loadfile, math, minetest, modlib, pairs, setfenv, setmetatable, table, type

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

lua_log_file = {
	-- default value
	reference_strings = true
}
local files = {}
local metatable = {__index = lua_log_file}

function lua_log_file.new(file_path, root, reference_strings)
	local self = setmetatable({
		file_path = assert(file_path),
		root = root,
		reference_strings = reference_strings
	}, metatable)
	if minetest then
		files[self] = true
	end
	return self
end

local function set_references(self, table)
	-- Weak table keys to allow the collection of dead reference tables
	-- TODO garbage collect strings in the references table
	self.references = setmetatable(table, {__mode = "k"})
end

function lua_log_file:load()
	-- Bytecode is blocked by the engine
	local read = assert(loadfile(self.file_path))
	-- math.huge is serialized to inf
	local env = {inf = math.huge}
	setfenv(read, env)
	read()
	env.R = env.R or {{}}
	self.reference_count = #env.R
	self.root = env.R[1]
	set_references(self, {})
end

function lua_log_file:open()
	self.file = io.open(self.file_path, "a+")
end

function lua_log_file:init()
	if modlib.file.exists(self.file_path) then
		self:load()
		self:_rewrite()
		self:open()
		return
	end
	self:open()
	self.root = {}
	self:_write()
end

function lua_log_file:log(statement)
	self.file:write(statement)
	self.file:write"\n"
end

function lua_log_file:flush()
	self.file:flush()
end

function lua_log_file:close()
	self.file:close()
	self.file = nil
	files[self] = nil
end

if minetest then
	minetest.register_on_shutdown(function()
		for self in pairs(files) do
			self.file:close()
		end
	end)
end

function lua_log_file:_dump(value, is_key)
	if value == nil then
		return "nil"
	end
	if value == true then
		return "true"
	end
	if value == false then
		return "false"
	end
	if value ~= value then
		-- nan
		return "0/0"
	end
	local _type = type(value)
	if _type == "number" then
		return ("%.17g"):format(value)
	end
	local reference = self.references[value]
	if reference then
		return "R[" .. reference .."]"
	end
	reference = self.reference_count + 1
	local key = "R[" .. reference .."]"
	local function create_reference()
		self.reference_count = reference
		self.references[value] = reference
	end
	if _type == "string" then
		local reference_strings = self.reference_strings
		if is_key and ((not reference_strings) or value:len() <= key:len()) and value:match"^[%a_][%a%d_]*$" then
			-- Short key
			return value, true
		end
		local formatted = ("%q"):format(value)
		if (not reference_strings) or formatted:len() <= key:len()  then
			-- Short string
			return formatted
		end
		-- Use reference
		create_reference()
		self:log(key .. "=" .. formatted)
	elseif _type == "table" then
		-- Tables always need a reference before they are traversed to prevent infinite recursion
		create_reference()
		-- TODO traverse tables to determine whether this is actually needed
		self:log(key .. "={}")
		local tablelen = #value
		for k, v in pairs(value) do
			if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > tablelen then
				local dumped, short = self:_dump(k, true)
				self:log(key .. (short and ("." .. dumped) or ("[" .. dumped .. "]")) .. "=" .. self:_dump(v))
			end
		end
	else
		error("unsupported type: " .. _type)
	end
	return key
end

function lua_log_file:set(table, key, value)
	if not self.references[table] then
		error"orphan table"
	end
	if table[key] == value then
		-- No change
		return
	end
	table[key] = value
	table = self:_dump(table)
	local key, short_key = self:_dump(key, true)
	self:log(table .. (short_key and ("." .. key) or ("[" .. key .. "]")) .. "=" .. self:_dump(value))
end

function lua_log_file:set_root(key, value)
	return self:set(self.root, key, value)
end

function lua_log_file:_write()
	set_references(self, {})
	self.reference_count = 0
	self:log"R={}"
	self:_dump(self.root)
end

function lua_log_file:_rewrite()
	self.file = io.open(self.file_path, "w+")
	self:_write()
	self.file:close()
end

function lua_log_file:rewrite()
	if self.file then
		self.file:close()
	end
	self:_rewrite()
	self:open()
end

-- Export environment
return _ENV