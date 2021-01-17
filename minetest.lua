max_wear = 2 ^ 16 - 1
function override(function_name, function_builder)
    local func = minetest[function_name]
    minetest["original_" .. function_name] = func
    minetest[function_name] = function_builder(func)
end

-- TODO fix modlib.minetest.get_gametime() messing up responsible "mod" determined by engine on crash
get_gametime = minetest.get_gametime
local get_gametime_initialized
local function get_gametime_init(dtime)
    if get_gametime_initialized then
        -- if the profiler is being used, the globalstep can't be unregistered
        return
    end
    get_gametime_initialized = true
    assert(dtime == 0)
    local gametime = minetest.get_gametime()
    assert(gametime)
    function modlib.minetest.get_gametime()
        local imprecise_gametime = minetest.get_gametime()
        if imprecise_gametime > gametime then
            minetest.log("warning", "modlib.minetest.get_gametime(): Called after increment and before first globalstep")
            return imprecise_gametime
        end
        return gametime
    end
    for index, globalstep in pairs(minetest.registered_globalsteps) do
        if globalstep == get_gametime_init then
            table.remove(minetest.registered_globalsteps, index)
            break
        end
    end
    -- globalsteps of mods which depend on modlib will execute after this
    minetest.register_globalstep(function(dtime)
        gametime = gametime + dtime
    end)
end
minetest.register_globalstep(get_gametime_init)

delta_times={}
delays={}
callbacks={}
function register_globalstep(interval, callback)
    if type(callback) ~= "function" then
        return
    end
    table.insert(delta_times, 0)
    table.insert(delays, interval)
    table.insert(callbacks, callback)
end
function texture_modifier_inventorycube(face_1, face_2, face_3)
    return "[inventorycube{" .. string.gsub(face_1, "%^", "&")
            .. "{" .. string.gsub(face_2, "%^", "&")
            .. "{" .. string.gsub(face_3, "%^", "&")
end
function get_node_inventory_image(nodename)
    local n = minetest.registered_nodes[nodename]
    if not n then
        return
    end
    local tiles = {}
    for l, tile in pairs(n.tiles or {}) do
        tiles[l] = (type(tile) == "string" and tile) or tile.name
    end
    local chosen_tiles = { tiles[1], tiles[3], tiles[5] }
    if #chosen_tiles == 0 then
        return false
    end
    if not chosen_tiles[2] then
        chosen_tiles[2] = chosen_tiles[1]
    end
    if not chosen_tiles[3] then
        chosen_tiles[3] = chosen_tiles[2]
    end
    local img = minetest.registered_items[nodename].inventory_image
    if string.len(img) == 0 then
        img = nil
    end
    return img or texture_modifier_inventorycube(chosen_tiles[1], chosen_tiles[2], chosen_tiles[3])
end
function get_color_int(color)
    return color.b + (color.g*256) + (color.r*256*256)
end
function check_player_privs(playername, privtable)
    local privs=minetest.get_player_privs(playername)
    local missing_privs={}
    local to_lose_privs={}
    for priv, expected_value in pairs(privtable) do
        local actual_value=privs[priv]
        if expected_value then
            if not actual_value then
                table.insert(missing_privs, priv)
            end
        else
            if actual_value then
                table.insert(to_lose_privs, priv)
            end
        end
    end
    return missing_privs, to_lose_privs
end

minetest.register_globalstep(function(dtime)
    for k, v in pairs(delta_times) do
        local v=dtime+v
        if v > delays[k] then
            callbacks[k](v)
            v=0
        end
        delta_times[k]=v
    end
end)

form_listeners = {}
function register_form_listener(formname, func)
    local current_listeners = form_listeners[formname] or {}
    table.insert(current_listeners, func)
    form_listeners[formname] = current_listeners
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    local handlers = form_listeners[formname]
    if handlers then
        for _, handler in pairs(handlers) do
            handler(player, fields)
        end
    end
end)

