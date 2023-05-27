local texmod = {}
local metatable = {__index = texmod}

local function new(self)
	return setmetatable(self, metatable)
end

-- `texmod{...}` may be used to create texture modifiers, bypassing the checks
setmetatable(texmod, {__call = new})

-- Constructors / "generators"

function texmod.file(filename)
	-- See `TEXTURENAME_ALLOWED_CHARS` in Minetest (`src/network/networkprotocol.h`)
	assert(not filename:find"[^%w_.-]", "invalid characters in file name")
	return new{
		type = "file",
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
	return self:transform(assert(
		(flip_axis == "x" and "fx")
		or (flip_axis == "y" and "fy")
		or (not flip_axis and "i")))
end

function texmod:rotate(deg)
	assert(deg % 90 == 0)
	deg = deg % 360
	return self:transform(("r%d"):format(deg))
end

-- D4 group transformations (see https://proofwiki.org/wiki/Definition:Dihedral_Group_D4),
-- represented using indices into a table of matrices
-- TODO (...) try to come up with a more elegant solution
do
	-- Matrix multiplication for composition: First applies a, then b <=> b * a
	local function mat_2x2_compose(a, b)
		local a_1_1, a_1_2, a_2_1, a_2_2 = unpack(a)
		local b_1_1, b_1_2, b_2_1, b_2_2 = unpack(b)
		return {
			a_1_1 * b_1_1 + a_2_1 * b_1_2, a_1_2 * b_1_1 + a_2_2 * b_1_2;
			a_1_1 * b_2_1 + a_2_1 * b_2_2, a_1_2 * b_2_1 + a_2_2 * b_2_2
		}
	end
	local r90 ={
		0, -1;
		1, 0
	}
	local fx = {
		-1, 0;
		0, 1
	}
	local fy = {
		1, 0;
		0, -1
	}
	local r180 = mat_2x2_compose(r90, r90)
	local r270 = mat_2x2_compose(r180, r90)
	local fxr90 = mat_2x2_compose(fx, r90)
	local fyr90 = mat_2x2_compose(fy, r90)
	local transform_mats = {[0] = {1, 0; 0, 1}, r90, r180, r270, fx, fxr90, fy, fyr90}
	local transform_idx_by_name = {i = 0, r90 = 1, r180 = 2, r270 = 3, fx = 4, fxr90 = 5, fy = 6, fyr90 = 7}
	-- Lookup tables for getting the flipped axis / rotation angle
	local flip_by_idx = {
		[4] = "x",
		[5] = "x",
		[6] = "y",
		[7] = "y",
	}
	local rot_by_idx = {
		[1] = 90,
		[2] = 180,
		[3] = 270,
		[5] = 90,
		[7] = 90,
	}
	local idx_by_mat_2x2 = {}
	local function transform_idx(mat)
		-- note: assumes mat[i] in {-1, 0, 1}
		return mat[1] + 3*(mat[2] + 3*(mat[3] + 3*mat[4]))
	end
	for i = 0, 7 do
		idx_by_mat_2x2[transform_idx(transform_mats[i])] = i
	end
	-- Compute a multiplication table
	local composition_idx = {}
	local function ij_idx(i, j)
		return i*8 + j
	end
	for i = 0, 7 do
		for j = 0, 7 do
			composition_idx[ij_idx(i, j)] = assert(idx_by_mat_2x2[
				transform_idx(mat_2x2_compose(transform_mats[i], transform_mats[j]))])
		end
	end
	function texmod:transform(...)
		if select("#", ...) == 0 then return self end
		local idx = ...
		if type(idx) == "string" then
			idx = assert(transform_idx_by_name[idx:lower()])
		end
		local base = self
		if self.type == "transform" then
			-- Merge with a `^[transform` base image
			assert(transform_mats[idx])
			base = self.base
			idx = composition_idx[ij_idx(self.idx, idx)]
		end
		assert(transform_mats[idx])
		if idx == 0 then return base end -- identity
		return new{
			type = "transform",
			base = base,
			idx = idx,
			-- Redundantly store this information for convenience. Do not modify!
			flip_axis = flip_by_idx[idx],
			rotation_deg = rot_by_idx[idx] or 0,
		}:transform(select(2, ...))
	end
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
		ratio = ratio or color.alpha or 0xFF
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
