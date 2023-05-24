local texmod = ...
local colorspec = modlib.minetest.colorspec

local transforms = {
	[0] = {},
	{rotation_deg = 90},
	{rotation_deg = 180},
	{rotation_deg = 270},
	{flip_axis = "x"},
	{flip_axis = "x", rotation_deg = 90},
	{flip_axis = "y"},
	{flip_axis = "y", rotation_deg = 90},
}

return function(read_char)
	-- TODO this currently uses closures rather than passing around a "reader" object,
	-- which is inconsistent with the writer and harder to port to more static languages
	local level = 0
	local invcube = false
	local eof = false

	local escapes, character

	local function peek()
		if eof then return end
		local expected_escapes = 0
		if level > 0 then
			-- Premature optimization my beloved (this is `2^(level-1)`)
			expected_escapes = math.ldexp(0.5, level)
		end
		if character:match"[&^:]" then
			if escapes == expected_escapes then return character end
		elseif escapes <= expected_escapes then
			return character
		elseif escapes >= 2*expected_escapes then
			return "\\"
		end
	end

	local function popchar()
		escapes = 0
		while true do
			character = read_char()
			if character ~= "\\" then break end
			escapes = escapes + 1
		end
		if character == nil then
			assert(escapes == 0, "end of texmod expected")
			eof = true
		end
	end

	popchar()

	local function pop()
		local expected_escapes = 0
		if level > 0 then
			-- Premature optimization my beloved (this is `2^(level-1)`)
			expected_escapes = math.ldexp(0.5, level)
		end
		if escapes > 0 and escapes >= 2*expected_escapes then
			escapes = escapes - 2*expected_escapes
			return
		end
		return popchar()
	end

	local function match(char)
		if peek() == char then
			pop()
			return true
		end
	end

	local function expect(char)
		if not match(char) then
			error(("%q expected"):format(char))
		end
	end

	local function hat()
		return match(invcube and "&" or "^")
	end

	local function match_charset(set)
		local char = peek()
		if char and char:match(set) then
			pop()
			return char
		end
	end

	local function match_str(set)
		local c = match_charset(set)
		if not c then error ("character in " .. set .. " expected") end
		local t = {c}
		while true do
			c = match_charset(set)
			if not c then break end
			table.insert(t, c)
		end
		return table.concat(t)
	end

	local function int()
		local sign = 1
		if match"-" then sign = -1 end
		return sign * tonumber(match_str"%d")
	end

	local texp
	local function subtexp()
		level = level + 1
		local res = texp()
		level = level - 1
		return res
	end

	local read_base = {
		png = function()
			expect":"
			local base64 = match_str"[a-zA-Z0-9+/=]"
			return assert(minetest.decode_base64(base64), "invalid base64")
		end,
		inventorycube = function()
			local function read_side()
				assert(not invcube, "can't nest inventorycube")
				invcube = true
				assert(match"{", "'{' expected")
				local res = texp()
				invcube = false
				return res
			end
			local top = read_side()
			local left = read_side()
			local right = read_side()
			return top, left, right
		end,
		combine = function()
			expect":"
			local w = int()
			expect"x"
			local h = int()
			local blits = {}
			while match":" do
				if eof then break end -- we can just end with `:`, right?
				local x = int()
				expect","
				local y = int()
				expect"="
				level = level + 1
				local t = texp()
				level = level - 1
				table.insert(blits, {x = x, y = y, texture = t})
			end
			return w, h, blits
		end,
	}

	local function fname()
		-- This is overly permissive, as is Minetest;
		-- we just allow arbitrary characters up until a character which may terminate the name.
		-- Inside an inventorycube, `&` also terminates names.
		return match_str(invcube and "[^:^&){]" or "[^:^){]")
	end

	local function basexp()
		if match"(" then
			local res = texp()
			expect")"
			return res
		end
		if match"[" then
			local name = match_str"[a-z]"
			local reader = read_base[name]
			if not reader then
				error("invalid texture modifier: " .. name)
			end
			return texmod[name](reader())
		end
		return texmod.file(fname())
	end

	local function pcolorspec()
		-- Leave exact validation up to colorspec, only do a rough greedy charset matching
		return assert(colorspec.from_string(match_str"[#%xa-z]"))
	end

	local function crack()
		expect":"
		local framecount = int()
		expect":"
		local frame = int()
		if match":" then
			return framecount, frame, int()
		end
		return framecount, frame
	end

	local param_readers = {
		brighten = function()end,
		noalpha = function()end,
		resize = function()
			expect":"
			local w = int()
			expect"x"
			local h = int()
			return w, h
		end,
		makealpha = function()
			expect":"
			local r = int()
			expect","
			local g = int()
			expect","
			local b = int()
			return r, g, b
		end,
		opacity = function()
			expect":"
			local ratio = int()
			return ratio
		end,
		invert = function()
			expect":"
			local channels = {}
			while true do
				local c = match_charset"[rgba]"
				if not c then break end
				channels[c] = true
			end
			return channels
		end,
		transform = function()
			if match"I" then
				return
			end
			local flip_axis
			if match"F" then
				flip_axis = assert(match_charset"[XY]", "axis expected"):lower()
			end
			local rot_deg
			if match"R" then
				rot_deg = int()
			end
			if flip_axis or rot_deg then
				return flip_axis, rot_deg
			end
			local transform = assert(transforms[int()], "out of range")
			return transform.flip_axis, transform.rotation_deg
		end,
		verticalframe = function()
			expect":"
			local framecount = int()
			expect":"
			local frame = int()
			return framecount, frame
		end,
		crack = crack,
		cracko = crack,
		sheet = function()
			expect":"
			local w = int()
			expect"x"
			local h = int()
			expect":"
			local x = int()
			expect","
			local y = int()
			return w, h, x, y
		end,
		multiply = function()
			expect":"
			return pcolorspec()
		end,
		colorize = function()
			expect":"
			local color = pcolorspec()
			if not match":" then
				return color
			end
			if not match"a" then
				return color, int()
			end
			for c in ("lpha"):gmatch"." do
				expect(c)
			end
			return color, "alpha"
		end,
		mask = function()
			expect":"
			return subtexp()
		end,
		lowpart = function()
			expect":"
			local percent = int()
			assert(percent)
			expect":"
			return percent, subtexp()
		end,
	}

	function texp()
		local base = basexp()
		while hat() do
			if match"[" then
				local name = match_str"[a-z]"
				local param_reader = param_readers[name]
				local gen_reader = read_base[name]
				if not (param_reader or gen_reader) then
					error("invalid texture modifier: " .. name)
				end
				if param_reader then
					base = base[name](base, param_reader())
				elseif gen_reader then
					base = base:overlay(texmod[name](gen_reader()))
				end
			else
				base = base:overlay(basexp())
			end
		end
		return base
	end
	local res = texp()
	assert(eof, "eof expected")
	return res
end