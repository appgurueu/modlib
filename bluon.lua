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
    local function uint(type, uint)
        for _ = 1, uint_widths[type] do
            byte(uint % 0x100)
            uint = math.floor(uint / 0x100)
        end
    end
    local function uint_with_type(base, _uint)
        local type_offset = uint_type(_uint)
        byte(base + type_offset)
        uint(type_offset, _uint)
    end
    local function float(number)
        local sign = 0
        if number < 0 then
            number = -number
            sign = 0x80
        end
        local mantissa, exponent = math.frexp(number)
        exponent = exponent + 127
        if exponent > 1 then
            -- TODO ensure this deals properly with subnormal numbers
            mantissa = mantissa * 2 - 1
            exponent = exponent - 1
        end
        local sign_byte = sign + math.floor(exponent / 2)
        mantissa = mantissa * 0x80
        local exponent_byte = (exponent % 2) * 0x80 + math.floor(mantissa)
        mantissa = mantissa % 1
        local mantissa_bytes = {}
        -- TODO ensure this check is proper
        local double = mantissa % 2^-23 > 0
        byte(double and type_ranges.number or type_ranges.number_f32)
        local len = double and 6 or 2
        for index = len, 1, -1 do
            mantissa = mantissa * 0x100
            mantissa_bytes[index] = string.char(math.floor(mantissa))
            mantissa = mantissa % 1
        end
        assert(mantissa == 0)
        stream:write(table.concat(mantissa_bytes))
        byte(exponent_byte)
        byte(sign_byte)
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
                uint_with_type(object > 0 and type_ranges.number_constant or type_ranges.number_positive, object > 0 and object or -object)
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
    local function uint(bytes)
        local factor = 1
        local int = 0
        for _ = 1, uint_widths[bytes] do
            int = int + byte() * factor
            factor = factor * 0x100
        end
        return int
    end
    -- TODO get rid of code duplication (see b3d.lua)
    local function float(double)
        -- First read the mantissa
        local mantissa = 0
        for _ = 1, double and 6 or 2 do
            mantissa = (mantissa + byte()) / 0x100
        end
        -- Second and first byte in big endian: last bit of exponent + 7 bits of mantissa, sign bit + 7 bits of exponent
        local byte_2, byte_1 = byte(), byte()
        local sign = 1
        if byte_1 >= 0x80 then
            sign = -1
            byte_1 = byte_1 - 0x80
        end
        local exponent = byte_1 * 2
        if byte_2 >= 0x80 then
            exponent = exponent + 1
            byte_2 = byte_2 - 0x80
        end
        mantissa = (mantissa + byte_2) / 0x80
        if exponent == 0xFF then
            if mantissa == 0 then
                return sign * math.huge
            end
            -- Differentiating quiet and signalling nan is not possible in Lua, hence we don't have to do it
            -- HACK ((0/0)^1) yields nan, 0/0 yields -nan
            return sign == 1 and ((0/0)^1) or 0/0
        end
        assert(mantissa < 1)
        if exponent == 0 then
            -- subnormal value
            return sign * 2^-126 * mantissa
        end
        return sign * 2 ^ (exponent - 127) * (1 + mantissa)
    end
    local aux_read = self.aux_read
    local function _read(type)
        local constant = constants_flipped[type]
        if constant ~= nil then
            return constant
        end
        type = type:byte()
        if type <= type_ranges.number then
            if type <= type_ranges.number_positive then
                return uint(type - type_ranges.number_constant)
            end
            if type <= type_ranges.number_negative then
                return -uint(type - type_ranges.number_positive)
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