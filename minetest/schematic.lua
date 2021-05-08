schematic = {}
local metatable = {__index = schematic}

function schematic.setmetatable(self)
    return setmetatable(self, metatable)
end

function schematic.create(self, pos_min, pos_max)
    -- Don't use the metatable for the defaults to force a serialization
    self.baked_light = self.backed_light or false
    self.meta_data = self.meta_data or true
    self.size = vector.subtract(pos_max, pos_min)
    local voxelmanip = minetest.get_voxel_manip(pos_min, pos_max)
    local emin, emax = voxelmanip:read_from_map(pos_min, pos_max)
    local voxelarea = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local meta_data = {}
    for _, pos in ipairs(minetest.find_nodes_with_meta(pos_min, pos_max)) do
        local meta = minetest.get_meta(pos):to_table()
        if next(meta.fields) ~= nil or next(meta.inventory) ~= nil then
            meta_data[voxelarea:indexp(pos)] = meta
        end
    end
    local data, light_data, param2_data = voxelmanip:get_data(), self.baked_light and voxelmanip:get_light_data() or {}, voxelmanip:get_param2_data()
    local nodes = {}
    for index in voxelarea:iterp(pos_min, pos_max) do
        if data[index] == minetest.CONTENT_UNKNOWN or data[index] == minetest.CONTENT_IGNORE then
            error("unknown or ignore node at " .. minetest.pos_to_string(voxelarea:position(index)))
        end
        table.insert(nodes, {
            name = minetest.get_name_from_content_id(data[index]),
            light = light_data[index],
            param2 = param2_data[index],
            meta = meta_data[index]
        })
    end
    self.nodes = nodes
    return schematic.setmetatable(self)
end

function schematic:write_to_voxelmanip(voxelmanip, pos_min)
    local pos_max = vector.add(pos_min, self.size)
    local emin, emax = voxelmanip:read_from_map(pos_min, pos_max)
    local voxelarea = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local data, light_data, param2_data = voxelmanip:get_data(), self.baked_light and voxelmanip:get_light_data(), voxelmanip:get_param2_data()
    for _, pos in ipairs(minetest.find_nodes_with_meta(pos_min, pos_max)) do
        -- Clear all metadata. Due to an engine bug, nodes will actually have empty metadata.
        minetest.get_meta(pos):from_table{}
    end
    local i = 1
    for index in voxelarea:iterp(pos_min, pos_max) do
        local node = self.nodes[i]
        i = i + 1
        data[index] = minetest.get_content_id(node.name)
        if data[index] == nil then
            error(("unknown node %q"):format(node.name))
        end
        if self.baked_light then
            light_data[index] = node.light
        end
        param2_data[index] = node.param2
        if node.meta then
            -- TODO consider removing this check by using a separate table [index] = meta for node meta
            minetest.get_meta(voxelarea:position(index)):from_table(node.meta)
        end
    end
    voxelmanip:set_data(data)
    if self.baked_light then
        voxelmanip:set_light_data(light_data)
    end
    voxelmanip:set_param2_data(param2_data)
end

function schematic:place(pos_min)
    local pos_max = vector.add(pos_min, self.size)
    local voxelmanip = minetest.get_voxel_manip(pos_min, pos_max)
    self:write_to_voxelmanip(voxelmanip, pos_min)
    voxelmanip:write_to_map(not self.baked_light)
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