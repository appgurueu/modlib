local texmod = ...
local colorspec = modlib.minetest.colorspec

-- Generator readers

local gr = {}

function gr.png(r)
	r:expect":"
	local base64 = r:match_str"[a-zA-Z0-9+/=]"
	return assert(minetest.decode_base64(base64), "invalid base64")
end

function gr.inventorycube(r)
	local top = r:invcubeside()
	local left = r:invcubeside()
	local right = r:invcubeside()
	return top, left, right
end

function gr.combine(r)
	r:expect":"
	local w = r:int()
	r:expect"x"
	local h = r:int()
	local blits = {}
	while r:match":" do
		if r.eof then break end -- we can just end with `:`, right?
		local x = r:int()
		r:expect","
		local y = r:int()
		r:expect"="
		table.insert(blits, {x = x, y = y, texture = r:subtexp()})
	end
	return w, h, blits
end

-- Parameter readers

local pr = {}

function pr.brighten() end

function pr.noalpha() end

function pr.resize(r)
	r:expect":"
	local w = r:int()
	r:expect"x"
	local h = r:int()
	return w, h
end

function pr.makealpha(r)
	r:expect":"
	local red = r:int()
	r:expect","
	local green = r:int()
	r:expect","
	local blue = r:int()
	return red, green, blue
end

function pr.opacity(r)
	r:expect":"
	local ratio = r:int()
	return ratio
end

function pr.invert(r)
	r:expect":"
	local channels = {}
	while true do
		local c = r:match_charset"[rgba]"
		if not c then break end
		channels[c] = true
	end
	return channels
end

do
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
	function pr.transform(r)
		-- Note: While it isn't documented, `[transform` is indeed case-insensitive.
		if r:match_charset"[iI]" then
			return
		end
		local flip_axis
		if r:match_charset"[fF]" then
			flip_axis = assert(r:match_charset"[xXyY]", "axis expected"):lower()
		end
		local rot_deg
		if r:match_charset"[rR]" then
			rot_deg = r:int()
		end
		if flip_axis or rot_deg then
			return flip_axis, rot_deg
		end
		local transform = assert(transforms[r:int()], "out of range")
		return transform.flip_axis, transform.rotation_deg
	end
end

function pr.verticalframe(r)
	r:expect":"
	local framecount = r:int()
	r:expect":"
	local frame = r:int()
	return framecount, frame
end

function pr.crack(r)
	r:expect":"
	local framecount = r:int()
	r:expect":"
	local frame = r:int()
	if r:match":" then
		return framecount, frame, r:int()
	end
	return framecount, frame
end
pr.cracko = pr.crack

function pr.sheet(r)
	r:expect":"
	local w = r:int()
	r:expect"x"
	local h = r:int()
	r:expect":"
	local x = r:int()
	r:expect","
	local y = r:int()
	return w, h, x, y
end

function pr.multiply(r)
	r:expect":"
	return r:colorspec()
end

function pr.colorize(r)
	r:expect":"
	local color = r:colorspec()
	if not r:match":" then
		return color
	end
	if not r:match"a" then
		return color, r:int()
	end
	for c in ("lpha"):gmatch"." do
		r:expect(c)
	end
	return color, "alpha"
end

function pr.mask(r)
	r:expect":"
	return r:subtexp(r)
end

function pr.lowpart(r)
	r:expect":"
	local percent = r:int()
	assert(percent)
	r:expect":"
	return percent, r:subtexp()
end

-- Reader methods. We use `r` instead of the `self` "sugar" for consistency (and to save us some typing).
local rm = {}

function rm.peek(r)
	if r.eof then return end
	local expected_escapes = 0
	if r.level > 0 then
		-- Premature optimization my beloved (this is `2^(level-1)`)
		expected_escapes = math.ldexp(0.5, r.level)
	end
	if r.character:match"[&^:]" then
		if r.escapes == expected_escapes then return r.character end
	elseif r.escapes <= expected_escapes then
		return r.character
	elseif r.escapes >= 2*expected_escapes then
		return "\\"
	end
end
function rm.popchar(r)
	r.escapes = 0
	while true do
		r.character = r:read_char()
		if r.character ~= "\\" then break end
		r.escapes = r.escapes + 1
	end
	if r.character == nil then
		assert(r.escapes == 0, "end of texmod expected")
		r.eof = true
	end
end
function rm.pop(r)
	local expected_escapes = 0
	if r.level > 0 then
		-- Premature optimization my beloved (this is `2^(level-1)`)
		expected_escapes = math.ldexp(0.5, r.level)
	end
	if r.escapes > 0 and r.escapes >= 2*expected_escapes then
		r.escapes = r.escapes - 2*expected_escapes
		return
	end
	return r:popchar()
end
function rm.match(r, char)
	if r:peek() == char then
		r:pop()
		return true
	end
end
function rm.expect(r, char)
	if not r:match(char) then
		error(("%q expected"):format(char))
	end
end
function rm.hat(r)
	return r:match(r.invcube and "&" or "^")
end
function rm.match_charset(r, set)
	local char = r:peek()
	if char and char:match(set) then
		r:pop()
		return char
	end
end
function rm.match_str(r, set)
	local c = r:match_charset(set)
	if not c then
		error(("character in %s expected"):format(set))
	end
	local t = {c}
	while true do
		c = r:match_charset(set)
		if not c then break end
		table.insert(t, c)
	end
	return table.concat(t)
end
function rm.int(r)
	local sign = 1
	if r:match"-" then sign = -1 end
	return sign * tonumber(r:match_str"%d")
end
function rm.fname(r)
	-- This is overly permissive, as is Minetest;
	-- we just allow arbitrary characters up until a character which may terminate the name.
	-- Inside an inventorycube, `&` also terminates names.
	return r:match_str(r.invcube and "[^:^&){]" or "[^:^){]")
end
function rm.subtexp(r)
	r.level = r.level + 1
	local res = r:texp()
	r.level = r.level - 1
	return res
end
function rm.invcubeside(r)
	assert(not r.invcube, "can't nest inventorycube")
	r.invcube = true
	assert(r:match"{", "'{' expected")
	local res = r:texp()
	r.invcube = false
	return res
end
function rm.basexp(r)
	if r:match"(" then
		local res = r:texp()
		r:expect")"
		return res
	end
	if r:match"[" then
		local type = r:match_str"[a-z]"
		local gen_reader = gr[type]
		if not gen_reader then
			error("invalid texture modifier: " .. type)
		end
		return texmod[type](gen_reader(r))
	end
	return texmod.file(r:fname())
end
function rm.colorspec(r)
	-- Leave exact validation up to colorspec, only do a rough greedy charset matching
	return assert(colorspec.from_string(r:match_str"[#%xa-z]"))
end
function rm.texp(r)
	local base = r:basexp()
	while r:hat() do
		if r:match"[" then
			local type = r:match_str"[a-z]"
			local param_reader, gen_reader = pr[type], gr[type]
			if not (param_reader or gen_reader) then
				error("invalid texture modifier: " .. type)
			end
			if param_reader then
				base = base[type](base, param_reader(r))
			elseif gen_reader then
				base = base:overlay(texmod[type](gen_reader(r)))
			end
		else
			base = base:overlay(r:basexp())
		end
	end
	return base
end

local mt = {__index = rm}
return function(read_char)
	local r = setmetatable({
		level = 0,
		invcube = false,
		eof = false,
		read_char = read_char,
	}, mt)
	r:popchar()
	local res = r:texp()
	assert(r.eof, "eof expected")
	return res
end