-- Localize globals
local math, math_floor, minetest, modlib_table_reverse, os, string_char, setmetatable, table_insert, table_concat
	= math, math.floor, minetest, modlib.table.reverse, os, string.char, setmetatable, table.insert, table.concat

local inf = math.huge

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

-- TODO might be too invasive
-- Make random random
math.randomseed(minetest and minetest.get_us_time() or os.time() + os.clock())
for _ = 1, 100 do math.random() end

negative_nan = 0/0
positive_nan = negative_nan ^ 1

function sign(number)
	if number ~= number then return number end -- nan
	if number == 0 then return 0 end
	if number < 0 then return -1 end
	if number > 0 then return 1 end
end

log = setmetatable({}, {
	__index = function(self, base)
		local div = math.log(base)
		local function base_log(number)
			return math.log(number) / div
		end
		self[base] = base_log
		return base_log
	end,
	__call = function(_, number, base)
		if not base then
			return math.log(number)
		end
		return math.log(number) / math.log(base)
	end
})

-- one-based mod
function onemod(number, modulus)
	return ((number - 1) % modulus) + 1
end

function round(number, steps)
	steps = steps or 1
	return math_floor(number * steps + 0.5) / steps
end

local c0 = ("0"):byte()
local cA = ("A"):byte()

function default_digit_function(digit)
	if digit <= 9 then return string_char(c0 + digit) end
	return string_char(cA + digit - 10)
end

default_precision = 10

-- See https://github.com/appgurueu/Luon/blob/master/index.js#L724
function tostring(number, base, digit_function, precision)
	if number ~= number then
		return "nan"
	end
	if number == inf then
		return "inf"
	end
	if number == -inf then
		return "-inf"
	end
	digit_function = digit_function or default_digit_function
	precision = precision or default_precision
	local out = {}
	if number < 0 then
		table_insert(out, "-")
		number = -number
	end
	-- Rounding
	number = number + base ^ -precision / 2
	local digit
	while number >= base do
		digit = math_floor(number % base)
		table_insert(out, digit_function(digit))
		number = (number - digit) / base
	end
	digit = math_floor(number)
	table_insert(out, digit_function(digit))
	modlib_table_reverse(out)
	number = number % 1
	if number ~= 0 and number >= base ^ -precision then
		table_insert(out, ".")
		while precision >= 0 and number >= base ^ -precision do
			number = number * base
			digit = math_floor(number % base)
			table_insert(out, digit_function(digit))
			number = number - digit
			precision = precision - 1
		end
	end
	return table_concat(out)
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
	local exp = math_floor(math.log(number, 2))
	local powexp = 2 ^ math.max(-126, math.min(exp, 127))
	local leading = exp < -127 and 0 or 1
	local mantissa = math_floor((leading - number / powexp) * 0x800000 + 0.5)
	if mantissa <= -0x800000 then
		return sign * inf
	end
	return sign * powexp * (leading - mantissa / 0x800000)
end

-- Export environment
return _ENV