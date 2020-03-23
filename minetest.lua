-- MT extension
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