locks={}
function request(resource, func, ...)
    if locks[resource] then
        table.insert(locks[resource], {func=func, args={...}})
        return false
    end
    locks[resource]={}
    return true
end
function free(resource)
    if locks[resource] then
        local first=locks[resource][1]
        if first then
            first.func(unpack(first.args), true)
        end
    end
    locks[resource]=nil
    return true
end