--+ Improved base64 decode removing valid padding
function decode_base64(base64)
    local len = base64:len()
    local padding_char = base64:sub(len, len) == "="
    if padding_char then
        if len % 4 ~= 0 then
            return
        end
        if base64:sub(len-1, len-1) == "=" then
            base64 = base64:sub(1, len-2)
        else
            base64 = base64:sub(1, len-1)
        end
    end
    return minetest.decode_base64(base64)
end

liquid_level_max = 8
--+ Calculates the corner levels of a flowingliquid node
--> 4 corner levels from -0.5 to 0.5 as list of `modlib.vector`
function get_liquid_corner_levels(pos)
    local node = minetest.get_node(pos)
    local def = minetest.registered_nodes[node.name]
    local source, flowing = def.liquid_alternative_source, node.name
    local range = def.liquid_range or liquid_level_max
    local neighbors = {}
    for x = -1, 1 do
        neighbors[x] = {}
        for z = -1, 1 do
            local neighbor_pos = {x = pos.x + x, y = pos.y, z = pos.z + z}
            local neighbor_node = minetest.get_node(neighbor_pos)
            local level
            if neighbor_node.name == source then
                level = 1
            elseif neighbor_node.name == flowing then
                local neighbor_level = neighbor_node.param2 % 8
                level = (math.max(0, neighbor_level - liquid_level_max + range) + 0.5) / range
            end
            neighbor_pos.y = neighbor_pos.y + 1
            local node_above = minetest.get_node(neighbor_pos)
            neighbors[x][z] = {
                air = neighbor_node.name == "air",
                level = level,
                above_is_same_liquid = node_above.name == flowing or node_above.name == source
            }
        end
    end
    local function get_corner_level(x, z)
        local air_neighbor
        local levels = 0
        local neighbor_count = 0
        for nx = x - 1, x do
            for nz = z - 1, z do
                local neighbor = neighbors[nx][nz]
                if neighbor.above_is_same_liquid then
                    return 1
                end
                local level = neighbor.level
                if level then
                    if level == 1 then
                        return 1
                    end
                    levels = levels + level
                    neighbor_count = neighbor_count + 1
                elseif neighbor.air then
                    if air_neighbor then
                        return 0.02
                    end
                    air_neighbor = true
                end
            end
        end
        if neighbor_count == 0 then
            return 0
        end
        return levels / neighbor_count
    end
    local corner_levels = {
        {0, nil, 0},
        {1, nil, 0},
        {1, nil, 1},
        {0, nil, 1}
    }
    for index, corner_level in pairs(corner_levels) do
        corner_level[2] = get_corner_level(corner_level[1], corner_level[3])
        corner_levels[index] = modlib.vector.subtract_scalar(modlib.vector.new(corner_level), 0.5)
    end
    return corner_levels
end

flowing_downwards = modlib.vector.new{0, -1, 0}
--+ Calculates the flow direction of a flowingliquid node
--> `modlib.minetest.flowing_downwards = modlib.vector.new{0, -1, 0}` if only flowing downwards
--> surface direction as `modlib.vector` else
function get_liquid_flow_direction(pos)
    local corner_levels = get_liquid_corner_levels(pos)
    local max_level = corner_levels[1][2]
    for index = 2, 4 do
        local level = corner_levels[index][2]
        if level > max_level then
            max_level = level
        end
    end
    local dir = modlib.vector.new{0, 0, 0}
    local count = 0
    for max_level_index, corner_level in pairs(corner_levels) do
        if corner_level[2] == max_level then
            for offset = 1, 3 do
                local index = (max_level_index + offset - 1) % 4 + 1
                local diff = corner_level - corner_levels[index]
                if diff[2] ~= 0 then
                    diff[1] = diff[1] * diff[2]
                    diff[3] = diff[3] * diff[2]
                    if offset == 3 then
                        diff = modlib.vector.divide_scalar(diff, math.sqrt(2))
                    end
                    dir = dir + diff
                    count = count + 1
                end
            end
        end
    end
    if count ~= 0 then
        dir = modlib.vector.divide_scalar(dir, count)
    end
    if dir == modlib.vector.new{0, 0, 0} then
        if minetest.get_node(pos).param2 % 32 > 7 then
            return flowing_downwards
        end
    end
    return dir
