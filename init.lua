-- Error override - TODO discuss about silent errors

-- Lua version check
if _VERSION then
    if _VERSION < "Lua 5" then
        error("Outdated Lua version ! modlib requires Lua 5 or greater.")
    end
    if _VERSION > "Lua 5.1" then
        error("Too new Lua version ! modlib requires Lua 5.1 or smaller.")
    end
end

-- MT shorthands
for k, v in pairs(minetest) do
    print(k.." : "..type(v))
end
mt=minetest
mt.version=minetest.get_version()

if mt.version.project == "Minetest" then
    if mt.version.string < "0.4" then
        error("Outdated Minetest version ! modlib requires Minetest 0.4 or greater.")
    end
    if mt.version.string > "5.1" then
        error("Too new Minetest version ! modlib requires Minetest 5.1 or smaller.")
    end
else
    error("No Minetest provided ! Modlib requires Minetest instead of "..mt.version.project..".")
end

MT=mt

-- MT extension
-- TODO add formspec queues and event system + sync handler
-- TODO add chatcommand helper

mt_ext = {
    delta_times={},
    delays={},
    callbacks={},
    register_globalstep=function(interval, callback)
        if type(callback) ~= "function" then
            return
        end
        table.insert(mt_ext.delta_times, 0)
        table.insert(mt_ext.delays, interval)
        table.insert(mt_ext.callbacks, callback)
    end,
    texture_modifier_inventorycube=function(face_1, face_2, face_3)
        return "[inventorycube{" .. string.gsub(face_1, "%^", "&")
                .. "{" .. string.gsub(face_2, "%^", "&")
                .. "{" .. string.gsub(face_3, "%^", "&")
    end,
    get_node_inventory_image=function(nodename)
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
        return img or mt_ext.texture_modifier_inventorycube(chosen_tiles[1], chosen_tiles[2], chosen_tiles[3])
    end,
    get_color_int=function(color)
        return color.b + (color.g*256) + (color.r*256*256)
    end
}

minetest.register_globalstep(function(dtime)
    for k, v in pairs(mt_ext.delta_times) do
        local v=dtime+v
        if v > mt_ext.delays[k] then
            mt_ext.callbacks[k](v)
            v=0
        end
        mt_ext.delta_times[k]=v
    end
end)

-- Chatcommand Extension

cmd_ext = {
    -- TODO register chatcommand - constraint checking, automatic call with parameters, automatic reject in case of missing parameters or stuff liek t'is
    register_chatcommand=function(name, def)
    end
}

-- Player specific values

player_ext = {
    forbidden_names={},
    register_forbidden_name=function(name)
        player_ext.forbidden_names[name]=true
    end,
    unregister_forbidden_name=function(name)
        player_ext.forbidden_names[name]=nil
    end,
    playerdata = {},
    defaults={},
    playerdata_functions={},
    delete_player_data=function(playername)
        player_ext.playerdata[playername]=nil
    end,
    create_player_data=function(playername)
        player_ext.playerdata[playername]={}
    end,
    init_player_data=function(playername)
        table_ext.add_all(player_ext.playerdata[playername], player_ext.defaults)
        for _, callback in ipairs(player_ext.playerdata_functions) do
            callback(player_ext.playerdata[playername])
        end
    end,
    get_player_data=function(playername)
        return player_ext.playerdata[playername]
    end,
    get_property =function(playername, propertyname)
        return player_ext.get_player_data(playername)[propertyname]
    end,
    set_property =function(playername, propertyname, propertyvalue)
        player_ext.get_player_data(playername)[propertyname]=propertyvalue
    end,
    get_property_default =function(propertyname)
        return player_ext.defaults[propertyname]
    end,
    set_property_default =function(propertyname, defaultvalue)
        player_ext.defaults[propertyname]=defaultvalue
    end,
    add_playerdata_function=function(callback)
        table.insert(player_ext.playerdata_functions, callback)
    end,
    get_color=function(player)
        local sender_color=player:get_properties().nametag_color
        if sender_color then
            sender_color = minetest.rgba(sender_color.r, sender_color.g, sender_color.b)
        else
            sender_color="#FFFFFF"
        end
        return sender_color
    end,
    get_color_int=function(player)
        local sender_color=player:get_properties().nametag_color
        if sender_color then
            sender_color = sender_color.b + (sender_color.g*256) + (sender_color.r*256*256)
        else
            sender_color=0xFFFFFF
        end
        return sender_color
    end
}

