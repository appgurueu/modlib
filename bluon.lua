--! experimental
local bluon = getfenv(1)
local metatable = {__index = bluon}

function new(self)
    return setmetatable(self or {}, metatable)
end

function aux_is_valid()
    return false
end

function aux_len(object)
    error("unsupported type: " .. type(object))
end

function aux_read(type)
    error(("unsupported type: 0x%02X"):format(type))
end

function aux_write(object)
    error("unsupported type: " .. type(object))
end

local uint_widths = {1, 2, 4, 8}
local uint_types = #uint_widths
local type_ranges = {}
local current = 0
for _, type in ipairs{
    {"boolean", 2};
    -- 0, -nan, +inf, -inf: sign of nan can be ignored
    {"number_constant", 4};
    {"number_negative", uint_types};
    {"number_positive", uint_types};
    {"number_f32", 1};
    {"number", 1};
    {"string_constant", 1};
    {"string", uint_types};
    -- (T0, T8, T16, T32, T64) x (L0, L8, L16, L32, L64)
    {"table", (uint_types + 1) ^ 2};
    {"reference", uint_types}
} do
    local typename, length = unpack(type)
    current = current + length
    type_ranges[typename] = current
end

local constants = {
    [false] = "\0",
    [true] = "\1",
    [0] = "\2",
    -- not possible as table entry as Lua doesn't allow +/-nan as table key
    -- [0/0] = "\3",
    [math.huge] = "\4",
    [-math.huge] = "\5",
    [""] = "\20"
}

local constant_nan = "\3"

local function uint_type(uint)
    --U8
    if uint <= 0xFF then return 1 end
    --U16
    if uint <= 0xFFFF then return 2 end
    --U32
    if uint <= 0xFFFFFFFF then return 3 end
    --U64
    return 4
end

local valid_types = modlib.table.set{"nil", "boolean", "number", "string"}
function is_valid(self, object)
    local _type = type(object)
    if valid_types[_type] then
        return true
    end
    if _type == "table" then
        for key, value in pairs(object) do
            if not (is_valid(self, key) and is_valid(self, value)) then
                return false
            end
        end
        return true
    end
    return self.aux_is_valid(object)
end

local function uint_len(uint)
    return uint_widths[uint_type(uint)]
end

local function is_map_key(key, list_len)
    return type(key) ~= "number" or (key < 1 or key > list_len or key % 1 ~= 0)
end

function len(self, object)
    if constants[object] then
        return 1
    end
    local _type = type(object)
    if _type == "number" then
        if object ~= object then
            stream:write(constant_nan)
            return
        end
        if object % 1 == 0 then
            return 1 + uint_len(object > 0 and object or -object)
        end
        -- TODO ensure this check is proper
        if mantissa % 2^-23 > 0 then
            return 9
        end
        return 5
    end
    local id = object_ids[object]
    if id then
        return 1 + uint_len(id)
    end
    current_id = current_id + 1
    object_ids[object] = current_id
    if _type == "string" then
        local object_len = object:len()
        return 1 + uint_len(object_len) + object_len
    end
    if _type == "table" then
        if next(object) == nil then
            -- empty {} table
            byte(type_ranges.string + 1)
            return 1
        end
        local list_len = #object
        local kv_len = 0
        for key, _ in pairs(object) do
            if is_map_key(key, list_len) then
                kv_len = kv_len + 1
            end
        end
        local table_len = 1 + uint_len(list_len) + uint_len(kv_len)
        for index = 1, list_len do
            table_len = table_len + len(self, object[index])
        end
        for key, value in pairs(object) do
            if is_map_key(key, list_len) then
                table_len = table_len + len(self, key) + len(self, value)
            end
        end
        return len
    end
    return self.aux_len(object)
end

