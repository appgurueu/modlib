local assert, next, pairs, pcall, error, type, table_insert, table_concat, string_format, string_match, setfenv, math_huge, loadfile, loadstring
    = assert, next, pairs, pcall, error, type, table.insert, table.concat, string.format, string.match, setfenv, math.huge, loadfile, loadstring

local count_objects = modlib.table.count_objects

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

function write(value, write)
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
    for value, count in pairs(count_objects(value)) do
        local type_ = type(value)
        if count >= 2 and (type_ ~= "string" or #reference + 2 >= #value) then
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
        return not references[key] and type(key) == "string" and string_match(key, "^[%a_][%a%d_]*$")
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
            return write(string_format("%.17g", value))
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
    local fill_root = to_fill[value]
    if fill_root then
        -- Root table is circular, must return by named reference
        dump(value)
        write"return "
        write(references[value])
    else
        -- Root table is not circular, can directly start writing
        write"return "
        dump(value)
    end
end

function write_file(value, file)
    return write(value, function(text)
        file:write(text)
    end)
end

function write_string(value)
    local rope = {}
    write(value, function(text)
        table_insert(rope, text)
    end)
    return table_concat(rope)
end

function read(...)
	local read = assert(...)
	-- math.huge is serialized to inf, 0/0 is serialized to -nan
	setfenv(read, {inf = math_huge, nan = 0/0})
	local success, value_or_err = pcall(read)
    if success then
        return value_or_err
    end
    return nil, value_or_err
end

function read_file(path)
    return read(loadfile(path))
end

function read_string(string)
    return read(loadstring(string))
end

return _ENV