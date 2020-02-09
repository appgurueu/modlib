forbidden_names={"me"}
register_forbidden_name=function(name)
    forbidden_names[name]=true
end
unregister_forbidden_name=function(name)
    forbidden_names[name]=nil
end
playerdata = {}
defaults={}
playerdata_functions={}
delete_player_data=function(playername)
    playerdata[playername]=nil
end
create_player_data=function(playername)
    playerdata[playername]={}
end
init_player_data=function(playername)
    modlib.table.add_all(playerdata[playername], defaults)
    for _, callback in ipairs(playerdata_functions) do
        callback(playerdata[playername])
    end
end
get_player_data=function(playername)
    return playerdata[playername]
end
get_property =function(playername, propertyname)
    return get_player_data(playername)[propertyname]
end
set_property =function(playername, propertyname, propertyvalue)
    get_player_data(playername)[propertyname]=propertyvalue
end
get_property_default =function(propertyname)
    return defaults[propertyname]
end
set_property_default =function(propertyname, defaultvalue)
    defaults[propertyname]=defaultvalue
end
add_playerdata_function=function(callback)
    table.insert(playerdata_functions, callback)
end
get_color=function(player)
    local sender_color=player:get_properties().nametag_color
    if sender_color then
        sender_color = minetest.rgba(sender_color.r, sender_color.g, sender_color.b)
    else
        sender_color="#FFFFFF"
    end
    return sender_color
end
get_color_table=function(player)
    local sender_color=player:get_properties().nametag_color
    return sender_color or {r=255, g=255, b=255}
end
get_color_int=function(player)
    local sender_color=player:get_properties().nametag_color
    if sender_color then
        sender_color = sender_color.b + (sender_color.g*256) + (sender_color.r*256*256)
    else
        sender_color=0xFFFFFF
    end
    return sender_color
end

minetest.register_on_prejoinplayer(function(name, ip)
    if forbidden_names[name] then
        return "The name '"..name.."' is already used in the game and thus not allowed as playername."
    end
end )

minetest.register_on_joinplayer(function(player)
    local playername=player:get_player_name()
    create_player_data(playername)
    init_player_data(playername)
end)

minetest.register_on_leaveplayer(function(player)
    local playername=player:get_player_name()
    delete_player_data(playername)
end)
