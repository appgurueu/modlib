local mt_vector = vector
local vector = getfenv(1)

function new(v)
    return setmetatable(v, vector)
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

function combine(v1, v2, f)
    local new_vector = {}
    for key, value in pairs(v1) do
        new_vector[key] = f(value, v2[key])
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
    return function(v1, v2)
        return combine(v1, v2, f)
    end, function(v, ...)
        return apply(v, f, ...)
    end
end

add, add_scalar = combinator(function(a, b) return a + b end)
subtract, subtract_scalar = combinator(function(a, b) return a - b end)
multiply, multiply_scalar = combinator(function(a, b) return a * b end)
divide, divide_scalar = combinator(function(a, b) return a / b end)

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

function box_box_collision(diff, box, other_box)
    for index, diff in pairs(diff) do
        if box[index] + diff > other_box[index + 3] or other_box[index] > box[index + 3] + diff then
            return false
        end
    end
    return true
end