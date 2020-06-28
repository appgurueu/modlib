local mt_vector = vector
local vector = getfenv(1)

function new(v)
    return setmetatable(v, vector)
end

function from_xyzw(v)
    return new{v.x, v.y, v.z, v.w}
end

function to_xyzw(v)
    return {x = v[1], y = v[2], z = v[3], w = v[4]}
end

function to_minetest(v)
    return mt_vector.new(unpack(v))
end

function combine(v1, v2, f)
    local v = {}
    for k, c in pairs(v1) do
        v[k] = f(c, v2[k])
    end
    return new(v)
end

function apply(v, s, f)
    for i, c in pairs(v) do
        v[i] = f(c, s)
    end
end

function combinator(f)
    return function(v1, v2)
        return combine(v1, v2, f)
    end, function(v, s)
        return apply(v, s, f)
    end
end

add, add_scalar = combinator(function(a, b) return a + b end)
subtract, subtract_scalar = combinator(function(a, b) return a - b end)
multiply, multiply_scalar = combinator(function(a, b) return a * b end)
divide, divide_scalar = combinator(function(a, b) return a / b end)

function length(v)
    local sum = 0
    for _, c in pairs(v) do
        sum = sum + c*c
    end
    return math.sqrt(sum)
end