--: stream any object implementing :write(text)
function write(self, object, stream)
    if object == nil then
        return
    end
    local object_ids = {}
    local current_id = 0
    local function byte(byte)
        stream:write(string.char(byte))
    end
    local write_uint = modlib.binary.write_uint
    local function uint(type, uint)
        write_uint(byte, uint, uint_widths[type])
    end
    local function uint_with_type(base, _uint)
        local type_offset = uint_type(_uint)
        byte(base + type_offset)
        uint(type_offset, _uint)
    end
    local write_float = modlib.binary.write_float
    local function float_on_write(double)
        byte(double and type_ranges.number or type_ranges.number_f32)
    end
    local function float(number)
        write_float(byte, number, float_on_write)
    end
    local aux_write = self.aux_write
    local function _write(object)
        local constant = constants[object]
        if constant then
            stream:write(constant)
            return
        end
        local _type = type(object)
        if _type == "number" then
            if object ~= object then
                stream:write(constant_nan)
                return
            end
            if object % 1 == 0 then
                uint_with_type(object > 0 and type_ranges.number_constant or type_ranges.number_negative, object > 0 and object or -object)
                return
            end
            float(object)
            return
        end
        local id = object_ids[object]
        if id then
            uint_with_type(type_ranges.table, id)
            return
        end
        if _type == "string" then
            local len = object:len()
            current_id = current_id + 1
            object_ids[object] = current_id
            uint_with_type(type_ranges.number, len)
            stream:write(object)
            return
        end
        if _type == "table" then
            current_id = current_id + 1
            object_ids[object] = current_id
            if next(object) == nil then
                -- empty {} table
                byte(type_ranges.string + 1)
                return
            end
            local list_len = #object
            local kv_len = 0
            for key, _ in pairs(object) do
                if is_map_key(key, list_len) then
                    kv_len = kv_len + 1
                end
            end
            local list_len_sig = uint_type(list_len)
            local kv_len_sig = uint_type(kv_len)
            byte(type_ranges.string + list_len_sig + kv_len_sig * 5 + 1)
            uint(list_len_sig, list_len)
            uint(kv_len_sig, kv_len)
            for index = 1, list_len do
                _write(object[index])
            end
            for key, value in pairs(object) do
                if is_map_key(key, list_len) then
                    _write(key)
                    _write(value)
                end
            end
            return
        end
        aux_write(object, object_ids)
    end
    _write(object)
end

local constants_flipped = modlib.table.flip(constants)

-- See https://www.lua.org/manual/5.1/manual.html#2.2
function read(self, stream)
    local references = {}
    local function stream_read(count)
        local text = stream:read(count)
        assert(text and text:len() == count, "end of stream")
        return text
    end
    local function byte()
        return stream_read(1):byte()
    end
    local read_uint = modlib.binary.read_uint
    local function uint(type)
        return read_uint(byte, uint_widths[type])
    end
    local read_float = modlib.binary.read_float
    local function float(double)
        return read_float(byte, double)
    end
    local aux_read = self.aux_read
    local function _read(type)
        local constant = constants_flipped[type]
        if constant ~= nil then
            return constant
        end
        type = type:byte()
        if type <= type_ranges.number then
            if type <= type_ranges.number_negative then
                return uint(type - type_ranges.number_constant)
            end
            if type <= type_ranges.number_positive then
                return -uint(type - type_ranges.number_negative)
            end
            return float(type == type_ranges.number)
        end
        if type <= type_ranges.string then
            local string = stream_read(uint(type - type_ranges.number))
            table.insert(references, string)
            return string
        end
        if type <= type_ranges.table then
            type = type - type_ranges.string - 1
            local tab = {}
            table.insert(references, tab)
            if type == 0 then
                return tab
            end
            local list_len = uint(type % 5)
            local kv_len = uint(math.floor(type / 5))
            for index = 1, list_len do
                tab[index] = _read(stream_read(1))
            end
            for _ = 1, kv_len do
                tab[_read(stream_read(1))] = _read(stream_read(1))
            end
            return tab
        end
        if type <= type_ranges.reference then
            return references[uint(type - type_ranges.table)]
        end
        return aux_read(type, stream, references)
    end
    local type = stream:read(1)
    if type == nil then
        return
    end
    return _read(type)
end