end

--+ Raycast wrapper with proper flowingliquid intersections
function raycast(_pos1, _pos2, objects, liquids)
    local raycast = minetest.raycast(_pos1, _pos2, objects, liquids)
    if not liquids then
        return raycast
    end
    local pos1 = modlib.vector.from_minetest(_pos1)
    local _direction = vector.direction(_pos1, _pos2)
    local direction = modlib.vector.from_minetest(_direction)
    local length = vector.distance(_pos1, _pos2)
    local function next()
        for pointed_thing in raycast do
            if pointed_thing.type ~= "node" then
                return pointed_thing
            end
            local _pos = pointed_thing.under
            local pos = modlib.vector.from_minetest(_pos)
            local node = minetest.get_node(_pos)
            local def = minetest.registered_nodes[node.name]
            if not (def and def.drawtype == "flowingliquid") then return pointed_thing end
            local corner_levels = get_liquid_corner_levels(_pos)
            local full_corner_levels = true
            for _, corner_level in pairs(corner_levels) do
                if corner_level[2] < 0.5 then
                    full_corner_levels = false
                    break
                end
            end
            if full_corner_levels then
                return pointed_thing
            end
            local relative = pos1 - pos
            local inside = true
            for _, prop in pairs(relative) do
                if prop <= -0.5 or prop >= 0.5 then
                    inside = false
                    break
                end
            end
            local function level(x, z)
                local function distance_squared(corner)
                    return (x - corner[1]) ^ 2 + (z - corner[3]) ^ 2
                end
                local irrelevant_corner, distance = 1, distance_squared(corner_levels[1])
                for index = 2, 4 do
                    local other_distance = distance_squared(corner_levels[index])
                    if other_distance > distance then
                        irrelevant_corner, distance = index, other_distance
                    end
                end
                local function corner(off)
                    return corner_levels[((irrelevant_corner + off) % 4) + 1]
                end
                local base = corner(2)
                local edge_1, edge_2 = corner(1) - base, corner(3) - base
                -- Properly selected edges will have a total length of 2
                assert(math.abs(edge_1[1] + edge_1[3]) + math.abs(edge_2[1] + edge_2[3]) == 2)
                if edge_1[1] == 0 then
                    edge_1, edge_2 = edge_2, edge_1
                end
                local level = base[2] + (edge_1[2] * ((x - base[1]) / edge_1[1])) + (edge_2[2] * ((z - base[3]) / edge_2[3]))
                assert(level >= -0.5 and level <= 0.5)
                return level
            end
            inside = inside and (relative[2] < level(relative[1], relative[3]))
            if inside then
                -- pos1 is inside the liquid node
                pointed_thing.intersection_point = _pos1
                pointed_thing.intersection_normal = vector.new(0, 0, 0)
                return pointed_thing
            end
            local function intersection_normal(axis, dir)
                return {x = 0, y = 0, z = 0, [axis] = dir}
            end
            local function plane(axis, dir)
                local offset = dir * 0.5
                local diff_axis = (relative[axis] - offset) / -direction[axis]
                local intersection_point = {}
                for plane_axis = 1, 3 do
                    if plane_axis ~= axis then
                        local value = direction[plane_axis] * diff_axis + relative[plane_axis]
                        if value < -0.5 or value > 0.5 then
                            return
                        end
                        intersection_point[plane_axis] = value
                    end
                end
                intersection_point[axis] = offset
                return intersection_point
            end
            if direction[2] > 0 then
                local intersection_point = plane(2, -1)
                if intersection_point then
                    pointed_thing.intersection_point = (intersection_point + pos):to_minetest()
                    pointed_thing.intersection_normal = intersection_normal("y", -1)
                    return pointed_thing
                end
            end
            for coord, other in pairs{[1] = 3, [3] = 1} do
                if direction[coord] ~= 0 then
                    local dir = direction[coord] > 0 and -1 or 1
                    local intersection_point = plane(coord, dir)
                    if intersection_point then
                        local height = 0
                        for _, corner in pairs(corner_levels) do
                            if corner[coord] == dir * 0.5 then
                                height = height + (math.abs(intersection_point[other] + corner[other])) * corner[2]
                            end
                        end
                        if intersection_point[2] <= height then
                            pointed_thing.intersection_point = (intersection_point + pos):to_minetest()
                            pointed_thing.intersection_normal = intersection_normal(modlib.vector.index_aliases[coord], dir)
                            return pointed_thing
                        end
                    end
                end
            end
            for _, triangle in pairs{
                {corner_levels[3], corner_levels[2], corner_levels[1]},
                {corner_levels[4], corner_levels[3], corner_levels[1]}
            } do
                local pos_on_ray = modlib.vector.ray_triangle_intersection(relative, direction, triangle)
                if pos_on_ray and pos_on_ray <= length then
                    pointed_thing.intersection_point = (pos1 + modlib.vector.multiply_scalar(direction, pos_on_ray)):to_minetest()
                    pointed_thing.intersection_normal = modlib.vector.triangle_normal(triangle):to_minetest()
                    return pointed_thing
                end
            end
        end
    end
    return setmetatable({next = next}, {__call = next})
