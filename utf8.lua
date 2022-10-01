local assert, error, select, string_char, table_concat
	= assert, error, select, string.char, table.concat

local utf8 = {}

function utf8.is_valid_codepoint(codepoint)
	-- Must be in bounds & must not be a surrogate
	return codepoint <= 0x10FFFF and (codepoint < 0xD800 or codepoint > 0xDFFF)
end

local function utf8_bytes(codepoint)
	if codepoint <= 0x007F then
		return codepoint
	end if codepoint <= 0x7FF then
		local payload_2 = codepoint % 0x40
		codepoint = (codepoint - payload_2) / 0x40
		return 0xC0 + codepoint, 0x80 + payload_2
	end if codepoint <= 0xFFFF then
		local payload_3 = codepoint % 0x40
		codepoint = (codepoint - payload_3) / 0x40
		local payload_2 = codepoint % 0x40
		codepoint = (codepoint - payload_2) / 0x40
		return 0xE0 + codepoint, 0x80 + payload_2, 0x80 + payload_3
	end if codepoint <= 0x10FFFF then
		local payload_4 = codepoint % 0x40
		codepoint = (codepoint - payload_4) / 0x40
		local payload_3 = codepoint % 0x40
		codepoint = (codepoint - payload_3) / 0x40
		local payload_2 = codepoint % 0x40
		codepoint = (codepoint - payload_2) / 0x40
		return 0xF0 + codepoint, 0x80 + payload_2, 0x80 + payload_3, 0x80 + payload_4
	end error"codepoint out of range"
end

function utf8.char(...)
	local n_args = select("#", ...)
	if n_args == 0 then return end
	local chars = {}
	for i = 1, n_args do
		chars[i] = string_char(utf8_bytes(select(i, ...)))
	end
	return table_concat(chars)
end

-- Overly permissive pattern that greedily matches a single UTF-8 codepoint
utf8.charpattern = "[%z-\127\194-\253][\128-\191]*"

return utf8