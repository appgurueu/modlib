function read(filename)
	local file = io.open(filename, "r")
	if file == nil then return nil end
	local content = file:read"*a"
	file:close()
	return content
end

function write(filename, new_content)
	local file = io.open(filename, "w")
	if file == nil then return false end
	file:write(new_content)
	file:close()
	return true
end

function ensure_content(filename, ensured_content)
    local content = read(filename)
    if content ~= ensured_content then
        return write(filename, ensured_content)
    end
    return true
end

function append(filename, new_content)
	local file = io.open(filename, "a")
	if file == nil then return false end
	file:write(new_content)
	file:close()
	return true
end

function exists(filename)
	local file = io.open(filename, "r")
	if file == nil then return false end
	file:close()
	return true
end

function create_if_not_exists(filename, content)
	if not exists(filename) then
		write(filename, content or "")
		return true
	end
	return false
end

function create_if_not_exists_from_file(filename, src_filename) return create_if_not_exists(filename, read(src_filename)) end

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
	modlib.minetest.register_globalstep(step or 0.1, function(dtime)
		local content = io.open(bridge.input, "r")
		local line = content:read()
		while line do
			line_consumer(line)
			line = content:read()
		end
		write(bridge.input, "")
	end)
end

function process_bridge_serve(name, step)
	local bridge = process_bridges[name]
	modlib.minetest.register_globalstep(step or 0.1, function(dtime)
		bridge.output_file:close()
		process_bridges[name].output_file = io.open(bridge.output, "a")
	end)
end

function process_bridge_write(name, message)
	local bridge = process_bridges[name]
	bridge.output_file:write(message .. "\n")
	-- append(bridge.input, message)
end

function process_bridge_start(name, command, os_execute)
	local bridge = process_bridges[name]
	os_execute(string.format(command, bridge.output, bridge.input, bridge.logs))
end