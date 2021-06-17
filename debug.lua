-- Localize globals
local _G, debug, getfenv, table, tostring = _G, debug, getfenv, table, tostring

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

function variables(stacklevel)
	stacklevel = (stacklevel or 1) + 1
	local locals = {}
	local index = 1
	while true do
		local name, value = debug.getlocal(stacklevel, index)
		if not name then break end
		table.insert(locals, {name, value})
		index = index + 1
	end
	local upvalues = {}
	local func = debug.getinfo(stacklevel).func
	local fenv = getfenv(func)
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
		fenv = fenv,
		fenv_global = fenv == _G
	}
end

function stack(stacklevel)
	stacklevel = (stacklevel or 1) + 1
	local stack = {}
	while true do
		local info = debug.getinfo(stacklevel, "nfSlu")
		if not info then
			break
		end
		info.func = tostring(info.func)
		info.variables = variables(stacklevel)
		stack[stacklevel - 1] = info
		stacklevel = stacklevel + 1
	end
	return stack
end

-- Export environment
return _ENV