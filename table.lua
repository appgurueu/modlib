-- Table helpers
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

function map(t, func)
    for k, v in pairs(t) do
        t[k]=func(v)
    end
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

function merge_tables(table1, table2)
    local table1copy = table.copy(table1)
    for key, value in pairs(table2) do
        table1copy[key] = value
    end
    return table1copy
end

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
    return table_ext.keys(lookup)
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
    return table_ext.best_value(table, function(v, m) return v < m end)
end

function max(table)
    return table_ext.best_value(table, function(v, m) return v > m end)
end

function binary_search(list, value)
    local min, size = 1, #list
    while size > 1 do
        local s_half = math.floor(size / 2)
        local pivot = min + s_half
        local element = list[pivot]
        if value > element then
            min = pivot
        end
        size = s_half
    end
end