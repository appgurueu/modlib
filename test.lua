local t = {}
t[t] = t

local t2 = modlib.table.deepcopy(t)
assert(t2[t2] == t2)

assert(modlib.table.equals_noncircular({[{}]={}}, {[{}]={}}))
minetest.register_abm{
    label = "get_liquid_corner_levels & get_liquid_direction test",
    nodenames = {"default:water_flowing"},
    interval = 1,
    chance = 1,
    action = function(pos, node)
        assert(type(node) == "table")
        for _, corner_level in pairs(modlib.minetest.get_liquid_corner_levels(pos, node)) do
            minetest.add_particle{
                pos = vector.subtract(vector.add(pos, corner_level), 0.5),
                size = 2,
                texture = "logo.png"
            }
        end
        local direction = modlib.minetest.get_liquid_flow_direction(pos, node)
        local start_pos = pos
        start_pos.y = start_pos.y + 1
        for i = 0, 20 do
            minetest.add_particle{
                pos = vector.add(start_pos, vector.multiply(direction, i/20)),
                size = i/10,
                texture = "logo.png"
            }
        end
    end
}