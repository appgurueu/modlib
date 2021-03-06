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
	local function check_entry(key, value)
		assert(tab[key] == value)
		tab[key] = nil
	end
	func.iterate(check_entry, pairs, tab)
	assert(next(tab) == nil)

	tab = {a = 1, b = 2}
	local function pairs_callback(callback, tab)
		for k, v in pairs(tab) do
			callback(k, v)
		end
	end
	for k, v in func.for_generator(pairs_callback, tab) do
		check_entry(k, v)
	end
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

-- hashlist
do
	local n = 100
	local list = hashlist.new{}
	for i = 1, n do
		list:push_tail(i)
	end
	for i = 1, n do
		local head = list:get_head()
		assert(head == list:pop_head(i) and head == i)
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

local function serializer_test(assert_preserves)
	-- TODO nan
	for _, constant in pairs{true, false, huge, -huge} do
		assert_preserves(constant)
	end
	-- Strings
	for i = 1, 1000 do
		assert_preserves(_G.table.concat(table.repetition(_G.string.char(i % 256), i)))
	end
	-- Numbers
	for _ = 1, 1000 do
		local int = random(-2^50, 2^50)
		assert(int % 1 == 0)
		assert_preserves(int)
		assert_preserves((random() - 0.5) * 2^random(-20, 20))
	end
	-- Simple tables
	assert_preserves{hello = "world", welt = "hallo"}
	assert_preserves{"hello", "hello", "hello"}
	local circular = {}
	circular[circular] = circular
	circular[1] = circular
	assert_preserves(circular)
	local mixed = {1, 2, 3}
	mixed[mixed] = mixed
	mixed.vec = {x = 1, y = 2, z = 3}
	mixed.vec2 = modlib.table.copy(mixed.vec)
	mixed.blah = "blah"
	assert_preserves(mixed)
	local a, b, c = {}, {}, {}
	a[a] = a; a[b] = b; a[c] = c;
	b[a] = a; b[b] = b; b[c] = c;
	c[a] = a; c[b] = b; c[c] = c;
	a.a = {"a", a = a}
	assert_preserves(a)
end

-- bluon
do
	local bluon = bluon
	serializer_test(function(object)
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
	end)
end

-- luon
do
	serializer_test(function(object)
		local serialized = luon:write_string(object)
		assert(table.equals_references(object, luon:read_string(serialized)), serialized)
	end)
	local nan = luon:read_string(luon:write_string(0/0))
	assert(nan ~= nan)
end

if not _G.minetest then return end

assert(minetest.luon:read_string(minetest.luon:write_string(ItemStack"")))

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
assert(colorspec.from_string"#694269":to_string() == "694269")

-- Persistence
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
-- SQLite3
do
	local sqlite3 = persistence.sqlite3(require"lsqlite3")
	local p = sqlite3.new("database.test.sqlite3", {})
    p:init()
    p:rewrite()
	p:set_root("key", "value")
    assert(p.root.key == "value")
	p:set_root("other key", "other value")
	p:set_root("key", "other value")
	p:set_root("key", nil)
	local x = {x = 1, y = 2}
	p:set_root("x1", x)
	p:set_root("x2", x)
	p:set_root("x2", nil)
	p:set_root("x1", nil)
	p:set_root("key", {a = 1, b = 2, c = {a = 1}})
	p:set_root("key", nil)
	p:set_root("key", {a = 1, b = 2, c = 3})
	local cyclic = {}
	cyclic.cycle = cyclic
	p:set_root("cyclic", cyclic)
	p:set_root("cyclic", nil)
	p:collectgarbage()
	p:defragment_ids()
	local rows = {}
	for row in p.database:rows"SELECT * FROM table_entries ORDER BY table_id, key_type, key" do
		_G.table.insert(rows, row)
	end
	assert(modlib.table.equals(rows, {
		{1, 3, "key", 4, 2},
		{1, 3, "other key", 3, "other value"},
		{2, 3, "a", 2, 1},
		{2, 3, "b", 2, 2},
		{2, 3, "c", 2, 3}
	}))
	p:close()
	p = sqlite3.new("database.test.sqlite3", {})
	p:init()
	assert(modlib.table.equals(p.root, {
		key = {a = 1, b = 2, c = 3},
		["other key"] = "other value"
	}))
	p:close()
end

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