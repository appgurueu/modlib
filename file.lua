local dir_delim = ...
-- Localize globals
local io, minetest, modlib, string = io, minetest, modlib, string

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

_ENV.dir_delim = dir_delim

function get_name(filepath)
	return filepath:match("([^%" .. dir_delim .. "]+)$") or filepath
end

function split_extension(filename)
	return filename:match"^(.*)%.(.*)$"
end
--! deprecated
get_extension = split_extension

function split_path(filepath)
	return modlib.text.split_unlimited(filepath, dir_delim, true)
end

-- concat_path is set by init.lua to avoid code duplication

function read(filename)
	local file, err = io.open(filename, "r")
	if file == nil then return nil, err end
	local content = file:read"*a"
	file:close()
	return content
end

function read_binary(filename)
	local file, err = io.open(filename, "rb")
	if file == nil then return nil, err end
	local content = file:read"*a"
	file:close()
	return content
end

function write_unsafe(filename, new_content)
	local file, err = io.open(filename, "w")
	if file == nil then return false, err end
	file:write(new_content)
	file:close()
	return true
end

write = minetest and minetest.safe_file_write or write_unsafe

function write_binary_unsafe(filename, new_content)
	local file, err = io.open(filename, "wb")
	if file == nil then return false, err end
	file:write(new_content)
	file:close()
	return true
end

write_binary = minetest and minetest.safe_file_write or write_binary_unsafe

function ensure_content(filename, ensured_content)
	local content = read(filename)
	if content ~= ensured_content then
		return write(filename, ensured_content)
	end
	return true
end

function append(filename, new_content)
	local file, err = io.open(filename, "a")
	if file == nil then return false, err end
	file:write(new_content)
	file:close()
	return true
end

function exists(filename)
	local file, err = io.open(filename, "r")
	if file == nil then return false, err end
	file:close()
	return true
end

function create_if_not_exists(filename, content)
	if not exists(filename) then
		return write(filename, content or "")
	end
	return false
end

function create_if_not_exists_from_file(filename, src_filename) return create_if_not_exists(filename, read(src_filename)) end

if not minetest then return end

-- Process Bridge Helpers
process_bridges = {}

function process_bridge_build(name, input, output, logs)
	if not input or not output or not logs then
		minetest.mkdir(minetest.get_worldpath() .. "/bridges/" .. name)
	end
	input = input or minetest.get_worldpath() .. "/bridges/" .. name .. "/input.txt"
	output = output or minetest.get_worldpath() .. "/bridges/" .. name .. "/output.txt"
	logs = logs or minetest.get_worldpath() .. "/bridges/" .. name .. "/logs.txt"
	-- Clear input
	write(input, "")
	-- Clear output
	write(output, "")
	-- Create logs if not exists
	create_if_not_exists(logs, "")
	process_bridges[name] = {
		input = input,
		output = output,
		logs = logs,
		output_file = io.open(output, "a")
	}
end

function process_bridge_listen(name, line_consumer, step)
	local bridge = process_bridges[name]
	modlib.minetest.register_globalstep(step or 0.1, function()
		for line in io.lines(bridge.input) do
			line_consumer(line)
		end
		write(bridge.input, "")
	end)
end

function process_bridge_serve(name, step)
	local bridge = process_bridges[name]
	modlib.minetest.register_globalstep(step or 0.1, function()
		bridge.output_file:close()
		process_bridges[name].output_file = io.open(bridge.output, "a")
	end)
end

function process_bridge_write(name, message)
	local bridge = process_bridges[name]
	bridge.output_file:write(message .. "\n")
end

function process_bridge_start(name, command, os_execute)
	local bridge = process_bridges[name]
	os_execute(string.format(command, bridge.output, bridge.input, bridge.logs))
end

-- Export environment
return _ENV