end

players = {}

registered_on_wielditem_changes = {function(...)
    local _, previous_item, _, item = ...
    if previous_item then
        ((previous_item:get_definition()._modlib or {}).un_wield or modlib.func.no_op)(...)
    end
    if item then
        ((item:get_definition()._modlib or {}).on_wield or modlib.func.no_op)(...)
    end
end}

--+ Registers an on_wielditem_change callback: function(player, previous_item, previous_index, item)
--+ Will be called once with player, nil, index, item on join
register_on_wielditem_change = modlib.func.curry(table.insert, registered_on_wielditem_changes)

minetest.register_on_mods_loaded(function()
    -- Other on_joinplayer / on_leaveplayer callbacks should execute first
    minetest.register_on_joinplayer(function(player)
        local item, index = player:get_wielded_item(), player:get_wield_index()
        players[player:get_player_name()] = {
            wield = {
                item = item,
                index = index
            }
        }
        modlib.table.icall(registered_on_wielditem_changes, player, nil, index, item)
    end)
    minetest.register_on_leaveplayer(function(player)
        players[player:get_player_name()] = nil
    end)
end)

minetest.register_globalstep(function()
    for _, player in pairs(minetest.get_connected_players()) do
        local item, index = player:get_wielded_item(), player:get_wield_index()
        local playerdata = players[player:get_player_name()]
        local previous_item, previous_index = playerdata.wield.item, playerdata.wield.index
        if item:get_name() ~= previous_item or index ~= previous_index then
            playerdata.wield.item = item
            playerdata.wield.index = index
            modlib.table.icall(registered_on_wielditem_changes, player, previous_item, previous_index, item)
        end
    end
end)

