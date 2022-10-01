local string_char, table_concat = string.char, table.concat

local utf8 = {}

function utf8.is_valid_codepoint(codepoint)
	-- Must be in bounds & must not be a surrogate
	return codepoint <= 0x10FFFF and (codepoint < 0xD800 or codepoint > 0xDFFF)
end

local function utf8_char(codepoint)
	if codepoint <= 0x007F then -- single byte
		return string_char(codepoint) -- UTF-8 encoded string
	end
	local result = ""
	local i = 0
	repeat
		local remainder = codepoint % 64
		result = string_char(128 + remainder) .. result
		codepoint = (codepoint - remainder) / 64
		i = i + 1
	until codepoint <= 2 ^ (8 - i - 2)

	return string_char(0x100 - 2 ^ (8 - i - 1) + codepoint) .. result -- UTF-8 encoded string
end

function utf8.char(...)
	local n_args = select("#", ...)
	if n_args == 1 then return utf8_char(...) end
	local chars = {}
	for i = 1, n_args do
		chars[i] = utf8_char(select(i, ...))
	end
	return table_concat(chars)
end

return utf8