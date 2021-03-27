players = {}

registered_on_wielditem_changes = {function(...)
	local _, previous_item, _, item = ...
	if previous_item then
		((previous_item:get_definition()._modlib or {}).un_wield or modlib.func.no_op)(...)
	end
	if item then
		((item:get_definition()._modlib or {}).on_wield or modlib.func.no_op)(...)
	end
end}

--+ Registers an on_wielditem_change callback: function(player, previous_item, previous_index, item)
--+ Will be called once with player, nil, index, item on join
register_on_wielditem_change = modlib.func.curry(table.insert, registered_on_wielditem_changes)

minetest.register_on_mods_loaded(function()
	-- Other on_joinplayer / on_leaveplayer callbacks should execute first
	minetest.register_on_joinplayer(function(player)
		local item, index = player:get_wielded_item(), player:get_wield_index()
		players[player:get_player_name()] = {
			wield = {
				item = item,
				index = index
			}
		}
		modlib.table.icall(registered_on_wielditem_changes, player, nil, index, item)
	end)
	minetest.register_on_leaveplayer(function(player)
		players[player:get_player_name()] = nil
	end)
end)

minetest.register_globalstep(function()
	for _, player in pairs(minetest.get_connected_players()) do
		local item, index = player:get_wielded_item(), player:get_wield_index()
		local playerdata = players[player:get_player_name()]
		if not playerdata then return end
		local previous_item, previous_index = playerdata.wield.item, playerdata.wield.index
		if item:get_name() ~= previous_item or index ~= previous_index then
			playerdata.wield.item = item
			playerdata.wield.index = index
			modlib.table.icall(registered_on_wielditem_changes, player, previous_item, previous_index, item)
		end
	end
end)