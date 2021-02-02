local metatable = {__index = getfenv(1)}

--! experimental
--+ Reads a single BB3D chunk from a stream
--+ Doing `assert(stream:read(1) == nil)` afterwards is recommended
--+ See `b3d_specification.txt` as well as https://github.com/blitz-research/blitz3d/blob/master/blitz3d/loader_b3d.cpp
--> B3D model
function read(stream)
    local left = 8

    local function byte()
        left = left - 1
        return assert(stream:read(1):byte())
    end

    local function int()
        local value = byte() + byte() * 0x100 + byte() * 0x10000 + byte() * 0x1000000
        if value >= 2^31 then
            return value - 2^32
        end
        return value
    end

    local function id()
        return int() + 1
    end

    local function optional_id()
        local id = int()
        if id == -1 then
            return
        end
        return id + 1
    end

    local function string()
        local rope = {}
        while true do
            left = left - 1
            local char = assert(stream:read(1))
            if char == "\0" then
                return table.concat(rope)
            end
            table.insert(rope, char)
        end
    end

    local function float()
        -- TODO properly truncate to single floating point
        local byte_4, byte_3, byte_2, byte_1 = byte(), byte(), byte(), byte()
        local sign = 1
        if byte_1 >= 0x80 then
            sign = -1
            byte_1 = byte_1 - 0x80
        end
        local exponent = byte_1 * 2
        if byte_2 >= 0x80 then
            byte_2 = byte_2 - 0x80
            exponent = exponent + 1
        end
        local mantissa = ((((byte_4 / 0x100) + byte_3) / 0x100) + byte_2) / 0x80
        if exponent == 0xFF then
            if mantissa == 0 then
                return sign * math.huge
            end
            -- TODO differentiate quiet and signalling NaN as well as positive and negative
            return 0/0
        end
        if exponent == 0 then
            -- subnormal value
            return sign * 2^-126 * mantissa
        end
        return sign * 2 ^ (exponent - 127) * (1 + mantissa)
    end

    local function float_array(length)
        local list = {}
        for index = 1, length do
            list[index] = float()
        end
        return list
    end

    local function color()
        return {
            r = float(),
            g = float(),
            b = float(),
            a = float()
        }
    end

    local function vector3()
        return float_array(3)
    end

    local function quaternion()
        return {[4] = float(), [1] = float(), [2] = float(), [3] = float()}
    end

    local function content()
        assert(left >= 0, stream:seek())
        return left ~= 0
    end

    local chunk
    local chunks = {
        TEXS = function()
            local textures = {}
            while content() do
                table.insert(textures, {
                    file = string(),
                    flags = int(),
                    blend = int(),
                    pos = float_array(2),
                    scale = float_array(2),
                    rotation = float()
                })
            end
            return textures
        end,
        BRUS = function()
            local brushes = {}
            brushes.n_texs = int()
            assert(brushes.n_texs <= 8)
            while content() do
                local brush = {
                    name = string(),
                    color = color(),
                    shininess = float(),
                    blend = float(),
                    fx = float(),
                    texture_id = {}
                }
                for index = 1, brushes.n_texs do
                    brush.texture_id[index] = optional_id()
                end
                table.insert(brushes, brush)
            end
            return brushes
        end,
        VRTS = function()
            local vertices = {
                flags = int(),
                tex_coord_sets = int(),
                tex_coord_set_size = int()
            }
            assert(vertices.tex_coord_sets <= 8 and vertices.tex_coord_set_size <= 4)
            local has_normal = (vertices.flags % 2 == 1) or nil
            local has_color = (math.floor(vertices.flags / 2) % 2 == 1) or nil
            while content() do
                local vertex = {
                    pos = vector3(),
                    normal = has_normal and vector3(),
                    color = has_color and color(),
                    tex_coords = {}
                }
                for tex_coord_set = 1, vertices.tex_coord_sets do
                    local tex_coords = {}
                    for tex_coord = 1, vertices.tex_coord_set_size do
                        tex_coords[tex_coord] = float()
                    end
                    vertex.tex_coords[tex_coord_set] = tex_coords
                end
                table.insert(vertices, vertex)
            end
            return vertices
        end,
        TRIS = function()
            local tris = {
                brush_id = id(),
                vertex_ids = {}
            }
            while content() do
                table.insert(tris.vertex_ids, {id(), id(), id()})
            end
            return tris
        end,
        MESH = function()
            local mesh = {
                brush_id = optional_id(),
                vertices = chunk{VRTS = true}
            }
            mesh.triangle_sets = {}
            repeat
                local tris = chunk{TRIS = true}
                table.insert(mesh.triangle_sets, tris)
            until not content()
            return mesh
        end,
        BONE = function()
            local bone = {}
            while content() do
                local vertex_id = id()
                assert(not bone[vertex_id], "duplicate vertex weight")
                local weight = float()
                if weight > 0 then
                    -- Many exporters include unneeded zero weights
                    bone[vertex_id] = weight
                end
            end
            return bone
        end,
        KEYS = function()
            local flags = int()
            local _flags = flags % 8
            local rotation, scale, position
            if _flags >= 4 then
                rotation = true
                _flags = _flags - 4
            end
            if _flags >= 2 then
                scale = true
                _flags = _flags - 2
            end
            position = _flags >= 1
            local bone = {
                flags = flags
            }
            while content() do
                table.insert(bone, {
                    frame = int(),
                    position = position and vector3() or nil,
                    scale = scale and vector3() or nil,
                    rotation = rotation and quaternion() or nil
                })
            end
            -- Ensure frames are sorted ascending
            table.sort(bone, function(a, b) return a.frame < b.frame end)
            return bone
        end,
        ANIM = function()
            return {
                -- flags are unused
                flags = int(),
                frames = int(),
                fps = float()
            }
        end,
        NODE = function()
            local node = {
                name = string(),
                position = vector3(),
                scale = vector3(),
                keys = {},
                rotation = quaternion(),
                children = {}
            }
            local node_type
            -- See https://github.com/blitz-research/blitz3d/blob/master/blitz3d/loader_b3d.cpp#L263
            -- Order is not validated; double occurences of mutually exclusive node def are
            while content() do
                local elem, type = chunk()
                if type == "MESH" then
                    assert(not node_type)
                    node_type = "mesh"
                    node.mesh = elem
                elseif type == "BONE" then
                    assert(not node_type)
                    node_type = "bone"
                    node.bone = elem
                elseif type == "KEYS" then
                    assert((node.keys[#node.keys] or {}).frame ~= (elem[1] or {}).frame, "duplicate frame")
                    modlib.table.append(node.keys, elem)
                elseif type == "NODE" then
                    table.insert(node.children, elem)
                elseif type == "ANIM" then
                    node.animation = elem
                else
                    assert(not node_type)
                    node_type = "pivot"
                end
            end
            -- TODO somehow merge keys
            return node
        end,
        BB3D = function()
            local version = int()
            local self = {
                version = {
                    major = math.floor(version / 100),
                    minor = version % 100,
                    raw = version
                },
                textures = {},
                brushes = {}
            }
            assert(self.version.major <= 2, "unsupported version: " .. self.version.major)
            while content() do
                local field, type = chunk{TEXS = true, BRUS = true, NODE = true}
                if type == "TEXS" then
                    modlib.table.append(self.textures, field)
                elseif type == "BRUS" then
                    modlib.table.append(self.brushes, field)
                else
                    self.node = field
                end
            end
            return self
        end
    }

    local function chunk_header()
        left = left - 4
        return stream:read(4), int()
    end

    function chunk(possible_chunks)
        local type, new_left = chunk_header()
        local parent_left
        left, parent_left = new_left, left
        if possible_chunks and not possible_chunks[type] then
            error("expected one of " .. table.concat(modlib.table.keys(possible_chunks), ", ") .. ", found " .. type)
        end
        local res = assert(chunks[type])()
        assert(left == 0)
        left = parent_left - new_left
        return res, type
    end

    local self = chunk{BB3D = true}
    return setmetatable(self, metatable)
end

-- TODO function write(self, stream)

local binary_search_frame = modlib.table.binary_search_comparator(function(a, b)
    return modlib.table.default_comparator(a, b.frame)
end)
function calculate_absolute_bone_properties(self, keyframe, interpolate)
    local function get_frame_values(keys)
        local values = keys[keyframe]
        if values and values.frame == keyframe then
            return {
                position = values.position,
                rotation = values.rotation,
                scale = values.scale
            }
        end
        local index = binary_search_frame(keys, keyframe)
        if index > 0 then
            return keys[index]
        end
        index = -index
        assert(index > 1 and index <= #keys)
        local a, b = keys[index - 1], keys[index]
        if not interpolate then
            return a
        end
        local ratio = (keyframe - a.frame) / (b.frame - a.frame)
        return {
            position = (a.position and b.position and modlib.vector.interpolate(a.position, b.position, ratio)) or a.position or b.position,
            rotation = (a.rotation and b.rotation and modlib.quaternion.interpolate(a.rotation, b.rotation, ratio)) or a.rotation or b.rotation,
            scale = (a.scale and b.scale and modlib.vector.interpolate(a.scale, b.scale, ratio)) or a.scale or b.scale,
        }
    end
    local absolute_bone_properties = {}
    local function calculate_absolute_properties(self, parent_properties)
        local properties = {
            name = self.name,
            position = self.position,
            rotation = self.rotation,
            scale = self.scale
        }
        if self.keys and next(self.keys) ~= nil then
            properties = modlib.table.add_all(properties, get_frame_values(self.keys))
        end
        if parent_properties then
            properties.position = modlib.vector.add(parent_properties.position, properties.position)
            properties.rotation = modlib.quaternion.multiply(parent_properties.rotation, properties.rotation)
            properties.scale = modlib.vector.multiply(parent_properties.scale, properties.scale)
        end
        if self.bone then
            table.insert(absolute_bone_properties, properties)
        end
        for _, child in ipairs(self.children or {}) do
            calculate_absolute_properties(child, properties)
        end
    end
    calculate_absolute_properties(self.node)
    return absolute_bone_properties
end