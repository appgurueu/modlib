-- Localize globals
local error, coroutine, math, modlib, unpack, select, setmetatable
	= error, coroutine, math, modlib, unpack, select, setmetatable

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

no_op = function() end

function curry(func, ...)
	local args = { ... }
	return function(...) return func(unpack(args), ...) end
end

function curry_tail(func, ...)
	local args = { ... }
	return function(...) return func(unpack(modlib.table.concat({...}, args))) end
end

function curry_full(func, ...)
	local args = { ... }
	return function() return func(unpack(args)) end
end

function args(...)
	local args = { ... }
	return function(func) return func(unpack(args)) end
end

function value(val) return function() return val end end

function values(...)
	local args = { ... }
	return function() return unpack(args) end
end

function memoize(func)
	return setmetatable({}, {
		__index = function(self, key)
			local value = func(key)
			self[key] = value
			return value
		end,
		__call = function(self, arg)
			return self[arg]
		end,
		__mode = "k"
	})
end

-- Equivalent to `for x, y, z in iterator, state, ... do callback(x, y, z) end`
function iterate(callback, iterator, state, ...)
	local function loop(...)
		if ... == nil then return end
		callback(...)
		return loop(iterator(state, ...))
	end
	return loop(iterator(state, ...))
end

function for_generator(caller, ...)
	local co = coroutine.create(function(...)
		return caller(function(...)
			return coroutine.yield(...)
		end, ...)
	end)
	local args = {...}
	return function()
		if coroutine.status(co) == "dead" then
			return
		end
		local function _iterate(status, ...)
			if not status then
				error((...))
			end
			return ...
		end
		return _iterate(coroutine.resume(co, unpack(args)))
	end
end

-- Does not use select magic, stops at the first nil value
function aggregate(binary_func, total, ...)
	if total == nil then return end
	local function _aggregate(value, ...)
		if value == nil then return end
		total = binary_func(total, value)
		return _aggregate(...)
	end
	_aggregate(...)
	return total
end

--+ For all functions which aggregate over single values, use modlib.table.ivalues - not ipairs - for lists!
--+ Otherwise they will be applied to the indices.
iterator = {}

function iterator.aggregate(binary_func, total, ...)
	for value in ... do
		total = binary_func(total, value)
	end
	return total
end

function iterator.min(less_than_func, ...)
	local min
	for value in ... do
		if min == nil or less_than_func(value, min) then
			min = value
		end
	end
	return min
end

function iterator.count(...)
	local count = 0
	for _ in ... do
		count = count + 1
	end
	return count
end

function iterator.sum(...)
	return iterator.aggregate(add, ...)
end

function iterator.average(...)
	local count = 0
	local sum = 0
	for value in ... do
		count = count + 1
		sum = sum + value
	end
	return sum / count
end

--: ... **restartable** iterator
-- While a single pass method for calculating the standard deviation exists, it is highly inaccurate
function iterator.standard_deviation(...)
	local avg = iterator.average(...)
	local count = 0
	local sum = 0
	for value in ... do
		count = count + 1
		sum = sum + (value - avg)^2
	end
	return math.sqrt(sum / count)
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

--+ Calls func using the provided arguments, deepcopies all arguments
function call_by_value(func, ...)
	return func(unpack(modlib.table.deepcopy{...}))
end

-- Functional wrappers for Lua's builtin metatable operators (arithmetic, concatenation, length, comparison, indexing, call)

function add(a, b)
	return a + b
end

function mul(a, b)
	return a * b
end

function div(a, b)
	return a / b
end

function mod(a, b)
	return a % b
end

function pow(a, b)
	return a ^ b
end

function unm(a)
	return -a
end

function concat(a, b)
	return a .. b
end

function len(a)
	return #a
end

function eq(a, b)
	return a == b
end

function lt(a, b)
	return a < b
end

function le(a, b)
	return a <= b
end

function index(object, key)
	return object[key]
end

function newindex(object, key, value)
	object[key] = value
end

function call(object, ...)
	object(...)
end

-- Functional wrappers for logical operators, suffixed with _ to avoid a syntax error

function not_(a)
	return not a
end

function and_(a, b)
	return a and b
end

function or_(a, b)
	return a or b
end

-- Export environment
return _ENV