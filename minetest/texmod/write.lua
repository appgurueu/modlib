local pw = {} -- parameter writers: `[type] = func(self, write)`

function pw:png(w)
	w.colon(); w.str(minetest.encode_base64(self.data))
end

function pw:combine(w)
	w.colon(); w.int(self.w); w.str"x"; w.str(self.h)
	for _, blit in ipairs(self.blits) do
		w.colon()
		w.int(blit.x); w.str","; w.int(blit.y); w.str"="
		w.esctex(blit.texture)
	end
end

-- Consider [inventorycube{a{b{c inside [combine: no need to escape &'s (but :'s need to be escaped)
-- Consider [combine inside inventorycube: need to escape &'s 

function pw:inventorycube(w)
	assert(not w.inventorycube, "[inventorycube may not be nested")
	local function write_side(side)
		w.str"{"
		w.inventorycube = true
		w.tex(self[side])
		w.inventorycube = false
	end
	write_side"top"
	write_side"left"
	write_side"right"
end

-- No parameters to write
pw.brighten = modlib.func.no_op
pw.noalpha = modlib.func.no_op

function pw:resize(w)
	w.colon(); w.int(self.w); w.str"x"; w.int(self.h)
end

function pw:makealpha(w)
	w.colon(); w.int(self.r); w.str","; w.int(self.g); w.str","; w.int(self.b)
end

function pw:opacity(w)
	w.colon(); w.int(self.ratio)
end

function pw:invert(w)
	w.colon()
	if self.r then w.str"r" end
	if self.g then w.str"g" end
	if self.b then w.str"b" end
	if self.a then w.str"a" end
end

function pw:transform(w)
	local rot_deg, flip_axis = self.rotation_deg or 0, self.flip_axis
	if rot_deg == 0 and flip_axis == nil then
		w.str"I"
	elseif rot_deg == 0 then
		w.str(assert(({x = "FX", y = "FY"})[flip_axis]))
	elseif flip_axis == nil then
		w.str"R"; w.int(self.rotation_deg)
	elseif rot_deg == 90 then
		w.str(assert(({x = "FX", y = "FY"})[flip_axis]))
		w.str"R90"
	elseif rot_deg == 180 then
		-- Rotating by 180° is equivalent to flipping both axes;
		-- if one axis was already flipped, that is undone -
		-- thus it is equivalent to flipping the other axis
		w.str(assert(({x = "FY", y = "FX"})[flip_axis]))
	elseif rot_deg == 270 then
		-- Rotating by 270° is equivalent to first rotating by 180°, then rotating by 90°;
		-- first flipping an axis and then rotating by 180°
		-- is equivalent to flipping the other axis as shown above
		w.str(assert(({x = "FY", y = "FX"})[flip_axis]))
		w.str"R90"
	end
end

function pw:verticalframe(w)
	w.colon(); w.int(self.framecount); w.colon(); w.int(self.frame)
end

function pw:crack(w)
	w.colon(); w.int(self.tilecount); w.colon(); w.int(self.framecount); w.colon(); w.int(self.frame)
end

pw.cracko = pw.crack

function pw:sheet(w)
	w.colon(); w.int(self.w); w.str"x"; w.int(self.h); w.colon(); w.int(self.x); w.str","; w.int(self.y)
end

function pw:multiply(w)
	w.colon()
	w.str(self.color:to_string())
end

function pw:colorize(w)
	w.colon()
	w.str(self.color:to_string())
	if self.ratio then
		w.colon()
		if self.ratio == "alpha" then
			w.str"alpha"
		else
			w.int(self.ratio)
		end
	end
end

function pw:mask(w)
	w.colon(); w.esctex(self.mask)
end

function pw:lowpart(w)
	w.colon(); w.int(self.percent); w.colon(); w.esctex(self.over)
end

return function(self, write_str)
	-- We could use a metatable here, but it wouldn't really be worth it;
	-- it would save us instantiating a handful of closures at the cost of constant `__index` events
	-- and having to constantly pass `self`, increasing code complexity
	local w = {}
	w.inventorycube = false
	w.level = 0
	w.str = write_str
	function w.esc()
		if w.level == 0 then return end
		w.str(("\\"):rep(math.ldexp(0.5, w.level)))
	end
	function w.hat()
		-- Note: We technically do not need to escape `&` inside an [inventorycube which is nested inside [combine,
		-- but we do it anyways for good practice and since we have to escape `&` inside [combine inside [inventorycube.
		w.esc()
		w.str(w.inventorycube and "&" or "^")
	end
	function w.colon()
		w.esc(); w.str":"
	end
	function w.int(int)
		w.str(("%d"):format(int))
	end
	function w.tex(tex)
		if tex.type == "file" then
			assert(not tex.filename:find"[:^\\&{[]", "invalid character in filename")
			w.str(tex.filename)
			return
		end
		if tex.base then
			w.tex(tex.base)
			w.hat()
		end
		if tex.type == "overlay" then
			if tex.over.type ~= "file" then -- TODO also exclude [png, [combine and [inventorycube (generators)
				w.str"("; w.tex(tex.over); w.str")"
			else
				w.tex(tex.over)
			end
		else
			w.str"["
			w.str(tex.type)
			pw[tex.type](tex, w)
		end
	end
	function w.esctex(tex)
		w.level = w.level + 1
		w.tex(tex)
		w.level = w.level - 1
	end
	w.tex(self)
end