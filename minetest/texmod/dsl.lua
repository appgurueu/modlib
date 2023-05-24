local texmod = {}
local metatable = {__index = texmod}

local function new(self)
	return setmetatable(self, metatable)
end

-- `texmod{...}` may be used to create texture modifiers, bypassing the checks
setmetatable(texmod, {__call = new})

-- Constructors / "generators"

function texmod.file(filename)
	return new{
		type = "filename",
		filename = filename
	}
end

function texmod.png(data)
	assert(type(data) == "string")
	return new{
		type = "png",
		data = data
	}
end

function texmod.combine(w, h, blits)
	assert(w % 1 == 0 and w > 0)
	assert(h % 1 == 0 and h > 0)
	for _, blit in ipairs(blits) do
		assert(blit.x % 1 == 0)
		assert(blit.y % 1 == 0)
		assert(blit.texture)
	end
	return new{
		type = "combine",
		w = w,
		h = h,
		blits = blits
	}
end

function texmod.inventorycube(top, left, right)
	return new{
		type = "inventorycube",
		top = top,
		left = left,
		right = right
	}
end

-- Methods / "modifiers"

function texmod:overlay(overlay)
	return new{
		type = "overlay",
		base = self,
		over = overlay
	}
end

function texmod:brighten()
	return new{
		type = "brighten",
		base = self,
	}
end

function texmod:noalpha()
	return new{
		type = "noalpha",
		base = self
	}
end

function texmod:resize(w, h)
	assert(w % 1 == 0 and w > 0)
	assert(h % 1 == 0 and h > 0)
	return new{
		type = "resize",
		base = self,
		w = w,
		h = h,
	}
end

local function assert_uint8(num)
	assert(num % 1 == 0 and num >= 0 and num <= 0xFF)
end

function texmod:makealpha(r, g, b)
	assert_uint8(r); assert_uint8(g); assert_uint8(b)
	return new{
		type = "makealpha",
		base = self,
		r = r, g = g, b = b
	}
end

function texmod:opacity(ratio)
	assert_uint8(ratio)
	return new{
		type = "opacity",
		base = self,
		ratio = ratio
	}
end

local function tobool(val)
	return not not val
end

function texmod:invert(channels --[[set with keys "r", "g", "b", "a"]])
	return new{
		type = "invert",
		base = self,
		r = tobool(channels.r),
		g = tobool(channels.g),
		b = tobool(channels.b),
		a = tobool(channels.a)
	}
end

function texmod:flip(flip_axis --[["x" or "y"]])
	assert(flip_axis == "x" or flip_axis == "y")
	return new{
		type = "transform",
		base = self,
		flip_axis = flip_axis
	}
end

function texmod:rotate(deg)
	deg = deg % 360
	assert(deg % 90 == 0, "only multiples of 90° supported")
	return new{
		type = "transform",
		base = self,
		rotation_deg = deg
	}
end

-- First flip, then rotate counterclockwise
function texmod:transform(flip_axis, rotation_deg)
	assert(flip_axis == nil or flip_axis == "x" or flip_axis == "y")
	rotation_deg = (rotation_deg or 0) % 360
	assert(rotation_deg % 90 == 0, "only multiples of 90° supported")
	return new{
		type = "transform",
		base = self,
		rotation_deg = rotation_deg ~= 0 and rotation_deg or nil,
		flip_axis = flip_axis
	}
end

function texmod:verticalframe(framecount, frame)
	assert(framecount >= 1)
	assert(frame >= 0)
	return new{
		type = "verticalframe",
		base = self,
		framecount = framecount,
		frame = frame
	}
end

local function crack(self, name, ...)
	local tilecount, framecount, frame
	if select("#", ...) == 2 then
		tilecount, framecount, frame = 1, ...
	else
		assert(select("#", ...) == 3, "invalid number of arguments")
		tilecount, framecount, frame = ...
	end
	assert(tilecount >= 1)
	assert(framecount >= 1)
	assert(frame >= 0)
	return new{
		type = name,
		base = self,
		tilecount = tilecount,
		framecount = framecount,
		frame = frame
	}
end

function texmod:crack(...)
	return crack(self, "crack", ...)
end

function texmod:cracko(...)
	return crack(self, "cracko", ...)
end
texmod.crack_with_opacity = texmod.cracko

function texmod:sheet(w, h, x, y)
	assert(w % 1 == 0 and w >= 1)
	assert(h % 1 == 0 and h >= 1)
	assert(x % 1 == 0 and x < w)
	assert(y % 1 == 0 and y < w)
	return new{
		type = "sheet",
		base = self,
		w = w,
		h = h,
		x = x,
		y = y
	}
end

local colorspec = modlib.minetest.colorspec

function texmod:multiply(color)
	return new{
		type = "multiply",
		base = self,
		color = colorspec.from_any(color) -- copies a given colorspec
	}
end

function texmod:colorize(color, ratio)
	color = colorspec.from_any(color) -- copies a given colorspec
	if ratio == "alpha" then
		assert(color.alpha or 0xFF == 0xFF)
	else
		ratio = ratio or color.alpha
		assert_uint8(ratio)
		if color.alpha == ratio then
			ratio = nil
		end
	end
	return new{
		type = "colorize",
		base = self,
		color = color,
		ratio = ratio
	}
end

function texmod:mask(mask)
	return new{
		type = "mask",
		base = self,
		mask = mask
	}
end

function texmod:lowpart(percent, overlay)
	assert(percent % 1 == 0 and percent >= 0 and percent <= 100)
	return new{
		type = "lowpart",
		base = self,
		percent = percent,
		over = overlay
	}
end

return texmod, metatable