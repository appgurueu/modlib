classes = {}
function define(name, def)
    if def.extends then
        setmetatable(def, get(def.extends))
    end
    classes[name] = def
end
function new(classname, ...)
    local obj = get(classname).new(...)
    obj = setmetatable(obj, {__index = classes[classname]})
    return obj
end
function get(classname)
    return classes[classname]
end
function call(classname, funcname, object, ...)
    if object then
        setfenv(1, object)
        get(classname)[funcname](object, ...)
    else
        setfenv(1, classes[classname])
        get(classname)[funcname](...)
    end
    setfenv(1, _G)
end
