-- ensure modlib API isn't leaking into global environment
assert(modlib.bluon.assert ~= assert)

local random, huge = math.random, math.huge
local parent_env = getfenv(1)
setfenv(1, setmetatable({}, {
	__index = function(_, key)
		local value = modlib[key]
		if value ~= nil then
			return value
		end
		return parent_env[key]
	end,
	__newindex = function(_, key, value)
		error(dump{key = key, value = value})
	end
}))

-- func
do
	local tab = {a = 1, b = 2}
	func.iterate(function(key, value)
		assert(tab[key] == value)
		tab[key] = nil
	end, pairs, tab)
	assert(next(tab) == nil)
	assert(func.aggregate(func.add, 1, 2, 3) == 6)
end

-- string
assert(string.escape_magic_chars"%" == "%%")

-- table
do
	local tab = {}
	tab[tab] = tab
	local table_copy = table.deepcopy(tab)
	assert(table_copy[table_copy] == table_copy)
	assert(table.is_circular(tab))
	assert(not table.is_circular{a = 1})
	assert(table.equals_noncircular({[{}]={}}, {[{}]={}}))
	assert(table.equals_content(tab, table_copy))
	local equals_references = table.equals_references
	assert(equals_references(tab, table_copy))
	assert(equals_references({}, {}))
	assert(not equals_references({a = 1, b = 2}, {a = 1, b = 3}))
	tab = {}
	tab.a, tab.b = tab, tab
	table_copy = table.deepcopy(tab)
	assert(equals_references(tab, table_copy))
	local x, y = {}, {}
	assert(not equals_references({[x] = x, [y] = y}, {[x] = y, [y] = x}))
	assert(equals_references({[x] = x, [y] = y}, {[x] = x, [y] = y}))
	local nilget = table.nilget
	assert(nilget({a = {b = {c = 42}}}, "a", "b", "c") == 42)
	assert(nilget({a = {}}, "a", "b", "c") == nil)
	assert(nilget(nil, "a", "b", "c") == nil)
	assert(nilget(nil, "a", nil, "c") == nil)
	local rope = table.rope{}
	rope:write"hello"
	rope:write" "
	rope:write"world"
	assert(rope:to_text() == "hello world", rope:to_text())
	tab = {a = 1, b = {2}}
	tab[3] = tab
	local contents = {
		a = 1,
		[1] = 1,
		b = 1,
		[tab.b] = 1,
		[2] = 1,
		[tab] = 1,
		[3] = 1
	}
	table.deep_foreach_any(tab, function(content)
		assert(contents[content], content)
		contents[content] = 2
	end)
	for _, value in pairs(contents) do
		assert(value == 2)
	end
end

-- heap
do
	local n = 100
	local list = {}
	for index = 1, n do
		list[index] = index
	end
	table.shuffle(list)
	local heap = heap.new()
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
	local ranked_set = ranked_set.new()
	local list = {}
	for i = 1, n do
		ranked_set:insert(i)
		list[i] = i
	end

	assert(table.equals(ranked_set:to_table(), list))

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

	local ranked_set = ranked_set.new()
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

-- k-d-tree
local vectors = {}
for _ = 1, 1000 do
	_G.table.insert(vectors, {random(), random(), random()})
end
local kdtree = kdtree.new(vectors)
for _, v in ipairs(vectors) do
	local neighbor, distance = kdtree:get_nearest_neighbor(v)
	assert(vector.equals(v, neighbor), distance == 0)
end

for _ = 1, 1000 do
	local v = {random(), random(), random()}
	local _, distance = kdtree:get_nearest_neighbor(v)
	local min_distance = huge
	for _, w in ipairs(vectors) do
		local other_distance = vector.distance(v, w)
		if other_distance < min_distance then
			min_distance = other_distance
		end
	end
	assert(distance == min_distance)
end

