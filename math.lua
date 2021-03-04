-- Make random random
math.randomseed(minetest and minetest.get_us_time() or os.time() + os.clock())
for _ = 1, 100 do math.random() end

function round(number, steps)
	steps = steps or 1
	return math.floor(number * steps + 0.5) / steps
end

local c0 = ("0"):byte()
local cA = ("A"):byte()

function default_digit_function(digit)
	if digit <= 9 then return string.char(c0 + digit) end
	return string.char(cA + digit - 10)
end

default_precision = 10

-- See https://github.com/appgurueu/Luon/blob/master/index.js#L724
function tostring(number, base, digit_function, precision)
	digit_function = digit_function or default_digit_function
	precision = precision or default_precision
	local out = {}
	if number < 0 then
		table.insert(out, "-")
		number = -number
	end
	number = number + base ^ -precision / 2
	local digit
	while number >= base do
		digit = math.floor(number % base)
		table.insert(out, digit_function(digit))
		number = number / base
	end
	digit = math.floor(number)
	table.insert(out, digit_function(digit))
	modlib.table.reverse(out)
	number = number % 1
	if number ~= 0 and number >= base ^ -precision then
		table.insert(out, ".")
		while precision >= 0 and number >= base ^ precision do
			number = number * base
			digit = math.floor(number % base)
			table.insert(out, digit_function(digit))
			number = number - digit
			precision = precision - 1
		end
	end
	return table.concat(out)
end

-- See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Math/fround#polyfill
function fround(number)
	if number == 0 or number ~= number then
		return number
	end
	local sign = 1
	if number < 0 then
		sign = -1
		number = -number
	end
	local exp = math.floor(math.log(number, 2))
	local powexp = 2 ^ math.max(-126, math.min(number, 127))
	local leading = exp < -127 and 0 or 1
	local mantissa = math.floor((leading - number / powexp) * 0x800000 + 0.5)
	if mantissa <= -0x800000 then
		return sign * math.huge
	end
	mantissa = mantissa / 0x800000
	return sign * powexp * (leading - mantissa), mantissa
end