-- As in src/util/string.cpp
named_colors = {
	aliceblue = 0xf0f8ff,
	antiquewhite = 0xfaebd7,
	aqua = 0x00ffff,
	aquamarine = 0x7fffd4,
	azure = 0xf0ffff,
	beige = 0xf5f5dc,
	bisque = 0xffe4c4,
	black = 0x000000,
	blanchedalmond = 0xffebcd,
	blue = 0x0000ff,
	blueviolet = 0x8a2be2,
	brown = 0xa52a2a,
	burlywood = 0xdeb887,
	cadetblue = 0x5f9ea0,
	chartreuse = 0x7fff00,
	chocolate = 0xd2691e,
	coral = 0xff7f50,
	cornflowerblue = 0x6495ed,
	cornsilk = 0xfff8dc,
	crimson = 0xdc143c,
	cyan = 0x00ffff,
	darkblue = 0x00008b,
	darkcyan = 0x008b8b,
	darkgoldenrod = 0xb8860b,
	darkgray = 0xa9a9a9,
	darkgreen = 0x006400,
	darkgrey = 0xa9a9a9,
	darkkhaki = 0xbdb76b,
	darkmagenta = 0x8b008b,
	darkolivegreen = 0x556b2f,
	darkorange = 0xff8c00,
	darkorchid = 0x9932cc,
	darkred = 0x8b0000,
	darksalmon = 0xe9967a,
	darkseagreen = 0x8fbc8f,
	darkslateblue = 0x483d8b,
	darkslategray = 0x2f4f4f,
	darkslategrey = 0x2f4f4f,
	darkturquoise = 0x00ced1,
	darkviolet = 0x9400d3,
	deeppink = 0xff1493,
	deepskyblue = 0x00bfff,
	dimgray = 0x696969,
	dimgrey = 0x696969,
	dodgerblue = 0x1e90ff,
	firebrick = 0xb22222,
	floralwhite = 0xfffaf0,
	forestgreen = 0x228b22,
	fuchsia = 0xff00ff,
	gainsboro = 0xdcdcdc,
	ghostwhite = 0xf8f8ff,
	gold = 0xffd700,
	goldenrod = 0xdaa520,
	gray = 0x808080,
	green = 0x008000,
	greenyellow = 0xadff2f,
	grey = 0x808080,
	honeydew = 0xf0fff0,
	hotpink = 0xff69b4,
	indianred = 0xcd5c5c,
	indigo = 0x4b0082,
	ivory = 0xfffff0,
	khaki = 0xf0e68c,
	lavender = 0xe6e6fa,
	lavenderblush = 0xfff0f5,
	lawngreen = 0x7cfc00,
	lemonchiffon = 0xfffacd,
	lightblue = 0xadd8e6,
	lightcoral = 0xf08080,
	lightcyan = 0xe0ffff,
	lightgoldenrodyellow = 0xfafad2,
	lightgray = 0xd3d3d3,
	lightgreen = 0x90ee90,
	lightgrey = 0xd3d3d3,
	lightpink = 0xffb6c1,
	lightsalmon = 0xffa07a,
	lightseagreen = 0x20b2aa,
	lightskyblue = 0x87cefa,
	lightslategray = 0x778899,
	lightslategrey = 0x778899,
	lightsteelblue = 0xb0c4de,
	lightyellow = 0xffffe0,
	lime = 0x00ff00,
	limegreen = 0x32cd32,
	linen = 0xfaf0e6,
	magenta = 0xff00ff,
	maroon = 0x800000,
	mediumaquamarine = 0x66cdaa,
	mediumblue = 0x0000cd,
	mediumorchid = 0xba55d3,
	mediumpurple = 0x9370db,
	mediumseagreen = 0x3cb371,
	mediumslateblue = 0x7b68ee,
	mediumspringgreen = 0x00fa9a,
	mediumturquoise = 0x48d1cc,
	mediumvioletred = 0xc71585,
	midnightblue = 0x191970,
	mintcream = 0xf5fffa,
	mistyrose = 0xffe4e1,
	moccasin = 0xffe4b5,
	navajowhite = 0xffdead,
	navy = 0x000080,
	oldlace = 0xfdf5e6,
	olive = 0x808000,
	olivedrab = 0x6b8e23,
	orange = 0xffa500,
	orangered = 0xff4500,
	orchid = 0xda70d6,
	palegoldenrod = 0xeee8aa,
	palegreen = 0x98fb98,
	paleturquoise = 0xafeeee,
	palevioletred = 0xdb7093,
	papayawhip = 0xffefd5,
	peachpuff = 0xffdab9,
	peru = 0xcd853f,
	pink = 0xffc0cb,
	plum = 0xdda0dd,
	powderblue = 0xb0e0e6,
	purple = 0x800080,
	red = 0xff0000,
	rosybrown = 0xbc8f8f,
	royalblue = 0x4169e1,
	saddlebrown = 0x8b4513,
	salmon = 0xfa8072,
	sandybrown = 0xf4a460,
	seagreen = 0x2e8b57,
	seashell = 0xfff5ee,
	sienna = 0xa0522d,
	silver = 0xc0c0c0,
	skyblue = 0x87ceeb,
	slateblue = 0x6a5acd,
	slategray = 0x708090,
	slategrey = 0x708090,
	snow = 0xfffafa,
	springgreen = 0x00ff7f,
	steelblue = 0x4682b4,
	tan = 0xd2b48c,
	teal = 0x008080,
	thistle = 0xd8bfd8,
	tomato = 0xff6347,
	turquoise = 0x40e0d0,
	violet = 0xee82ee,
	wheat = 0xf5deb3,
	white = 0xffffff,
	whitesmoke = 0xf5f5f5,
	yellow = 0xffff00,
	yellowgreen = 0x9acd32
}

