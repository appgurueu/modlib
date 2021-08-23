local _ENV = {}

local components = {}
for _, value in pairs{
	"luon",
	"raycast",
	"schematic",
	"colorspec"
} do
	components[value] = value
end
for filename, comps in pairs{
	misc = {
		"max_wear",
		"override",
		"after",
		"register_globalstep",
		"form_listeners",
		"register_form_listener",
		"texture_modifier_inventorycube",
		"get_node_inventory_image",
		"check_player_privs",
		"decode_base64",
		"objects_inside_radius",
		"objects_inside_area",
		"nodename_matcher",
		"playerdata",
		"connected_players",
		"register_on_leaveplayer",
		"get_mod_info"
	},
	liquid = {
		"liquid_level_max",
		"get_liquid_corner_levels",
		"flowing_downwards",
		"get_liquid_flow_direction"
	},
	wielditem_change = {
		"players",
		"registered_on_wielditem_changes",
		"register_on_wielditem_change"
	},
	colorspec = {
		"named_colors",
		"colorspec_to_colorstring"
	},
	collisionboxes = {
		"get_node_collisionboxes"
	}
} do
	for _, component in pairs(comps) do
		components[component] = filename
	end
end

setmetatable(_ENV, {__index = function(_ENV, name)
	local filename = components[name]
	if filename then
		assert(loadfile(modlib.mod.get_resource(modlib.modname, "minetest", filename .. ".lua")))(_ENV)
		return rawget(_ENV, name)
	end
end})

return _ENV