-- bluon
do
	local bluon = bluon
	local function assert_preserves(object)
		local rope = table.rope{}
		local written, read, input
		local _, err = pcall(function()
			bluon:write(object, rope)
			written = rope:to_text()
			input = text.inputstream(written)
			read = bluon:read(input)
			local remaining = input:read(1000)
			assert(not remaining)
		end)
		assertdump(table.equals_references(object, read) and not err, {
			object = object,
			read = read,
			written = written and text.hexdump(written),
			err = err
		})
	end
	for _, constant in pairs{true, false, huge, -huge} do
		assert_preserves(constant)
	end
	for i = 1, 1000 do
		assert_preserves(_G.table.concat(table.repetition(_G.string.char(i % 256), i)))
	end
	for _ = 1, 1000 do
		local int = random(-2^50, 2^50)
		assert(int % 1 == 0)
		assert_preserves(int)
		assert_preserves((random() - 0.5) * 2^random(-20, 20))
	end
	assert_preserves{hello = "world", welt = "hallo"}
	assert_preserves{"hello", "hello", "hello"}
	local a = {}
	a[a] = a
	a[1] = a
	assert_preserves(a)
end

if not _G.minetest then return end

-- colorspec
local colorspec = minetest.colorspec
local function test_from_string(string, number)
	local spec = colorspec.from_string(string)
	local expected = colorspec.from_number(number)
	assertdump(table.equals(spec, expected), {expected = expected, actual = spec})
end
local spec = colorspec.from_number(0xDDCCBBAA)
assertdump(table.equals(spec, {a = 0xAA, b = 0xBB, g = 0xCC, r = 0xDD}), spec)
test_from_string("aliceblue", 0xf0f8ffff)
test_from_string("aliceblue#42", 0xf0f8ff42)
test_from_string("#333", 0x333333FF)
test_from_string("#694269", 0x694269FF)
test_from_string("#11223344", 0x11223344)

local function test_logfile(reference_strings)
	local logfile = persistence.lua_log_file.new(mod.get_resource"logfile.test.lua", {}, reference_strings)
	logfile:init()
	logfile.root = {a_longer_string = "test"}
	logfile:rewrite()
	logfile:set_root({a = 1}, {b = 2, c = 3, d = _G.math.huge, e = -_G.math.huge})
	local circular = {}
	circular[circular] = circular
	logfile:set_root(circular, circular)
	logfile:close()
	logfile:init()
	assert(table.equals_references(logfile.root, {
		a_longer_string = "test",
		[{a = 1}] = {b = 2, c = 3, d = _G.math.huge, e = -_G.math.huge},
		[circular] = circular,
	}))
	if not reference_strings then
		for key in pairs(logfile.references) do
			assert(type(key) ~= "string")
		end
	end
end
test_logfile(true)
test_logfile(false)

-- in-game tests & b3d testing
local tests = {
	-- depends on player_api
	b3d = false,
	liquid_dir = false,
	liquid_raycast = false
}
if tests.b3d then
	local stream = io.open(mod.get_resource("player_api", "models", "character.b3d"), "r")
	assert(stream)
	local b3d = b3d.read(stream)
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
	file.write(mod.get_resource"character.b3d.lua", "return " .. dump(_b3d_truncate(table.copy(b3d))))
	stream:close()
end
local vector, minetest, ml_mt = _G.vector, _G.minetest, minetest
if tests.liquid_dir then
	minetest.register_abm{
		label = "get_liquid_corner_levels & get_liquid_direction test",
		nodenames = {"group:liquid"},
		interval = 1,
		chance = 1,
		action = function(pos, node)
			assert(type(node) == "table")
			for _, corner_level in pairs(ml_mt.get_liquid_corner_levels(pos, node)) do
				minetest.add_particle{
					pos = vector.add(pos, corner_level),
					size = 2,
					texture = "logo.png"
				}
			end
			local direction = ml_mt.get_liquid_flow_direction(pos, node)
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
			local raycast = ml_mt.raycast(eye_pos, vector.add(eye_pos, vector.multiply(player:get_look_dir(), 3)), false, true)
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