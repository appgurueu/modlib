local assert, next, pairs, pcall, error, type, table_insert, table_concat, string_format, setfenv, math_huge, loadfile, loadstring
    = assert, next, pairs, pcall, error, type, table.insert, table.concat, string.format, setfenv, math.huge, loadfile, loadstring
local count_values = modlib.table.count_values

-- Build a table with the succeeding character from A-Z
local succ = {}
for char = ("A"):byte(), ("Z"):byte() - 1 do
    succ[string.char(char)] = string.char(char + 1)
end

local function quote(string)
    return string_format("%q", string)
end

local _ENV = {}
setfenv(1, _ENV)

function serialize(object, write)
    local reference = {"A"}
    local function increment_reference(place)
        if not reference[place] then
            reference[place] = "B"
        elseif reference[place] == "Z" then
            reference[place] = "A"
            return increment_reference(place + 1)
        else
            reference[place] = succ[reference[place]]
        end
    end
    local references = {}
    local to_fill = {}
    for value, count in pairs(count_values(object)) do
        local type_ = type(value)
        if count >= 2 and ((type_ == "string" and #reference + 2 >= #value) or type_ == "table") then
            local ref = table_concat(reference)
            write(ref)
            write"="
            write(type_ == "table" and "{}" or quote(value))
            write";"
            references[value] = ref
            if type_ == "table" then
                to_fill[value] = true
            end
            increment_reference(1)
        end
    end
    local function is_short_key(key)
        return not references[key] and type(key) == "string" and key:match"^[%a_][%a%d_]*$"
    end
    local function dump(value)
        -- Primitive types
        if value == nil then
            return write"nil"
        end
        if value == true then
            return write"true"
        end
        if value == false then
            return write"false"
        end
        local type_ = type(value)
        if type_ == "number" then
            return write(("%.17g"):format(value))
        end
        -- Reference types: table and string
        local ref = references[value]
        if ref then
            -- Referenced
            if not to_fill[value] then
                return write(ref)
            end
            -- Fill table
            to_fill[value] = false
            for k, v in pairs(value) do
                write(ref)
                if is_short_key(k) then
                    write"."
                    write(k)
                else
                    write"["
                    dump(k)
                    write"]"
                end
                write"="
                dump(v)
                write";"
            end
        elseif type_ == "string" then
            return write(quote(value))
        elseif type_ == "table" then
            local first = true
            write"{"
            local len = #value
            for i = 1, len do
                if not first then write";" end
                dump(value[i])
                first = false
            end
            for k, v in next, value do
                if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > len then
                    if not first then write";" end
                    if is_short_key(k) then
                        write(k)
                    else
                        write"["
                        dump(k)
                        write"]"
                    end
                    write"="
                    dump(v)
                    first = false
                end
            end
            write"}"
        else
            error("unsupported type: " .. type_)
        end
    end
    local fill_root = to_fill[object]
    if fill_root then
        -- Root table is circular, must return by named reference
        dump(object)
        write"return "
        write(references[object])
    else
        -- Root table is not circular, can directly start writing
        write"return "
        dump(object)
    end
end

function serialize_file(object, file)
    return serialize(object, function(text)
        file:write(text)
    end)
end

function serialize_string(object)
    local rope = {}
    serialize(object, function(text)
        table_insert(rope, text)
    end)
    return table_concat(rope)
end

function deserialize(...)
	local read = assert(...)
	-- math.huge is serialized to inf, 0/0 is serialized to -nan
	setfenv(read, {inf = math_huge, nan = 0/0})
	local success, value_or_err = pcall(read)
    if success then
        return value_or_err
    end
    return nil, value_or_err
end

function deserialize_file(path)
    return deserialize(loadfile(path))
end

function deserialize_string(string)
    return deserialize(loadstring(string))
end

return _ENV