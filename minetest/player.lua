-- Localize globals
local ipairs, minetest, modlib, table = ipairs, minetest, modlib, table

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

--! deprecated

forbidden_names = {}

function register_forbidden_name(name) forbidden_names[name] = true end

function unregister_forbidden_name(name) forbidden_names[name] = nil end

minetest.register_on_prejoinplayer(function(name)
	if forbidden_names[name] then
		return 'The name "' .. name .. '" is not allowed as a player name'
	end
end)
playerdata = {}
defaults = {}
playerdata_functions = {}

function delete_player_data(playername) playerdata[playername] = nil end

function create_player_data(playername) playerdata[playername] = {} end

function init_player_data(playername)
	modlib.table.add_all(playerdata[playername], defaults)
	for _, callback in ipairs(playerdata_functions) do callback(playerdata[playername]) end
end

function get_player_data(playername) return playerdata[playername] end

function get_property(playername, propertyname) return get_player_data(playername)[propertyname] end

function set_property(playername, propertyname, propertyvalue) get_player_data(playername)[propertyname] = propertyvalue end

function get_property_default(propertyname) return defaults[propertyname] end

function set_property_default(propertyname, defaultvalue) defaults[propertyname] = defaultvalue end

function add_playerdata_function(callback) table.insert(playerdata_functions, callback) end

function get_color(player)
	local sender_color = player:get_properties().nametag_color
	if sender_color then
		sender_color = minetest.rgba(sender_color.r, sender_color.g, sender_color.b)
	else sender_color = "#FFFFFF" end
	return sender_color
end

function get_color_table(player)
	local sender_color = player:get_properties().nametag_color
	return sender_color or { r = 255, g = 255, b = 255 }
end

--! deprecated in favor of modlib.minetest.colorspec
function get_color_int(player)
	local sender_color = player:get_properties().nametag_color
	if sender_color then
		sender_color = sender_color.b + sender_color.g * 0x100 + sender_color.r * 0x10000
	else sender_color = 0xFFFFFF end
	return sender_color
end

minetest.register_on_joinplayer(function(player)
	local playername = player:get_player_name()
	create_player_data(playername)
	init_player_data(playername)
end)
minetest.register_on_leaveplayer(function(player)
	local playername = player:get_player_name()
	delete_player_data(playername)
end)

function datatable(table, default)
	table = table or {}
	default = default or {}
	minetest.register_on_joinplayer(function(player)
		local name = player:get_player_name()
		table[name] = table[name] or default
	end)
	minetest.register_on_leaveplayer(function(player) table[player:get_player_name()] = nil end)
	return table
end

-- Export environment
return _ENV