-- TODO mt.register on prenewplayer - check for disallowed playernames

minetest.register_on_joinplayer(function(player)
    local playername=player:get_player_name()
    player_ext.create_player_data(playername)
    player_ext.init_player_data(playername)
end)

minetest.register_on_leaveplayer(function(player)
    local playername=player:get_player_name()
    player_ext.delete_player_data(playername)
end)

-- TODO code 'em
-- OOP helpers

class={
    classes={},
    define=function(name, def)
        if def.extends then
            setmetatable(def, class.get(def.extends))
        end
        class.classes[name]=def
    end,
    new=function(classname, ...)
        local obj=class.get(classname).new(...)
        obj=setmetatable(obj, {__index=class.classes[classname]}) -- TODO ? metatable add __call with setfenv
        return obj
    end,
    get=function(classname)
        return class.classes[classname]
    end,
    call=function(classname, funcname, object, ...)
        if object then
            setfenv(1, object)
            class.get(classname)[funcname](object,...)
        else
            setfenv(1, class.classes[classname])
            class.get(classname)[funcname](...)
        end
        setfenv(1, _G)
    end
}

-- Table helpers
table_ext= {

    tablecopy = function(t)
        return table.copy(t)
    end,

    count = function(table)
        local count = 0
        for _ in pairs(table) do
            count = count + 1
        end
        return count
    end,

    is_empty = function(table)
        return next(table) == nil
    end,

    map = function(t, func)
        for k, v in pairs(t) do
            t[k]=func(v)
        end
    end,

    process = function(t, func)
        local r={}
        for k, v in pairs(t) do
            table.insert(r, func(k,v))
        end
        return r
    end,

    call=function(funcs, ...)
        for _, func in ipairs(funcs) do
            func(unpack(arg))
        end
    end,

    merge_tables = function(table1, table2)
        local table1copy = table.copy(table1)
        for key, value in pairs(table2) do
            table1copy[key] = value
        end
        return table1copy
    end,

    difference=function(table1, table2)
        local result={}
        for k, v in pairs(table2) do
            local v2=table1[v]
            if v2~=v then
                result[k]=v
            end
        end
        return result
    end,

    add_all=function(dst, new)
        for key, value in pairs(new) do
            dst[key] = value
        end
        return dst
    end,

    keys = function(t)
        local keys = {}
        for key, _ in pairs(t) do
            table.insert(keys, key)
        end
        return keys
    end,

    values = function(t)
        local values = {}
        for key, _ in pairs(t) do
            table.insert(values, key)
        end
        return values
    end,

    flip = function(table)
        local flipped = {}
        for key, val in pairs(table) do
            flipped[val] = key
        end
        return flipped
    end,

    unique = function(table)
        local lookup = {}
        for val in ipairs(table) do
            lookup[val] = true
        end
        return table_ext.keys(lookup)
    end,

    rpairs=function(t)
        local i = #t
        return function ()
            if i >= 1 then
                local v=t[i]
                i = i-1
                if v then
                    return i+1, v
                end
            end
        end
    end,

    best_value=function(table, is_better_fnc)
        if not table or not is_better_fnc then
            return nil
        end
        local l=#table
        if l==0 then
            return nil
        end
        local m=table[1]
        for i=2, l do
            local v=table[i]
            if is_better_fnc(v, m) then
                m=v
            end
        end
        return m
    end,

    min = function(table)
        return table_ext.best_value(table, function(v, m) return v < m end)
    end,

    max = function(table)
        return table_ext.best_value(table, function(v, m) return v > m end)
    end
}

-- Number helpers - currently only round
number_ext={
    round=function (number, steps) --Rounds a number
        steps=steps or 1
        return math.floor(number*steps+0.5)/steps
    end
}

