local add = modlib.func.add

--+ For all functions which aggregate over single values, use modlib.table.ivalues - not ipairs - for lists!
--+ Otherwise they will be applied to the indices.
local iterator = {}

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