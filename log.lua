-- Localize globals
local ipairs, minetest, modlib, os, pairs, table = ipairs, minetest, modlib, os, pairs, table

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

-- Log helpers - write to log, force writing to file
minetest.mkdir(minetest.get_worldpath() .. "/logs")
channels = {}
last_day = os.date("%d")
function get_path(logname)
	return minetest.get_worldpath() .. "/logs/" .. logname
end
function create_channel(title)
	local dir = get_path(title)
	minetest.mkdir(dir)
	channels[title] = {dirname = dir, queue = {}}
	write(title, "Initialisation")
end
function write(channelname, msg)
	local channel = channels[channelname]
	local current_day = os.date("%d")
	if current_day ~= last_day then
		last_day = current_day
		write_to_file(channelname, channel, os.date("%Y-%m-%d"))
	end
	table.insert(channel.queue, os.date("[%H:%M:%S] ") .. msg)
end
function write_to_all(msg)
	for channelname, _ in pairs(channels) do
		write(channelname, msg)
	end
end
function write_to_file(name, channel, current_date)
	if not channel then
		channel = channels[name]
	end
	if #(channel.queue) > 0 then
		local filename = channel.dirname .. "/" .. (current_date or os.date("%Y-%m-%d")) .. ".txt"
		local rope = {}
		for _, msg in ipairs(channel.queue) do
			table.insert(rope, msg)
		end
		modlib.file.append(filename, table.concat(rope, "\n") .. "\n")
		channels[name].queue = {}
	end
end
function write_all_to_file()
	local current_date = os.date("%Y-%m-%d")
	for name, channel in pairs(channels) do
		write_to_file(name, channel, current_date)
	end
end
function write_safe(channelname, msg)
	write(channelname, msg)
	write_all_to_file()
end

local timer = 0

minetest.register_globalstep(
	function(dtime)
		timer = timer + dtime
		if timer > 5 then
			write_all_to_file()
			timer = 0
		end
	end
)

minetest.register_on_mods_loaded(
	function()
		write_to_all("Mods loaded")
	end
)

minetest.register_on_shutdown(
	function()
		write_to_all("Shutdown")
		write_all_to_file()
	end
)


-- Export environment
return _ENV