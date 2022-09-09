local string_char = string.char

local utf8 = {}

function utf8.char(codepoint)
	if codepoint <= 0x007F then
		-- Single byte
		return string_char(codepoint)
	end
	if codepoint < 0x00A0 or codepoint > 0x10FFFF then
		-- Out of range
		return -- TODO (?) error instead
	end
	local result = ""
	local i = 0
	repeat
		local remainder = codepoint % 64
		result = string_char(128 + remainder) .. result
		codepoint = (codepoint - remainder) / 64
		i = i + 1
	until codepoint <= 2 ^ (8 - i - 2)
	return string_char(0x100 - 2 ^ (8 - i - 1) + codepoint) .. result
end

return utf8