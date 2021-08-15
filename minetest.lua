local _ENV = setmetatable({}, {__index = _G})
local function load(filename)
	assert(loadfile(modlib.mod.get_resource(modlib.modname, "minetest", filename .. ".lua")))(_ENV)
end
-- minetest/gametime.lua is forceloaded in init.lua
load"misc"
load"collisionboxes"
load"liquid"
load"raycast"
load"wielditem_change"
load"colorspec"
load"schematic"
load"luon"
return _ENV