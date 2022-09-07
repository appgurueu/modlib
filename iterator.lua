local coroutine_create, coroutine_resume, coroutine_yield, coroutine_status, unpack
	= coroutine.create, coroutine.resume, coroutine.yield, coroutine.status, unpack

local add = modlib.func.add

--+ For all functions which aggregate over single values, use modlib.table.ivalues - not ipairs - for lists!
--+ Otherwise they will be applied to the indices.
local iterator = {}

-- Equivalent to `for x, y, z in iterator, state, ... do callback(x, y, z) end`
function iterator.foreach(callback, iterator, state, ...)
	local function loop(...)
		if ... == nil then return end
		callback(...)
		return loop(iterator(state, ...))
	end
	return loop(iterator(state, ...))
end

function iterator.for_generator(caller, ...)
	local co = coroutine_create(function(...)
		return caller(function(...)
			return coroutine_yield(...)
		end, ...)
	end)
	local args = {...}
	return function()
		if coroutine_status(co) == "dead" then
			return
		end
		local function _iterate(status, ...)
			if not status then
				error((...))
			end
			return ...
		end
		return _iterate(coroutine_resume(co, unpack(args)))
	end
end

function iterator.range(from, to, step)
	if not step then
		if not to then
			from, to = 1, from
		end
		step = 1
	end

	return function(_, current)
		current = current + step
		if current > to then
			return
		end
		return current
	end, nil, from - step
end

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

-- TODO iterator.max

function iterator.count(...)
	local count = 0
	for _ in ... do
		count = count + 1
	end
	return count
end

function iterator.sum(...)
	return iterator.aggregate(add, 0, ...)
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
-- A single pass method for calculating the standard deviation exists but is highly inaccurate
function iterator.standard_deviation(...)
	local avg = iterator.average(...)
	local count = 0
	local sum = 0
	for value in ... do
		count = count + 1
		sum = sum + (value - avg)^2
	end
	return (sum / count)^.5
end

return iterator