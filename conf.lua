minetest.mkdir(minetest.get_worldpath().."/config")
function get_path(confname)
    return minetest.get_worldpath().."/config/"..confname
end
function load (filename, constraints)
    local config = minetest.parse_json(modlib.file.read(filename))
    if constraints then
        local error_message = check_constraints(config, constraints)
        if error_message then
            error("Configuration - "..filename.." doesn't satisfy constraints : "..error_message)
        end
    end
    return config
end
function load_or_create(filename, replacement_file, constraints)
    modlib.file.create_if_not_exists_from_file(filename, replacement_file)
    return load(filename, constraints)
end
function import(modname, constraints)
    return load_or_create(get_path(modname)..".json", modlib.mod.get_resource(modname, "default_config.json"), constraints)
end
function check_constraints(value, constraints)
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
        return "None of the possible values : Expected one of "..minetest.write_json(modlib.table.keys(constraints.possible_values))..", found "..minetest.write_json(value)
    end
    if t == "table" then
        if constraints.children then
            for k, v in pairs(value) do
                local child=constraints.children[k]
                if not child then
                    return "Unexpected table entry : Expected one of "..minetest.write_json(modlib.table.keys(constraints.children))..", found "..minetest.write_json(k)
                else
                    local possible_errors=check_constraints(v, child)
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
        if constraints.required_children then
            for k,v_constraints in pairs(constraints.required_children) do
                local v=value[k]
                if v then
                    local possible_errors=check_constraints(v, v_constraints)
                    if possible_errors then
                        return possible_errors
                    end
                else
                    return "Table entry missing : Expected key "..minetest.write_json(k).." to be present in table "..minetest.write_json(value)
                end
            end
        end
        if constraints.possible_children then
            for k,v_constraints in pairs(constraints.possible_children) do
                local v=value[k]
                if v then
                    local possible_errors=check_constraints(v, v_constraints)
                    if possible_errors then
                        return possible_errors
                    end
                end
            end
        end
        if constraints.keys then
            for k,_ in pairs(value) do
                local possible_errors=check_constraints(k, constraints.keys)
                if possible_errors then
                    return possible_errors
                end
            end
        end
        if constraints.values then
            for _,v in pairs(value) do
                local possible_errors=check_constraints(v, constraints.values)
                if possible_errors then
                    return possible_errors
                end
            end
        end
    end
end