-- String helpers - split & trim at end & begin
string_ext={
    trim=function(str, to_remove)

        local j=1
        for i=1, string.len(str) do
            if str:sub(i,i) ~= to_remove then
                j=i
                break
            end
        end

        local k=1
        for i=string.len(str),j,-1 do
            if str:sub(i,i) ~= to_remove then
                k=i
                break
            end
        end

        return str:sub(j,k)
    end,

    trim_begin=function(str, to_remove)

        local j=1
        for i=1, string.len(str) do
            if str:sub(i,i) ~= to_remove then
                j=i
                break
            end
        end

        return str:sub(j)
    end,

    split=function(str, delim, limit)
        local parts={}
        local occurences=1
        local last_index=1
        local index=string.find(str, delim)
        while index and occurences < limit do
            table.insert(parts, string.sub(str, last_index, index-1))
            last_index=index+string.len(delim)
            index=string.find(str, delim, index+string.len(delim))
            occurences=occurences+1
        end
        table.insert(parts, string.sub(str, last_index))
        return parts
    end,

    hashtag=string.byte("#"),
    zero=string.byte("0"),
    nine=string.byte("9"),
    letter_a=string.byte("A"),
    letter_f=string.byte("F"),

    is_hexadecimal=function(byte)
        return (byte >= string_ext.zero and byte <= string_ext.nine) or (byte >= string_ext.letter_a and byte <= string_ext.letter_f)
    end
}

-- File helpers - reading, writing, appending, exists, create_if_not_exists
file_ext={
    read=function(filename)
        local file=io.open(filename,"r")
        if file==nil then
            return nil
        end
        local content=file:read("*a")
        file:close()
        return content
    end,
    write=function(filename, new_content)
        local file=io.open(filename,"w")
        if file==nil then
            return false
        end
        file:write(new_content)
        file:close()
        return true
    end,
    append=function(filename, new_content)
        local file=io.open(filename,"a")
        if file==nil then
            return false
        end
        file:write(new_content)
        file:close()
        return true
    end,
    exists=function(filename)
        local file=io.open(filename, "r")
        if file==nil then
            return false
        end
        file:close()
        return true
    end,
    create_if_not_exists=function(filename, content)
        if not file_ext.exists(filename) then
            file_ext.write(filename, content)
            return true
        end
        return false
    end,
    create_if_not_exists_from_file=function(filename, src_filename)
        return file_ext.create_if_not_exists(filename, file_ext.read(src_filename))
    end
}

-- Minetest related helpers --

-- get modpath wrapper
function get_resource(modname, resource)
    return minetest.get_modpath(modname).."/"..resource
end

-- get resource + dofile
function include(modname, file)
    dofile(get_resource(modname, file))
end

-- dofile with table env
function include_class(classname, filename)
    local file=io.open(filename, "r")
    local class=classname.."={_G=_G, G=_G}\nsetfenv(1,setmetatable("..classname..", {__index=_G, __call=_G}))\n"..file:read("*a").."\n"
    local fnc=assert(loadstring(class))
    fnc()
    file:close()
end

-- runs main.lua in table env
function include_mod(modname, config_constraints)
    include_class(modname, get_resource(modname,"main.lua"))
    if config_constraints then

    end
end

function extend_mod(modname, filename)
    local file=io.open(get_resource(modname,filename..".lua"), "r")
    local class="setfenv(1,setmetatable("..modname..", {__index=_G, __call=_G}))\n"..file:read("*a").."\n"
    local fnc=assert(loadstring(class))
    fnc()
    file:close()
end

-- Data helpers - load data, save data...
minetest.mkdir(minetest.get_worldpath().."/data")
data={
    create_mod_storage=function(modname)
        minetest.mkdir(minetest.get_worldpath().."/data/"..modname)
    end,
    get_path=function(modname, filename)
        return minetest.get_worldpath().."/data/"..modname.."/"..filename
    end,
    load=function(modname, filename)
        return minetest.deserialize(file_ext.read(data.get_path(modname, filename)..".lua"))
    end,
    save=function(modname, filename, stuff)
        return file_ext.write(data.get_path(modname, filename)..".lua", minetest.serialize(stuff))
    end,
    load_json =function(modname, filename)
        return minetest.parse_json(file_ext.read(data.get_path(modname, filename)..".json"))
    end,
    save_json=function(modname, filename, stuff)
        return file_ext.write(data.get_path(modname, filename)..".json", minetest.write_json(stuff))
    end
}

