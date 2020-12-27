local mt_vector = vector
local vector = getfenv(1)

index_aliases = {
    x = 1,
    y = 2,
    z = 3,
    w = 4
}

modlib.table.add_all(index_aliases, modlib.table.flip(index_aliases))

metatable = {
    __index = function(table, key)
        local index = index_aliases[key]
        if index ~= nil then
            return table[index]
        end
        return vector[key]
    end,
    __newindex = function(table, key, value)
        local index = letters[key]
        if index ~= nil then
            return rawset(table, index, value)
        end
    end
}

function new(v)
    return setmetatable(v, metatable)
end

function from_xyzw(v)
    return new{v.x, v.y, v.z, v.w}
end

function from_minetest(v)
    return new{v.x, v.y, v.z}
end

function to_xyzw(v)
    return {x = v[1], y = v[2], z = v[3], w = v[4]}
end

function to_minetest(v)
    return mt_vector.new(unpack(v))
end

function equals(v, other_v)
    for k, v in pairs(v) do
        if v ~= other_v[k] then return false end
    end
    return true
end

metatable.__eq = equals

function less_than(v, other_v)
    for k, v in pairs(v) do
        if v >= other_v[k] then return false end
    end
    return true
end

metatable.__lt = less_than

function less_or_equal(v, other_v)
    for k, v in pairs(v) do
        if v > other_v[k] then return false end
    end
    return true
end

metatable.__le = less_or_equal

function combine(v, other_v, f)
    local new_vector = {}
    for key, value in pairs(v) do
        new_vector[key] = f(value, other_v[key])
    end
    return new(new_vector)
end

function apply(v, f, ...)
    local new_vector = {}
    for key, value in pairs(v) do
        new_vector[key] = f(value, ...)
    end
    return new(new_vector)
end

function combinator(f)
    return function(v, other_v)
        return combine(v, other_v, f)
    end, function(v, ...)
        return apply(v, f, ...)
    end
end

function invert(v)
    for key, value in pairs(v) do
        v[key] = -value
    end
end

add, add_scalar = combinator(function(a, b) return a + b end)
subtract, subtract_scalar = combinator(function(a, b) return a - b end)
multiply, multiply_scalar = combinator(function(a, b) return a * b end)
divide, divide_scalar = combinator(function(a, b) return a / b end)
pow, pow_scalar = combinator(function(a, b) return a ^ b end)

metatable.__add = add
metatable.__unm = invert
metatable.__sub = subtract
metatable.__mul = multiply
metatable.__div = divide

function norm(v)
    local sum = 0
    for _, c in pairs(v) do
        sum = sum + c*c
    end
    return sum
end

function length(v)
    return math.sqrt(norm(v))
end

function normalize(v)
    return divide_scalar(v, length(v))
end

function floor(v)
    return apply(v, math.floor)
end

function ceil(v)
    return apply(v, math.ceil)
end

function clamp(v, min, max)
    return apply(apply(v, math.max, min), math.min, max)
end

function cross3(v, other_v)
    return new{
        v[2] * other_v[3] - v[3] * other_v[2],
        v[3] * other_v[1] - v[1] * other_v[3],
        v[1] * other_v[2] - v[2] * other_v[1]
    }
end

function dot(v, other_v)
    local sum = 0
    for i, c in pairs(v) do
        sum = sum + c * other_v[i]
    end
    return sum
end

function box_box_collision(diff, box, other_box)
    for index, diff in pairs(diff) do
        if box[index] + diff > other_box[index + 3] or other_box[index] > box[index + 3] + diff then
            return false
        end
    end
    return true
end

--+ Möller-Trumbore
function ray_triangle_intersection(origin, direction, triangle)
    local point_1, point_2, point_3 = unpack(triangle)
    local edge_1, edge_2 = subtract(point_2, point_1), subtract(point_3, point_1)
    local h = cross3(direction, edge_2)
    local a = dot(edge_1, h)
    if math.abs(a) < 1e-9 then
        return
    end
    local f = 1 / a
    local diff = subtract(origin, point_1)
    local u = f * dot(diff, h)
    if u < 0 or u > 1 then
        return
    end
    local q = cross3(diff, edge_1)
    local v = f * dot(direction, q)
    if v < 0 or u + v > 1 then
        return
    end
    local pos_on_line = f * dot(edge_2, q)
    if pos_on_line >= 0 then
        return pos_on_line
    end
end

function triangle_normal(triangle)
    local point_1, point_2, point_3 = unpack(triangle)
    local edge_1, edge_2 = subtract(point_2, point_1), subtract(point_3, point_1)
    return normalize(cross3(edge_1, edge_2))
end