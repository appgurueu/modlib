-- Localize globals
local math, modlib, pairs, setmetatable, string, table = math, modlib, pairs, setmetatable, string, table

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

function upper_first(text) return text:sub(1, 1):upper() .. text:sub(2) end

function lower_first(text) return text:sub(1, 1):lower() .. text:sub(2) end

function starts_with(text, start) return text:sub(1, start:len()) == start end

function ends_with(text, suffix) return text:sub(text:len() - suffix:len() + 1) == suffix end

function trim(text, to_remove)
	local j = 1
	for i = 1, string.len(text) do
		if text:sub(i, i) ~= to_remove then
			j = i
			break
		end
	end
	local k = 1
	for i = string.len(text), j, -1 do
		if text:sub(i, i) ~= to_remove then
			k = i
			break
		end
	end
	return text:sub(j, k)
end

function trim_begin(text, to_remove)
	local j = 1
	for i = 1, string.len(text) do
		if text:sub(i, i) ~= to_remove then
			j = i
			break
		end
	end
	return text:sub(j)
end

trim_left = trim_begin

function trim_end(text, to_remove)
	local k = 1
	for i = string.len(text), 1, -1 do
		if text:sub(i, i) ~= to_remove then
			k = i
			break
		end
	end
	return text:sub(1, k)
end

trim_right = trim_end

function trim_spacing(text)
	return text:match"^%s*(.-)%s*$"
end

local inputstream_metatable = {
	__index = {read = function(self, count)
		local cursor = self.cursor + 1
		self.cursor = self.cursor + count
		local text = self.text:sub(cursor, self.cursor)
		return text ~= "" and text or nil
	end}
}
function inputstream(text)
	return setmetatable({text = text, cursor = 0}, inputstream_metatable)
end

function hexdump(text)
	local dump = {}
	for index = 1, text:len() do
		dump[index] = ("%02X"):format(text:byte(index))
	end
	return table.concat(dump)
end

function split(text, delimiter, limit, is_regex)
	limit = limit or math.huge
	local no_regex = not is_regex
	local parts = {}
	local occurences = 1
	local last_index = 1
	local index = string.find(text, delimiter, 1, no_regex)
	while index and occurences < limit do
		table.insert(parts, string.sub(text, last_index, index - 1))
		last_index = index + string.len(delimiter)
		index = string.find(text, delimiter, index + string.len(delimiter), no_regex)
		occurences = occurences + 1
	end
	table.insert(parts, string.sub(text, last_index))
	return parts
end

function split_without_limit(text, delimiter, is_regex) return split(text, delimiter, nil, is_regex) end

split_unlimited = split_without_limit

function split_lines(text, limit) return modlib.text.split(text, "\r?\n", limit, true) end

function lines(text) return text:gmatch"[^\r\n]*" end

local zero = string.byte"0"
local nine = string.byte"9"
local letter_a = string.byte"A"
local letter_f = string.byte"F"

function is_hexadecimal(byte)
	return byte >= zero and byte <= nine or byte >= letter_a and byte <= letter_f
end

magic_chars = {
	"%",
	"(",
	")",
	".",
	"+",
	"-",
	"*",
	"?",
	"[",
	"^",
	"$"
}
local magic_charset = {}
for _, magic_char in pairs(magic_chars) do table.insert(magic_charset, "%" .. magic_char) end
magic_charset = "[" .. table.concat(magic_charset) .. "]"

function escape_magic_chars(text) return text:gsub("(" .. magic_charset .. ")", "%%%1") end

function utf8(number)
	if number <= 0x007F then
		-- Single byte
		return string.char(number)
	end
	if number < 0x00A0 or number > 0x10FFFF then
		-- Out of range
		return
	end
	local result = ""
	local i = 0
	while true do
		local remainder = number % 64
		result = string.char(128 + remainder) .. result
		number = (number - remainder) / 64
		i = i + 1
		if number <= 2 ^ (8 - i - 2) then break end
	end
	return string.char(256 - 2 ^ (8 - i - 1) + number) .. result
end

--+ deprecated
function handle_ifdefs(code, vars)
	local finalcode = {}
	local endif
	local after_endif = -1
	local ifdef_pos, after_ifdef = string.find(code, "--IFDEF", 1, true)
	while ifdef_pos do
		table.insert(finalcode, string.sub(code, after_endif + 2, ifdef_pos - 1))
		local linebreak = string.find(code, "\n", after_ifdef + 1, true)
		local varname = string.sub(code, after_ifdef + 2, linebreak - 1)
		endif, after_endif = string.find(code, "--ENDIF", linebreak + 1, true)
		if not endif then break end
		if vars[varname] then
			table.insert(finalcode, string.sub(code, linebreak + 1, endif - 1))
		end
		ifdef_pos, after_ifdef = string.find(code, "--IFDEF", after_endif + 1, true)
	end
	table.insert(finalcode, string.sub(code, after_endif + 2))
	return table.concat(finalcode, "")
end

local keywords = modlib.table.set{"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}
keywords["goto"] = true -- Lua 5.2 (LuaJIT) support

function is_keyword(text)
	return keywords[text]
end

function is_identifier(text)
	return (not keywords[text]) and text:match"^[A-Za-z_][A-Za-z%d_]*$"
end

-- Export environment
return _ENV