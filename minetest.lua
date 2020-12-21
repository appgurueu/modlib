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
--+ Calculates the flow direction of a flowingliquid node
--# as returned by `minetest.get_node`
--> 4 corner levels from -0.5 to 0.5 as list
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
        {x = 0, z = 0},
        {x = 1, z = 0},
        {x = 1, z = 1},
        {x = 0, z = 1}
    }
    for _, corner_level in pairs(corner_levels) do
        corner_level.y = get_corner_level(corner_level.x, corner_level.z) - 0.5
        corner_level.x, corner_level.z = corner_level.x - 0.5, corner_level.z - 0.5
    end
    return corner_levels
end

flowing_downwards = vector.new(0, -1, 0)
--+ Calculates the flow direction of a flowingliquid node
--# as returned by `minetest.get_node`
--> `modlib.minetest.flowing_downwards = vector.new(0, -1, 0)` if only flowing downwards
--> surface direction as `vector` else
function get_liquid_flow_direction(pos)
    local corner_levels = get_liquid_corner_levels(pos)
    local max_level = corner_levels[1].y
    for index = 2, 4 do
        local level = corner_levels[index].y
        if level > max_level then
            max_level = level
        end
    end
    local dir = vector.new(0, 0, 0)
    local count = 0
    for max_level_index, corner_level in pairs(corner_levels) do
        if corner_level.y == max_level then
            for offset = 1, 3 do
                local index = (max_level_index + offset - 1) % 4 + 1
                local diff = vector.subtract(corner_level, corner_levels[index])
                if diff.y ~= 0 then
                    diff.x = diff.x * diff.y
                    diff.z = diff.z * diff.y
                    if offset == 3 then
                        diff = vector.divide(diff, math.sqrt(2))
                    end
                    dir = vector.add(dir, diff)
                    count = count + 1
                end
            end
        end
    end
    if count ~= 0 then
        dir = vector.divide(dir, count)
    end
    if vector.equals(dir, vector.new(0, 0, 0)) then
        if node.param2 % 32 > 7 then
            return flowing_downwards
        end
    end
    return dir
end

--+ Raycast wrapper with proper flowingliquid intersections
function raycast(pos1, pos2, objects, liquids)
    local raycast = minetest.raycast(pos1, pos2, objects, liquids)
    if not liquids then
        return raycast
    end
    local direction = vector.direction(pos1, pos2)
    local length = vector.distance(pos1, pos2)
    local function next()
        for pointed_thing in raycast do
            if pointed_thing.type ~= "node" then
                return pointed_thing
            end
            local pos = pointed_thing.under
            local node = minetest.get_node(pos)
            local def = minetest.registered_nodes[node.name]
            if not (def and def.drawtype == "flowingliquid") then return pointed_thing end
            local corner_levels = get_liquid_corner_levels(pos)
            local full_corner_levels = true
            for _, corner_level in pairs(corner_levels) do
                if corner_level.y < 0.5 then
                    full_corner_levels = false
                    break
                end
            end
            if full_corner_levels then
                return pointed_thing
            end
            -- origin = pos
            local relative = vector.subtract(pos1, pos)
            local inside = true
            for _, prop in pairs(relative) do
                if prop <= -0.5 or prop >= 0.5 then
                    inside = false
                    break
                end
            end
            local function level(x, z)
                local function distance_squared(corner)
                    return (x - corner.x) ^ 2 + (z - corner.z) ^ 2
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
                local edge_1, edge_2 = vector.subtract(corner(1), base), vector.subtract(corner(3), base)
                assert(math.abs(edge_1.x + edge_1.z) + math.abs(edge_2.x + edge_2.z) == 2)
                if edge_1.x == 0 then
                    edge_1, edge_2 = edge_2, edge_1
                end
                local level = base.y + (edge_1.y * ((x - base.x) / edge_1.x)) + (edge_2.y * ((z - base.z) / edge_2.z))
                assert(level >= -0.5 and level <= 0.5)
                return level
            end
            inside = inside and (relative.y < level(relative.x, relative.z))
            if inside then
                -- pos1 is inside the liquid node
                pointed_thing.intersection_point = pos1
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
                for plane_axis in pairs{x = true, y = true, z = true, [axis] = nil} do
                    local value = direction[plane_axis] * diff_axis + relative[plane_axis]
                    if value < -0.5 or value > 0.5 then
                        return
                    end
                    intersection_point[plane_axis] = value
                end
                intersection_point[axis] = offset
                return intersection_point
            end
            if direction.y > 0 then
                local intersection_point = plane("y", -1)
                if intersection_point then
                    pointed_thing.intersection_point = vector.add(intersection_point, pos)
                    pointed_thing.intersection_normal = intersection_normal("y", -1)
                    return pointed_thing
                end
            end
            for coord, other in pairs{x = "z", z = "x"} do
                if direction[coord] ~= 0 then
                    local dir = direction[coord] > 0 and -1 or 1
                    local intersection_point = plane(coord, dir)
                    if intersection_point then
                        local height = 0
                        for _, corner in pairs(corner_levels) do
                            if corner[coord] == dir * 0.5 then
                                height = height + (math.abs(intersection_point[other] + corner[other])) * corner.y
                            end
                        end
                        if intersection_point.y <= height then
                            pointed_thing.intersection_point = vector.add(intersection_point, pos)
                            pointed_thing.intersection_normal = intersection_normal(coord, dir)
                            return pointed_thing
                        end
                    end
                end
            end
            for _, triangle in pairs{
                {corner_levels[1], corner_levels[2], corner_levels[3]},
                {corner_levels[1], corner_levels[3], corner_levels[4]}
            } do
                local pos_on_ray = modlib.vector.ray_triangle_intersection(relative, direction, triangle)
                if pos_on_ray and pos_on_ray <= length then
                    pointed_thing.intersection_point = vector.add(pos1, vector.multiply(direction, pos_on_ray))
                    pointed_thing.intersection_normal = vector.multiply(modlib.vector.triangle_normal(triangle), -1)
                    return pointed_thing
                end
            end
        end
    end
    return setmetatable({next = next}, {__call = next})
end