colorspec = {}

local colorspec_metatable = {__index = colorspec}

function colorspec.new(table)
    return setmetatable({
        r = assert(table.r),
        g = assert(table.g),
        b = assert(table.b),
        a = table.a or 255
    }, colorspec_metatable)
end

colorspec.from_table = colorspec.new

function colorspec.from_string(string)
    local hex = "#([A-Fa-f%d])+"
    local number, alpha = named_colors[string], 0xFF
    if not number then
        local name, alpha_text = string:match("^([a-z])+" .. hex .. "$")
        assert(alpha_text:len() == 2)
        number = assert(named_colors[name])
        alpha = tonumber(alpha_text, 16)
    end
    if number then
        return colorspec.from_number(number * 0xFF + alpha)
    end
    local hex_text = string:match(hex)
    local len, num = hex_text:len(), tonumber(hex_text, 16)
    if len == 8 then
        return colorspec.from_number(num)
    end
    if len == 6 then
        return colorspec.from_number(num * 0xFF + 0xFF)
    end
    local floor = math.floor
    if len == 4 then
        return colorspec.from_table{
            a = (num % 16) * 17,
            b = (floor(num / 16) % 16) * 17,
            g = (floor(num / (16 ^ 2)) % 16) * 17,
            r = (floor(num / (16 ^ 3)) % 16) * 17
        }
    end
    if len == 3 then
        return colorspec.from_table{
            b = (num % 16) * 17,
            g = (floor(num / 16) % 16) * 17,
            r = (floor(num / (16 ^ 2)) % 16) * 17
        }
    end
    error("Invalid colorstring: " .. string)
end

colorspec.from_text = colorspec.from_string

function colorspec.from_number(number)
    local floor = math.floor
    return colorspec.from_table{
        a = number % 0xFF,
        b = floor(number / 0xFF) % 0xFF,
        g = floor(number / 0xFFFF) % 0xFF,
        r = floor(number / 0xFFFFFF)
    }
end

function colorspec.from_any(value)
    local type = type(value)
    if type == "table" then
        return colorspec.from_table(value)
    end
    if type == "string" then
        return colorspec.from_string(value)
    end
    if type == "number" then
        return colorspec.from_number(value)
    end
    error("Unsupported type " .. type)
end

function colorspec:to_table()
    return self
end

--> hex string, omits alpha if possible (if opaque)
function colorspec:to_string()
    if self.a == 255 then
        return ("%02X02X02X"):format(self.r, self.g, self.b)
    end
    return ("%02X02X02X02X"):format(self.r, self.g, self.b, self.a)
end

function colorspec:to_number()
    return self.r * 0xFFFFFF + self.g * 0xFFFF + self.b * 0xFF + self.a
end

colorspec_to_colorstring = _G.minetest.colorspec_to_colorstring or function(spec)
    return colorspec.from_any(spec):to_string()
end

write_schematic = function(fil) end
-- TODO schematic format