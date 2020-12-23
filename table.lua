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

-- circular references can be different as long as the content is identical
function equals_content(table_1, table_2)
    local equal_tables = {}
    local function _equals(table_1, table_2)
        local function set_equal_tables(value)
            equal_tables[table_1] = equal_tables[table_1] or {}
            equal_tables[table_1][table_2] = value
            return value
        end
        local is_equal = table_1 == table_2
        if is_equal or type(table_1) ~= "table" or type(table_2) ~= "table" then
            return is_equal
        end
        if #table_1 ~= #table_2 then
            return false
        end
        local lookup_equal = (equal_tables[table_1] or {})[table_2]
        if lookup_equal ~= nil then
            return lookup_equal
        end
        set_equal_tables(true)
        local table_keys = {}
        for key_1, value_1 in pairs(table_1) do
            local value_2 = table_2[key_1]
            if not _equals(value_1, value_2) then
                if type(key_1) == "table" then
                    table_keys[key_1] = value_1
                else
                    return set_equal_tables(false)
                end
            end
        end
        for key_2, value_2 in pairs(table_2) do
            if type(key_2) == "table" then
                local found
                for table, value in pairs(table_keys) do
                    if _equals(key_2, table) and _equals(value_2, value) then
                        table_keys[table] = nil
                        found = true
                        break
                    end
                end
                if not found then
                    return set_equal_tables(false)
                end
            else
                if table_1[key_2] == nil then
                    return set_equal_tables(false)
                end
            end
        end
        return true
    end
    return _equals(table_1, table_2)
end

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

tablecopy = deepcopy
copy = deepcopy

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

function foreach(table, func)
    for k, v in pairs(table) do
        func(k, v)
    end
end

function foreach_value(table, func)
    for _, v in pairs(table) do
        func(v)
    end
end

function call(table, ...)
    for _, func in pairs(table) do
        func(...)
    end
end

function icall(table, ...)
    for _, func in ipairs(table) do
        func(...)
    end
end

function foreach_key(table, func)
    for key, _ in pairs(table) do
        func(key)
    end
end

function map(table, func)
    for key, value in pairs(table) do
        table[key] = func(value)
    end
    return table
end

function map_keys(table, func)
    local new_tab = {}
    for key, value in pairs(table) do
        new_tab[func(key)] = value
    end
    return new_tab
end

function process(tab, func)
    local results = {}
    for key, value in pairs(tab) do
        table.insert(results, func(key,value))
    end
    return results
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

function difference(table, other_table)
    local result = {}
    for key, value in pairs(other_table) do
        if table[value] ~= value then
            result[key] = value
        end
    end
    return result
end

function add_all(table, additions)
    for key, value in pairs(additions) do
        table[key] = value
    end
    return table
end

function deep_add_all(table, additions)
    for key, value in pairs(additions) do
        if type(table[key]) == "table" and type(value) == "table" then
            deep_add_all(table[key], value)
        else
            table[key] = value
        end
    end
    return table
end

function complete(table, completions)
    for key, value in pairs(completions) do
        if table[key] == nil then
            table[key] = value
        end
    end
    return table
end

function deepcomplete(table, completions)
    for key, value in pairs(completions) do
        if table[key] == nil then
            table[key] = value
        elseif type(table[key]) == "table" and type(value) == "table" then
            deepcomplete(table[key], value)
        end
    end
    return table
end

function merge_tables(table, other_table)
    return add_all(copy(table), other_table)
end

union = merge_tables

function intersection(table, other_table)
    local result = {}
    for key, value in pairs(table) do
        if other_table[key] then
            result[key] = value
        end
    end
    return result
end

function append(table, other_table)
    local length = #table
    for index, value in ipairs(other_table) do
        table[length + index] = value
    end
    return table
end

function keys(table)
    local keys = {}
    for key, _ in pairs(table) do
        keys[#keys + 1] = key
    end
    return keys
end

function values(table)
    local values = {}
    for _, value in pairs(table) do
        values[#values + 1] = value
    end
    return values
end

function flip(table)
    local flipped = {}
    for key, value in pairs(table) do
        flipped[value] = key
    end
    return flipped
end

function set(table)
    local flipped = {}
    for _, value in pairs(table) do
        flipped[value] = true
    end
    return flipped
end

function unique(table)
    local lookup = {}
    for _, value in pairs(table) do
        lookup[value] = true
    end
    return keys(lookup)
end

function rpairs(table)
    local index = #table
    return function()
        if index >= 1 then
            local value = table[index]
            index = index - 1
            if value ~= nil then
                return index + 1, value
            end
        end
    end
end

function best_value(table, is_better_func)
    local best = next(table)
    if best == nil then
        return
    end
    local candidate = best
    while true do
        candidate = next(table, candidate)
        if candidate == nil then
            return best
        end
        if is_better_func(candidate, best) then
            best = candidate
        end
    end
    error()
end

function min(table)
    return best_value(table, function(value, other_value) return value < other_value end)
end

function max(table)
    return best_value(table, function(value, other_value) return value > other_value end)
end

function default_comparator(value, other_value)
    if value == other_value then
        return 0
    end
    if value > other_value then
        return 1
    end
    return -1
end

--> index if element found
--> -index for insertion if not found
function binary_search_comparator(comparator)
    return function(list, value)
        local min, max = 1, #list
        while min <= max do
            local pivot = min + math.floor((max - min) / 2)
            local element = list[pivot]
            local compared = comparator(value, element)
            if compared == 0 then
                return pivot
            elseif compared > 0 then
                min = pivot + 1
            else
                max = pivot - 1
            end
        end
        return -min
    end
end

binary_search = binary_search_comparator(default_comparator)

function reverse(table)
    local l = #table + 1
    for index = 1, math.floor(#table / 2) do
        table[l - index], table[index] = table[index], table[l - index]
    end
    return table
end

function repetition(value, count)
    local table = {}
    for index = 1, count do
        table[index] = value
    end
    return table
end