-- string
assert(modlib.string.escape_magic_chars"%" == "%%")

-- table
do
    local table = {}
    table[table] = table
    local table_copy = modlib.table.deepcopy(table)
    assert(table_copy[table_copy] == table_copy)
    assert(modlib.table.is_circular(table))
    assert(not modlib.table.is_circular{a = 1})
    assert(modlib.table.equals_noncircular({[{}]={}}, {[{}]={}}))
    assert(modlib.table.equals_content(table, table_copy))
    local equals_references = modlib.table.equals_references
    assert(equals_references(table, table_copy))
    assert(equals_references({}, {}))
    assert(not equals_references({a = 1, b = 2}, {a = 1, b = 3}))
    table = {}
    table.a, table.b = table, table
    table_copy = modlib.table.deepcopy(table)
    assert(equals_references(table, table_copy))
    local x, y = {}, {}
    assert(not equals_references({[x] = x, [y] = y}, {[x] = y, [y] = x}))
    assert(equals_references({[x] = x, [y] = y}, {[x] = x, [y] = y}))
    local nilget = modlib.table.nilget
    assert(nilget({a = {b = {c = 42}}}, "a", "b", "c") == 42)
    assert(nilget({a = {}}, "a", "b", "c") == nil)
    assert(nilget(nil, "a", "b", "c") == nil)
    assert(nilget(nil, "a", nil, "c") == nil)
    local rope = modlib.table.rope{}
    rope:write"hello"
    rope:write" "
    rope:write"world"
    assert(rope:to_text() == "hello world", rope:to_text())
end

-- heap
do
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
end

-- ranked set
do
    local n = 100
    local ranked_set = modlib.ranked_set.new()
    local list = {}
    for i = 1, n do
        ranked_set:insert(i)
        list[i] = i
    end

    assert(modlib.table.equals(ranked_set:to_table(), list))

    local i = 0
    for rank, key in ranked_set:ipairs() do
        i = i + 1
        assert(i == key and i == rank)
        assert(ranked_set:get_by_rank(rank) == key)
        local rank, key = ranked_set:get(i)
        assert(key == i and i == rank)
    end
    assert(i == n)

    for i = 1, n do
        local _, v = ranked_set:delete(i)
        assert(v == i, i)
    end
    assert(not next(ranked_set:to_table()))

    local ranked_set = modlib.ranked_set.new()
    for i = 1, n do
        ranked_set:insert(i)
    end

    for rank, key in ranked_set:ipairs(10, 20) do
        assert(rank == key and key >= 10 and key <= 20)
    end

    for i = n, 1, -1 do
        local j = ranked_set:delete_by_rank(i)
        assert(j == i)
    end
end

-- colorspec
local colorspec = modlib.minetest.colorspec.from_number(0xDDCCBBAA)
assert(modlib.table.equals(colorspec, {a = 0xAA, b = 0xBB, g = 0xCC, r = 0xDD,}), dump(colorspec))

-- k-d-tree
local vectors = {}
for _ = 1, 1000 do
    table.insert(vectors, {math.random(), math.random(), math.random()})
end
local kdtree = modlib.kdtree.new(vectors)
for _, vector in ipairs(vectors) do
    local neighbor, distance = kdtree:get_nearest_neighbor(vector)
    assert(modlib.vector.equals(vector, neighbor), distance == 0)
end

for _ = 1, 1000 do
    local vector = {math.random(), math.random(), math.random()}
    local _, distance = kdtree:get_nearest_neighbor(vector)
    local min_distance = math.huge
    for _, other_vector in ipairs(vectors) do
        local other_distance = modlib.vector.distance(vector, other_vector)
        if other_distance < min_distance then
            min_distance = other_distance
        end
    end
    assert(distance == min_distance)
end

-- bluon
do
    local bluon = modlib.bluon
    local function assert_preserves(object)
        local rope = modlib.table.rope{}
        local written, read, input
        local _, err = pcall(function()
            bluon:write(object, rope)
            written = rope:to_text()
            input = modlib.text.inputstream(written)
            read = bluon:read(input)
            local remaining = input:read(1000)
            assert(not remaining)
        end)
        -- TODO assertdump
        assert(modlib.table.equals_references(object, read) and not err, dump{
            object = object,
            read = read,
            written = written and modlib.text.hexdump(written),
            err = err
        })
    end
    for _, constant in pairs{true, false, math.huge, -math.huge} do
        assert_preserves(constant)
    end
    for i = 1, 1000 do
        assert_preserves(table.concat(modlib.table.repetition(string.char(i % 256), i)))
    end
    for _ = 1, 1000 do
        local int = math.random(-2^50, 2^50)
        assert(int % 1 == 0)
        assert_preserves(int)
        assert_preserves((math.random() - 0.5) * 2^math.random(-20, 20))
    end
    assert_preserves{hello = "world", welt = "hallo"}
    assert_preserves{"hello", "hello", "hello"}
    local a = {}
    a[a] = a
    a[1] = a
    assert_preserves(a)
end

-- in-game tests & b3d testing
local tests = {
    -- depends on player_api
    b3d = false,
    liquid_dir = false,
    liquid_raycast = false
}
if tests.b3d then
    local stream = io.open(modlib.mod.get_resource("player_api", "models", "character.b3d"), "r")
    assert(stream)
    local b3d = modlib.b3d.read(stream)
    --! dirty helper method to create truncate tables with 10+ number keys
    local function _b3d_truncate(table)
        local count = 1
        for key, value in pairs(table) do
            if type(key) == "table" then
                _b3d_truncate(key)
            end
            if type(value) == "table" then
                _b3d_truncate(value)
            end
            count = count + 1
            if type(key) == "number" and count >= 9 and next(table, key) then
                if count == 9 then
                    table[key] = "TRUNCATED"
                else
                    table[key] = nil
                end
            end
        end
        return table
    end
    modlib.file.write(modlib.mod.get_resource"character.b3d.lua", "return " .. dump(_b3d_truncate(modlib.table.copy(b3d))))
    stream:close()
end
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