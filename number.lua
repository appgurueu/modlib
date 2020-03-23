-- Number helpers
function round(number, steps) -- Rounds a number
    steps = steps or 1
    return math.floor(number * steps + 0.5) / steps
end
local c0 = ("0"):byte()
local cA = ("A"):byte()
function default_digit_function(digit)
    if digit <= 9 then
        return string.char(c0+digit)
    end
    return string.char(cA+digit-10)
end
default_precision = 10
function tostring(number, base, digit_function, precision)
    digit_function = digit_function or default_digit_function
    precision = precision or default_precision
    local out = {}
    if number < 0 then
        table.insert(out, "-")
        number = -number
    end
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
    if number >= math.pow(base, precision) then
        table.insert(out, ".")
        -- precision >= 0 eventually redundant
        while precision >= 0 and number >= math.pow(base, precision) do
            number = number * base
            digit = math.floor(number % base)
            table.insert(out, digit_function(digit))
            number = number - digit
            precision = precision - 1
        end
    end
    return table.concat(out)
end