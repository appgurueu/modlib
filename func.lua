no_op = function() end

function curry(func, ...)
	local args = { ... }
	return function(...) return func(unpack(args), ...) end
end

function curry_tail(func, ...)
	local args = { ... }
	return function(...) return func(..., unpack(args)) end
end

function call(...)
	local args = { ... }
	return function(func) return func(unpack(args)) end
end

function value(val) return function() return val end end

function values(...)
	local args = { ... }
	return function() return unpack(args) end
end

function override_chain(func, override)
	return function(...)
		func(...)
		return override(...)
	end
end

function assert(value, callback)
	if not value then
		error(callback())
	end
end