-- Table helpers

-- Fisher-Yates
function shuffle(t)
    for i = 1, #t-1 do
        local j = math.random(i+1, #t)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function equals(t1, t2)
    local is_equal = t1 == t2
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return is_equal
    end
    if is_equal then
        return true
    end
    if #t1 ~= #t2 then
        return false
    end
    local table_keys = {}
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if not equals(v1, v2) then
            if type(k1) == "table" then
                table_keys[k1] = v1
            else
                return false
            end
        end
    end
    for k2, v2 in pairs(t2) do
        if type(k2) == "table" then
            local found
            for t, v in table_keys do
                if equals(k2, t) and equals(v2, v) then
                    table_keys[t] = nil
                    found=true
                    break
                end
            end
            if not found then
                return false
            end
        else
            if t1[k2] == nil then
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

function process(t, func)
    local r={}
    for k, v in pairs(t) do
        table.insert(r, func(k,v))
    end
    return r
end

function call(funcs, ...)
    for _, func in ipairs(funcs) do
        func(unpack(arg))
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
    function binary_search(list, value)
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