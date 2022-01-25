-- Localize globals
local assert, dump, error, ipairs, minetest, modlib, pairs, pcall, table, tonumber, type = assert, dump, error, ipairs, minetest, modlib, pairs, pcall, table, tonumber, type

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

-- not deprecated
function build_tree(dict)
	local tree = {}
	for key, value in pairs(dict) do
		local path = modlib.text.split_unlimited(key, ".")
		local subtree = tree
		for i = 1, #path - 1 do
			local index = tonumber(path[i]) or path[i]
			subtree[index] = subtree[index] or {}
			subtree = subtree[index]
		end
		subtree[path[#path]] = value
	end
	return tree
end
if minetest then
	function build_setting_tree()
		settings = build_tree(minetest.settings:to_table())
	end
	-- deprecated, use modlib.mod.configuration instead
	minetest.mkdir(minetest.get_worldpath().."/config")
	function get_path(confname)
		return minetest.get_worldpath().."/config/"..confname
	end
end
function read_conf(text)
	local lines = modlib.text.split_lines(text, nil, true)
	local dict = {}
	for i, line in ipairs(lines) do
		local error_base = "Line " .. (i+1) .. ": "
		line = modlib.text.trim_left(lines[i])
		if line ~= "" and line:sub(1,1) ~= "#" then
			line = modlib.text.split(line, "=", 2)
			if #line ~= 2 then
				error(error_base .. "No value given")
			end
			local prop = modlib.text.trim_right(line[1])
			if prop == "" then
				error(error_base .. "No key given")
			end
			local val = modlib.text.trim_left(line[2])
			if val == "" then
				error(error_base .. "No value given")
			end
			if modlib.text.starts_with(val, '"""') then
				val = val:sub(3)
				local total_val = {}
				local function readMultiline()
					while i < #lines do
						if modlib.text.ends_with(val, '"""') then
							val = val:sub(1, val:len() - 3)
							return
						end
						table.insert(total_val, val)
						i = i + 1
						val = lines[i]
					end
					i = i - 1
					error(error_base .. "Unclosed multiline block")
				end
				readMultiline()
				table.insert(total_val, val)
				val = table.concat(total_val, "\n")
			else
				val = modlib.text.trim_right(val)
			end
			if dict[prop] then
				error(error_base .. "Duplicate key")
			end
			dict[prop] = val
		end
	end
	return dict
end
function check_config_constraints(config, constraints, handler)
	local no_error, error_or_retval = pcall(function() check_constraints(config, constraints) end)
	if not no_error then
		handler(error_or_retval)
	end
end
function load(filename, constraints)
	local config = minetest.parse_json(modlib.file.read(filename))
	if constraints then
		check_config_constraints(config, constraints, function(message)
			error('Configuration of file "'..filename.."\" doesn't satisfy constraints: "..message)
		end)
	end
	return config
end
function load_or_create(filename, replacement_file, constraints)
	modlib.file.create_if_not_exists_from_file(filename, replacement_file)
	return load(filename, constraints)
end
function import(modname, constraints, no_settingtypes)
	local default_config = modlib.mod.get_resource(modname, "default_config.json")
	local default_conf = minetest.parse_json(modlib.file.read(default_config))
	local config = load_or_create(get_path(modname)..".json", default_config, constraints)
	local formats = {
		{ extension = ".lua", load = minetest.deserialize },
		{ extension = ".luon", load = function(text) minetest.deserialize("return "..text) end },
		{ extension = ".conf", load = function(text) return fix_types(build_tree(read_conf(text)), constraints) end }
	}
	for _, format in ipairs(formats) do
		local conf = modlib.file.read(get_path(modname)..format.extension)
		if conf then
			config = merge_config(config, format.load(conf))
		end
	end
	if not no_settingtypes then
		constraints.name = modname
		local settingtypes = generate_settingtypes(default_conf, constraints)
		modlib.file.write(modlib.mod.get_resource(modname, "settingtypes.txt"), settingtypes)
	end
	local additional_settings = settings[modname] or {}
	additional_settings = fix_types(additional_settings, constraints)
	-- TODO implement merge_config_legal(default_conf, ...)
	config = merge_config(config, additional_settings)
	if constraints then
		check_config_constraints(config, constraints, function(message)
			error('Configuration of mod "'..modname.."\" doesn't satisfy constraints: "..message)
		end)
	end
	return config
end
function merge_config(config, additional_settings)
	if not config or type(additional_settings) ~= "table" then
		return additional_settings
	end
	for setting, value in pairs(additional_settings) do
		if config[setting] then
			config[setting] = merge_config(config[setting], value)
		end
	end
	return config
end
-- format: # comment
-- name (Readable name) type type_args
function generate_settingtypes(default_conf, constraints)
	local constraint_type = constraints.type
	if constraints.children or constraints.possible_children or constraints.required_children or constraints.keys or constraints.values then
		constraint_type = "table"
	end
	local settingtype, type_args
	local title = constraints.title
	if not title then
		title = modlib.text.split(constraints.name, "_")
		title[1] = modlib.text.upper_first(title[1])
		title = table.concat(title, " ")
	end
	if constraint_type == "boolean" then
		settingtype = "bool"
		default_conf = default_conf and "true" or "false"
	elseif constraint_type == "string" then
		settingtype = "string"
	elseif constraint_type == "number" then
		settingtype = constraints.int and "int" or "float"
		local range = constraints.range
		if range then
			-- TODO consider better max
			type_args = (constraints.int and "%d %d" or "%f %f"):format(range[1], range[2] or (2 ^ 30))
		end
		-- HACK
		if not default_conf then default_conf = range[1] end
	elseif constraint_type == "table" then
		local handled = {}
		local settings = {}
		local function setting(key, value_constraints)
			if handled[key] then
				return
			end
			handled[key] = true
			value_constraints.name = constraints.name .. "." .. key
			value_constraints.title = title .. " " .. key
			table.insert(settings, generate_settingtypes(default_conf and default_conf[key], value_constraints))
		end
		for _, table in ipairs{"children", "required_children", "possible_children"} do
			for key, constraints in pairs(constraints[table] or {}) do
				setting(key, constraints)
			end
		end
		return table.concat(settings, "\n")
	end
	if not constraint_type then
		return ""
	end
	local comment = constraints.comment
	if comment then
		comment = "# " .. comment .. "\n"
	else
		comment = ""
	end
	assert(type(default_conf) == "string" or type(default_conf) == "number" or type(default_conf) == "nil", dump(default_conf))
	return comment .. constraints.name .. " (" .. title  .. ") " .. settingtype .. " " .. (default_conf or "") ..(type_args and (" "..type_args) or "")
end
function fix_types(value, constraints)
	local type = type(value)
	local expected_type = constraints.type
	if expected_type and expected_type ~= type then
		assert(type == "string", "Can't fix non-string value")
		if expected_type == "boolean" then
			assert(value == "true" or value == "false", "Not a boolean (true or false): " .. value)
			value = value == "true"
		elseif expected_type == "number" then
			assert(tonumber(value), "Not a number: " .. value)
			value = tonumber(value)
		end
	end
	if type == "table" then
		for key, val in pairs(value) do
			for _, child_constraints in ipairs{"required_children", "children", "possible_children"} do
				child_constraints = (constraints[child_constraints] or {})[key]
				if child_constraints then
					val = fix_types(val, child_constraints)
				end
			end
			if constraints.values then
				val = fix_types(val, constraints.values)
			end
			if constraints.keys then
				value[key] = nil
				value[fix_types(key, constraints.keys)] = val
			else
				value[key] = val
			end
		end
	end
	return value
end
function check_constraints(value, constraints)
	local t = type(value)
	if constraints.type and constraints.type ~= t then
		error("Wrong type: Expected "..constraints.type..", found "..t)
	end
	if (t == "number" or t == "string") and constraints.range then
		if value < constraints.range[1] or (constraints.range[2] and value > constraints.range[2]) then
			error("Not inside range: Expected value >= "..constraints.range[1].." and <= "..(constraints.range[2] or "inf")..", found "..minetest.write_json(value))
		end
	end
	if t == "number" and constraints.int and value % 1 ~= 0 then
		error("Not an integer number: " .. minetest.write_json(value))
	end
	if constraints.possible_values and not constraints.possible_values[value] then
		error("None of the possible values: Expected one of "..minetest.write_json(modlib.table.keys(constraints.possible_values))..", found "..minetest.write_json(value))
	end
	if t == "table" then
		if constraints.children then
			for key, val in pairs(value) do
				local child_constraints = constraints.children[key]
				if not child_constraints then
					error("Unexpected table entry: Expected one of "..minetest.write_json(modlib.table.keys(constraints.children))..", found "..minetest.write_json(key))
				else
					check_constraints(val, child_constraints)
				end
			end
			for key, _ in pairs(constraints.children) do
				if value[key] == nil then
					error("Table entry missing: Expected key "..minetest.write_json(key).." to be present in table "..minetest.write_json(value))
				end
			end
		end
		if constraints.required_children then
			for key, value_constraints in pairs(constraints.required_children) do
				local val = value[key]
				if val then
					check_constraints(val, value_constraints)
				else
					error("Table entry missing: Expected key "..minetest.write_json(key).." to be present in table "..minetest.write_json(value))
				end
			end
		end
		if constraints.possible_children then
			for key, value_constraints in pairs(constraints.possible_children) do
				local val = value[key]
				if val then
					check_constraints(val, value_constraints)
				end
			end
		end
		if constraints.keys then
			for key,_ in pairs(value) do
				check_constraints(key, constraints.keys)
			end
		end
		if constraints.values then
			for _, val in pairs(value) do
				check_constraints(val, constraints.values)
			end
		end
	end
	if constraints.func then
		local possible_errors = constraints.func(value)
		if possible_errors then
			error(possible_errors)
		end
	end
end

-- Export environment
return _ENV