local t = {}
t[t] = t

local t2 = modlib.table.deepcopy(t)
assert(t2[t2] == t2)

assert(modlib.table.equals_noncircular({[{}]={}}, {[{}]={}}))
assert(modlib.table.equals_content(t, t2))
assert(modlib.table.is_circular(t))
local equals_references = modlib.table.equals_references
assert(equals_references({}, {}))
assert(not equals_references({a = 1, b = 2}, {a = 1, b = 3}))
t = {}
t.a, t.b = t, t
t2 = {}
t2.a, t2.b = t2, t2
assert(equals_references(t, t2))
t = {}
t[t] = t
t2 = {}
t2[t2] = t2
assert(equals_references(t, t2))
local x, y = {}, {}
assert(not equals_references({[x] = x, [y] = y}, {[x] = y, [y] = x}))
assert(equals_references({[x] = x, [y] = y}, {[x] = x, [y] = y}))
assert(modlib.table.nilget({a = {b = {c = 42}}}, "a", "b", "c") == 42)
assert(modlib.table.nilget({a = {}}, "a", "b", "c") == nil)
assert(modlib.string.escape_magic_chars("%") == "%%")
local tests = {
    liquid_dir = false,
    liquid_raycast = false
}
if tests.liquid_dir then
    minetest.register_abm{
        label = "get_liquid_corner_levels & get_liquid_direction test",
        nodenames = {"default:water_flowing"},
        interval = 1,
        chance = 1,
        action = function(pos, node)
            assert(type(node) == "table")
            for _, corner_level in pairs(modlib.minetest.get_liquid_corner_levels(pos, node)) do
                minetest.add_particle{
                    pos = vector.add(pos, corner_level),
                    size = 2,
                    texture = "logo.png"
                }
            end
            local direction = modlib.minetest.get_liquid_flow_direction(pos, node)
            local start_pos = pos
            start_pos.y = start_pos.y + 1
            for i = 0, 5 do
                minetest.add_particle{
                    pos = vector.add(start_pos, vector.multiply(direction, i/5)),
                    size = i/2.5,
                    texture = "logo.png"
                }
            end
        end
    }
end
if tests.liquid_raycast then
    minetest.register_globalstep(function()
        for _, player in pairs(minetest.get_connected_players()) do
            local eye_pos = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)
            local raycast = modlib.minetest.raycast(eye_pos, vector.add(eye_pos, vector.multiply(player:get_look_dir(), 3)), false, true)
            for pointed_thing in raycast do
                if pointed_thing.type == "node" and minetest.registered_nodes[minetest.get_node(pointed_thing.under).name].liquidtype == "flowing" then
                    minetest.add_particle{
                        pos = vector.add(pointed_thing.intersection_point, vector.multiply(pointed_thing.intersection_normal, 0.1)),
                        size = 0.5,
                        texture = "object_marker_red.png",
                        expirationtime = 3
                    }
                end
            end
        end
    end)
end

local n = 100
local list = {}
for index = 1, n do
    list[index] = index
end
modlib.table.shuffle(list)
local heap = modlib.heap.new()
for index = 1, #list do
    heap:push(list[index])
end
for index = 1, #list do
    local popped = heap:pop()
    assert(popped == index)
end