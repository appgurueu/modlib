local function gather_info()
    local locals = {}
    local index = 1
    while true do
        local name, value = debug.getlocal(2, index)
        if not name then break end
        table.insert(locals, {name, value})
        index = index + 1
    end
    local upvalues = {}
    local func = debug.getinfo(2).func
    local envs = getfenv(func)
    index = 1
    while true do
        local name, value = debug.getupvalue(func, index)
        if not name then break end
        table.insert(upvalues, {name, value})
        index = index + 1
    end
    return {
        locals = locals,
        upvalues = upvalues,
        [envs == _G and "globals" or "envs"] = envs
    }
end

local c = 3
function test()
    local a = 1
    b = 2
    error(gather_info().upvalues[1][1])
end

test()