-- Configuration helpers - load config, check constraints
minetest.mkdir(minetest.get_worldpath().."/config")
conf={
    get_path=function(confname)
        return minetest.get_worldpath().."/config/"..confname
    end,
    load=function (filename, constraints)
        local config=minetest.parse_json(file_ext.read(filename))
        if constraints then
            local error_message=conf.check_constraints(config, constraints)
            if error_message then
                error("Configuration - "..filename.." doesn't satisfy constraints : "..error_message)
            end
        end
        return config
    end,
    load_or_create=function(filename, replacement_file, constraints)
        file_ext.create_if_not_exists_from_file(filename, replacement_file)
        return conf.load(filename, constraints)
    end,
    import=function(modname,constraints)
        return conf.load_or_create(conf.get_path(modname)..".json",get_resource(modname, "default_config.json"),constraints)
    end,
    check_constraints=function(value, constraints)
        local t=type(value)
        if constraints.func then
            local possible_errors=constraints.func(value)
            if possible_errors then
                return possible_errors
            end
        end
        if constraints.type and constraints.type~=t then
            return "Wrong type : Expected "..constraints.type..", found "..t
        end
        if (t == "number" or t == "string") and constraints.range then
            if value < constraints.range[1] or (constraints.range[2] and value > constraints.range[2]) then
                return "Not inside range : Expected value >= "..constraints.range[1].." and <= "..constraints.range[1]..", found "..minetest.write_json(value)
            end
        end
        if constraints.possible_values and not constraints.possible_values[value] then
            return "None of the possible values : Expected one of "..minetest.write_json(table_ext.keys(constraints.possible_values))..", found "..minetest.write_json(value)
        end
        if t == "table" then
            if constraints.children then
                for k, v in pairs(value) do
                    local child=constraints.children[k]
                    if not child then
                        return "Unexpected table entry : Expected one of "..minetest.write_json(table_ext.keys(constraints.children))..", found "..minetest.write_json(k)
                    else
                        local possible_errors=conf.check_constraints(v, child)
                        if possible_errors then
                            return possible_errors
                        end
                    end
                end
                for k, _ in pairs(constraints.children) do
                    if value[k] == nil then
                        return "Table entry missing : Expected key "..minetest.write_json(k).." to be present in table "..minetest.write_json(value)
                    end
                end
            end
            if constraints.keys then
                for k,_ in pairs(value) do
                    local possible_errors=conf.check_constraints(k, constraints.keys)
                    if possible_errors then
                        return possible_errors
                    end
                end
            end
            if constraints.values then
                for _,v in pairs(value) do
                    local possible_errors=conf.check_constraints(v, constraints.values)
                    if possible_errors then
                        return possible_errors
                    end
                end
            end
        end
    end
}

-- Log helpers - write to log, force writing to file
minetest.mkdir(minetest.get_worldpath().."/logs")
log={
    channels={},
    last_day=os.date("%d"),
    get_path=function(logname)
        return minetest.get_worldpath().."/logs/"..logname
    end,
    create_channel=function(title)
        local dir=log.get_path(title)
        minetest.mkdir(dir)
        log.channels[title]={dirname=dir,queue={}}
        log.write(title, "Initialisation")
    end,
    write=function(channelname, msg)
        local channel=log.channels[channelname]
        local current_day=os.date("%d")
        if current_day ~= log.last_day then
            log.last_day=current_day
            log.write_to_file(channelname, channel, os.date("%Y-%m-%d"))
        end
        table.insert(channel.queue, os.date("[%H:%M:%S] ")..msg)
    end,
    write_to_all=function(msg)
        for channelname, _ in pairs(log.channels) do
            log.write(channelname, msg)
        end
    end,
    write_to_file=function(name, channel, current_date)
        if not channel then
            channel=log.channels[name]
        end
        if #(channel.queue) > 0 then
            local filename=channel.dirname.."/"..(current_date or os.date("%Y-%m-%d"))..".txt"
            local rope={}
            for _, msg in ipairs(channel.queue) do
                table.insert(rope, msg)
            end
            file_ext.append(filename, table.concat(rope, "\n").."\n")
            log.channels[name].queue={}
        end
    end,
    write_all_to_file=function()
        local current_date=os.date("%Y-%m-%d")
        for name, channel in pairs(log.channels) do
            log.write_to_file(name, channel, current_date)
        end
    end
}

local timer=0

minetest.register_globalstep(function(dtime)
    timer=timer+dtime
    if timer > 5 then
        log.write_all_to_file()
        timer=0
    end
end)

minetest.register_on_mods_loaded(function()
    log.write_to_all("Mods loaded")
end)

minetest.register_on_shutdown(function()
    log.write_to_all("Shutdown")
    log.write_all_to_file()
end)