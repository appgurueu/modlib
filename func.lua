function curry(func, ...)
    local args = {...}
    return function(...)
        return func(unpack(args), ...)
    end
end