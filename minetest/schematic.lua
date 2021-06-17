-- Localize globals
local VoxelArea, assert, error, io, ipairs, math, minetest, modlib, next, pairs, setmetatable, table, vector = VoxelArea, assert, error, io, ipairs, math, minetest, modlib, next, pairs, setmetatable, table, vector

-- Set environment
local _ENV = ...
setfenv(1, _ENV)

schematic = {}
local metatable = {__index = schematic}

function schematic.setmetatable(self)
    return setmetatable(self, metatable)
end

function schematic.create(self, pos_min, pos_max)
    self.size = vector.subtract(pos_max, pos_min)
    local voxelmanip = minetest.get_voxel_manip(pos_min, pos_max)
    local emin, emax = voxelmanip:read_from_map(pos_min, pos_max)
    local voxelarea = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local nodes, light_values, param2s = {}, self.light_values and {}, {}
    local vm_nodes, vm_light_values, vm_param2s = voxelmanip:get_data(), light_values and voxelmanip:get_light_data(), voxelmanip:get_param2_data()
    local node_names, node_ids = {}, {}
    local i = 0
    for index in voxelarea:iterp(pos_min, pos_max) do
        if nodes[index] == minetest.CONTENT_UNKNOWN or nodes[index] == minetest.CONTENT_IGNORE then
            error("unknown or ignore node at " .. minetest.pos_to_string(voxelarea:position(index)))
        end
        local name = minetest.get_name_from_content_id(vm_nodes[index])
        local id = node_ids[name]
        if not id then
            table.insert(node_names, name)
            id = #node_names
            node_ids[name] = id
        end
        i = i + 1
        nodes[i] = id
        if self.light_values then
            light_values[i] = vm_light_values[index]
        end
        param2s[i] = vm_param2s[index]
    end
    local metas = self.metas
    if metas or metas == nil then
        local indexing = vector.add(self.size, 1)
        metas = {}
        for _, pos in ipairs(minetest.find_nodes_with_meta(pos_min, pos_max)) do
            local meta = minetest.get_meta(pos):to_table()
            if next(meta.fields) ~= nil or next(meta.inventory) ~= nil then
                local relative = vector.subtract(pos, pos_min)
                metas[((relative.z * indexing.y) + relative.y) * indexing.x + relative.x] = meta
            end
        end
    end
    self.node_names = node_names
    self.nodes = nodes
    self.light_values = light_values
    self.param2s = param2s
    self.metas = metas
    return schematic.setmetatable(self)
end

function schematic:write_to_voxelmanip(voxelmanip, pos_min)
    local pos_max = vector.add(pos_min, self.size)
    local emin, emax = voxelmanip:read_from_map(pos_min, pos_max)
    local voxelarea = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local nodes, light_values, param2s, metas = self.nodes, self.light_values, self.param2s, self.metas
    local vm_nodes, vm_lights, vm_param2s = voxelmanip:get_data(), light_values and voxelmanip:get_light_data(), voxelmanip:get_param2_data()
    for _, pos in ipairs(minetest.find_nodes_with_meta(pos_min, pos_max)) do
        -- Clear all metadata. Due to an engine bug, nodes will actually have empty metadata.
        minetest.get_meta(pos):from_table{}
    end
    local content_ids = {}
    for index, name in ipairs(self.node_names) do
        content_ids[index] = assert(minetest.get_content_id(name), ("unknown node %q"):format(name))
    end
    local i = 0
    for index in voxelarea:iterp(pos_min, pos_max) do
        i = i + 1
        vm_nodes[index] = content_ids[nodes[i]]
        if light_values then
            vm_lights[index] = light_values[i]
        end
        vm_param2s[index] = param2s[i]
    end
    voxelmanip:set_data(vm_nodes)
    if light_values then
        voxelmanip:set_light_data(vm_lights)
    end
    voxelmanip:set_param2_data(vm_param2s)
    if metas then
        local indexing = vector.add(self.size, 1)
        for index, meta in pairs(metas) do
            local floored = math.floor(index / indexing.x)
            local relative = {
                x = index % indexing.x,
                y = floored % indexing.y,
                z = math.floor(floored / indexing.y)
            }
            minetest.get_meta(vector.add(relative, pos_min)):from_table(meta)
        end
    end
end

function schematic:place(pos_min)
    local pos_max = vector.add(pos_min, self.size)
    local voxelmanip = minetest.get_voxel_manip(pos_min, pos_max)
    self:write_to_voxelmanip(voxelmanip, pos_min)
    voxelmanip:write_to_map(not self.light_values)
    return voxelmanip
end

function schematic:write_bluon(path)
    local file = io.open(path, "w")
    -- Header, short for "ModLib Bluon Schematic"
    file:write"MLBS"
    modlib.bluon:write(self, file)
    file:close()
end

function schematic.read_bluon(path)
    local file = io.open(path, "r")
    assert(file:read(4) == "MLBS", "not a modlib bluon schematic")
    local self = modlib.bluon:read(file)
    assert(not file:read(), "expected EOF")
    return schematic.setmetatable(self)
end

function schematic:write_zlib_bluon(path, compression)
    local file = io.open(path, "w")
    -- Header, short for "ModLib Zlib-compressed-bluon Schematic"
    file:write"MLZS"
    local rope = modlib.table.rope{}
    modlib.bluon:write(self, rope)
    local text = rope:to_text()
    file:write(minetest.compress(text, "deflate", compression or 9))
    file:close()
end

function schematic.read_zlib_bluon(path)
    local file = io.open(path, "r")
    assert(file:read(4) == "MLZS", "not a modlib zlib compressed bluon schematic")
    local self = modlib.bluon:read(modlib.text.inputstream(minetest.decompress(file:read"*a", "deflate")))
    return schematic.setmetatable(self)
end