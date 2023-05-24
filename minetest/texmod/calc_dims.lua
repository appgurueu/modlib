-- TODO ensure completeness, use table of dim calculation functions
local base_dims = modlib.table.set({
	"opacity",
	"invert",
	"brighten",
	"noalpha",
	"makealpha",
	"lowpart",
	"mask",
	"colorize",
})
local floor, max, clamp = math.floor, math.max, modlib.math.clamp
local function next_pow_of_2(x)
	-- I don't want to use a naive 2^ceil(log(x)/log(2)) due to possible float precision issues.
	local m, e = math.frexp(x) -- x = _*2^e, _ in [0.5, 1)
	if m == 0.5 then e = e - 1 end -- x = 2^(e-1)
	return math.ldexp(1, e) -- 2^e, premature optimization here we go
end
return function(self, get_file_dims)
	local function calc_dims(self)
		local type = self.type
		if type == "filename" then
			return get_file_dims(self.filename)
		end if base_dims[type] then
			return calc_dims(self.base)
		end if type == "resize" or type == "combine" then
			return self.w, self.h
		end if type == "overlay" then
			local base_w, base_h = calc_dims(self.base)
			local overlay_w, overlay_h = calc_dims(self.over)
			return max(base_w, overlay_w), max(base_h, overlay_h)
		end if type == "transform" then
			if self.rotation_deg % 180 ~= 0 then
				local base_w, base_h = calc_dims(self.base)
				return base_h, base_w
			end
			return calc_dims(self.base)
		end if type == "inventorycube" then
			local top_w, top_h = calc_dims(self.top)
			local left_w, left_h = calc_dims(self.left)
			local right_w, right_h = calc_dims(self.right)
			local d = clamp(next_pow_of_2(max(top_w, top_h, left_w, left_h, right_w, right_h)), 2, 64)
			return d, d
		end if type == "verticalframe" or type == "crack" or type == "cracko" then
			local base_w, base_h = calc_dims(self.base)
			return base_w, floor(base_h / self.framecount)
		end if type == "sheet" then
			local base_w, base_h = calc_dims(self.base)
			return floor(base_w / self.w), floor(base_h / self.h)
		end
		error("unsupported texture modifier: " .. type)
	end
	return calc_dims(self)
end