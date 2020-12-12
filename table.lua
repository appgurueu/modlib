-- Table helpers

function map_index(table, func)
    return setmetatable(table, {
        __index = function(table, key)
            return rawget(table, func(key))
        end,
        __newindex = function(table, key, value)
            rawset(table, func(key), value)
        end
    })
end

function set_case_insensitive_index(table)
    return map_index(table, string.lower)
end

function nilget(table, key, ...)
    assert(key ~= nil)
    local function nilget(table, key, ...)
        if key == nil then
            return table
        end
        local value = table[key]
        if value == nil then
            return nil
        end
        return nilget(value, ...)
    end
    return nilget(table, key, ...)
end

-- Fisher-Yates
function shuffle(table)
    for index = 1, #table - 1 do
        local index_2 = math.random(index + 1, #table)
        table[index], table[index_2] = table[index_2], table[index]
    end
    return table
end

-- TODO circular equals
function equals_noncircular(table_1, table_2)
    local is_equal = table_1 == table_2
    if is_equal or type(table_1) ~= "table" or type(table_2) ~= "table" then
        return is_equal
    end
    if #table_1 ~= #table_2 then
        return false
    end
    local table_keys = {}
    for key_1, value_1 in pairs(table_1) do
        local value_2 = table_2[key_1]
        if not equals_noncircular(value_1, value_2) then
            if type(key_1) == "table" then
                table_keys[key_1] = value_1
            else
                return false
            end
        end
    end
    for key_2, value_2 in pairs(table_2) do
        if type(key_2) == "table" then
            local found
            for table, value in pairs(table_keys) do
                if equals_noncircular(key_2, table) and equals_noncircular(value_2, value) then
                    table_keys[table] = nil
                    found = true
                    break
                end
            end
            if not found then
                return false
            end
        else
            if table_1[key_2] == nil then
                return false
            end
        end
    end
    return true
end

function tablecopy(t)
    return table.copy(t)
end

copy = tablecopy

function shallowcopy(table)
    local copy = {}
    for key, value in pairs(table) do
        copy[key] = value
    end
    return copy
end

function deepcopy_noncircular(table)
    local function _copy(value)
        if type(value) == "table" then
            return deepcopy_noncircular(value)
        end
        return value
    end
    local copy = {}
    for key, value in pairs(table) do
        copy[_copy(key)] = _copy(value)
    end
    return copy
end

function deepcopy(table)
    local copies = {}
    local function _deepcopy(table)
        if copies[table] then
            return copies[table]
        end
        local copy = {}
        copies[table] = copy
        local function _copy(value)
            if type(value) == "table" then
                if copies[value] then
                    return copies[value]
                end
                return _deepcopy(value)
            end
            return value
        end
        for key, value in pairs(table) do
            copy[_copy(key)] = _copy(value)
        end
        return copy
    end
    return _deepcopy(table)
end

function count(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function is_empty(table)
    return next(table) == nil
end

function foreach(t, func)
    for k, v in pairs(t) do
        func(k, v)
    end
end

function foreach_value(t, func)
    for _, v in pairs(t) do
        func(v)
    end
end

function foreach_key(t, func)
    for k, _ in pairs(t) do
        func(k)
    end
end

function map(t, func)
    for k, v in pairs(t) do
        t[k]=func(v)
    end
    return t
end

function map_keys(tab, func)
    local new_tab = {}
    for key, value in pairs(tab) do
        new_tab[func(key)] = value
    end
    return new_tab
end

function process(t, func)
    local r={}
    for k, v in pairs(t) do
        table.insert(r, func(k,v))
    end
    return r
end

function call(funcs, ...)
    for _, func in ipairs(funcs) do
        func(...)
    end
end

function find(list, value)
    for index, other_value in pairs(list) do
        if value == other_value then
            return index
        end
    end
    return false
end

contains = find

function difference(table1, table2)
    local result={}
    for k, v in pairs(table2) do
        local v2=table1[v]
        if v2~=v then
            result[k]=v
        end
    end
    return result
end

function add_all(dst, new)
    for key, value in pairs(new) do
        dst[key] = value
    end
    return dst
end

function complete(dst, new)
    for key, value in pairs(new) do
        if  dst[key] == nil then
            dst[key] = value
        end
    end
    return dst
end

function merge_tables(table1, table2)
    return add_all(copy(table1), table2)
end

union = merge_tables

function intersection(t1, t2)
    local result = {}
    for key, value in pairs(t1) do
        if t2[key] then
            result[key] = value
        end
    end
    return result
end

function append(t1, t2)
    local l=#t1
    for k, v in ipairs(t2) do
        t1[l+k]=v
    end
    return t1
end

function keys(t)
    local keys = {}
    for key, _ in pairs(t) do
        table.insert(keys, key)
    end
    return keys
end

function values(t)
    local values = {}
    for key, _ in pairs(t) do
        table.insert(values, key)
    end
    return values
end

function flip(table)
    local flipped = {}
    for key, val in pairs(table) do
        flipped[val] = key
    end
    return flipped
end

function set(table)
    local flipped = {}
    for _, val in pairs(table) do
        flipped[val] = true
    end
    return flipped
end

function unique(table)
    local lookup = {}
    for val in ipairs(table) do
        lookup[val] = true
    end
    return keys(lookup)
end

function rpairs(t)
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
end

function best_value(table, is_better_fnc)
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
end

function min(table)
    return best_value(table, function(v, m) return v < m end)
end

function max(table)
    return best_value(table, function(v, m) return v > m end)
end

function default_comparator(a, b)
    if a == b then
        return 0
    end
    if a > b then
        return 1
    end
    return -1
end

function binary_search_comparator(comparator)
    -- if found, returns index; if not found, returns -index for insertion
    return function(list, value)
        local min, max = 1, #list
        while min <= max do
            local pivot = min + math.floor((max-min)/2)
            local element = list[pivot]
            local compared = comparator(value, element)
            if compared == 0 then
                return pivot
            elseif compared > 0 then
                min = pivot+1
            else
                max = pivot-1
            end
        end
        return -min
    end
end

binary_search = binary_search_comparator(default_comparator)

function reverse(list)
    local len = #list
    for i = 1, math.floor(#list/2) do
        list[len-i+1], list[i] = list[i], list[len-i+1]
    end
    return list
end

function repetition(value, count)
    local table = {}
    for i = 1, count do
        table[i] = value
    end
    return table
end