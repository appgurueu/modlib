max_wear = math.pow(2, 16) - 1
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

function box_box_collision(a, b)
    for i=1, 3 do
        if a[i] < (b[i] + b[i+3]) or b[i] < (a[i] + a[i+3]) then
            return false
        end
    end
    return true
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
