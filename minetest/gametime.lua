local gametime
core.register_globalstep(function(dtime)
	if gametime then
		gametime = gametime + dtime
		return
	end
	gametime = assert(core.get_gametime())
	function modlib.minetest.get_gametime()
		local imprecise_gametime = core.get_gametime()
		if imprecise_gametime > gametime then
			core.log("warning", "modlib.minetest.get_gametime(): Called after increment and before first globalstep")
			return imprecise_gametime
		end
		return gametime
	end
end)