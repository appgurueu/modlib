-- String helpers - split & trim at end & begin
function upper_first(str)
    return str:sub(1,1):upper()..str:sub(2)
end
function lower_first(str)
    return str:sub(1,1):lower()..str:sub(2)
end
function starts_with(str, start) return str:sub(1, start:len()) == start end
function ends_with(str, suffix)
    return str:sub(str:len() - suffix:len() + 1) == suffix
end
function trim(str, to_remove)
    local j = 1
    for i = 1, string.len(str) do
        if str:sub(i, i) ~= to_remove then
            j = i
            break
        end
    end

    local k = 1
    for i = string.len(str), j, -1 do
        if str:sub(i, i) ~= to_remove then
            k = i
            break
        end
    end

    return str:sub(j, k)
end

function trim_begin(str, to_remove)
    local j = 1
    for i = 1, string.len(str) do
        if str:sub(i, i) ~= to_remove then
            j = i
            break
        end
    end

    return str:sub(j)
end

function split(str, delim, limit)
    if not limit then return split_without_limit(str, delim) end
    local parts = {}
    local occurences = 1
    local last_index = 1
    local index = string.find(str, delim, 1, true)
    while index and occurences < limit do
        table.insert(parts, string.sub(str, last_index, index - 1))
        last_index = index + string.len(delim)
        index = string.find(str, delim, index + string.len(delim), true)
        occurences = occurences + 1
    end
    table.insert(parts, string.sub(str, last_index))
    return parts
end

function split_without_limit(str, delim)
    local parts = {}
    local last_index = 1
    local index = string.find(str, delim, 1, true)
    while index do
        table.insert(parts, string.sub(str, last_index, index - 1))
        last_index = index + string.len(delim)
        index = string.find(str, delim, index + string.len(delim), true)
    end
    table.insert(parts, string.sub(str, last_index))
    return parts
end

hashtag = string.byte("#")
zero = string.byte("0")
nine = string.byte("9")
letter_a = string.byte("A")
letter_f = string.byte("F")

function is_hexadecimal(byte)
    return (byte >= zero and byte <= nine) or
               (byte >= letter_a and byte <= letter_f)
end

magic_chars = {
    "%", "(", ")", ".", "+", "-", "*", "?", "[", "^", "$" --[[,":"]]
}

function escape_magic_chars(text)
    for _, magic_char in ipairs(magic_chars) do
        text = string.gsub(text, "%" .. magic_char, "%%" .. magic_char)
    end
    return text
end

function utf8(number)
    if number < 0x007F then return string.char(number) end
    if number < 0x00A0 or number > 0x10FFFF then -- Out of range
        return
    end
    local result = ""
    local i = 0
    while true do
        local remainder = number % 64
        result = string.char(128 + remainder) .. result
        number = (number - remainder) / 64
        i = i + 1
        if number <= math.pow(2, 8 - i - 2) then break end
    end
    return string.char(256 - math.pow(2, 8 - i - 1) + number) .. result -- 256 = math.pow(2, 8)
end

function handle_ifndefs(code, vars)
    local finalcode = {}
    local endif
    local after_endif = -1
    local ifndef_pos, after_ifndef = string.find(code, "--IFNDEF", 1, true)
    while ifndef_pos do
        table.insert(finalcode,
                     string.sub(code, after_endif + 2, ifndef_pos - 1))
        local linebreak = string.find(code, "\n", after_ifndef + 1, true)
        local varname = string.sub(code, after_ifndef + 2, linebreak - 1)
        endif, after_endif = string.find(code, "--ENDIF", linebreak + 1, true)
        if not endif then break end
        if vars[varname] then
            table.insert(finalcode, string.sub(code, linebreak + 1, endif - 1))
        end
        ifndef_pos, after_ifndef = string.find(code, "--IFNDEF",
                                               after_endif + 1, true)
    end
    table.insert(finalcode, string.sub(code, after_endif + 2))
    return table.concat(finalcode, "")
end
