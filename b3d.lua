-- Localize globals
local assert, error, math, modlib, next, ipairs, pairs, setmetatable, string_char, table
	= assert, error, math, modlib, next, ipairs, pairs, setmetatable, string.char, table

local read_int, read_single = modlib.binary.read_int, modlib.binary.read_single

local write_int, write_single = modlib.binary.write_int, modlib.binary.write_single

local fround = modlib.math.fround

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

local metatable = {__index = _ENV}

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
		return read_int(byte, 4)
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
		return read_single(byte)
	end

	local function float_array(length)
		local list = {}
		for index = 1, length do
			list[index] = float()
		end
		return list
	end

	local function color()
		local ret = {}
		ret.r = float()
		ret.g = float()
		ret.b = float()
		ret.a = float()
		return ret
	end

	local function vector3()
		return float_array(3)
	end

	local function quaternion()
		local w = float()
		local x = float()
		local y = float()
		local z = float()
		return {x, y, z, w}
	end

	local function content()
		if left < 0 then
			error(("unexpected EOF at position %d"):format(stream:seek()))
		end
		return left ~= 0
	end

	local chunk
	local chunks = {
		TEXS = function()
			local textures = {}
			while content() do
				local tex = {}
				tex.file = string()
				tex.flags = int()
				tex.blend = int()
				tex.pos = float_array(2)
				tex.scale = float_array(2)
				tex.rotation = float()
				table.insert(textures, tex)
			end
			return textures
		end,
		BRUS = function()
			local brushes = {}
			local n_texs = int()
			assert(n_texs <= 8)
			while content() do
				local brush = {}
				brush.name = string()
				brush.color = color()
				brush.shininess = float()
				brush.blend = int()
				brush.fx = int()
				brush.texture_id = {}
				for index = 1, n_texs do
					brush.texture_id[index] = optional_id()
				end
				table.insert(brushes, brush)
			end
			return brushes
		end,
		VRTS = function()
			local vertices = {}
			vertices.flags = int()
			vertices.tex_coord_sets = int()
			vertices.tex_coord_set_size = int()
			assert(vertices.tex_coord_sets <= 8 and vertices.tex_coord_set_size <= 4)
			local has_normal = (vertices.flags % 2 == 1) or nil
			local has_color = (math.floor(vertices.flags / 2) % 2 == 1) or nil
			while content() do
				local vertex = {}
				vertex.pos = vector3()
				vertex.normal = has_normal and vector3()
				vertex.color = has_color and color()
				vertex.tex_coords = {}
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
			local tris = {}
			tris.brush_id = id()
			tris.vertex_ids = {}
			while content() do
				local i = id()
				local j = id()
				local k = id()
				table.insert(tris.vertex_ids, {i, j, k})
			end
			return tris
		end,
		MESH = function()
			local mesh = {}
			mesh.brush_id = optional_id()
			mesh.vertices = chunk{VRTS = true}
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
				local frame = {}
				frame.frame = int()
				if position then
					frame.position = vector3()
				end
				if scale then
					frame.scale = vector3()
				end
				if rotation then
					frame.rotation = quaternion()
				end
				table.insert(bone, frame)
			end
			return bone
		end,
		ANIM = function()
			local ret = {}
			ret.flags = int() -- flags are unused
			ret.frames = int()
			ret.fps = float()
			return ret
		end,
		NODE = function()
			local node = {}
			node.name = string()
			node.position = vector3()
			node.scale = vector3()
			node.keys = {}
			node.rotation = quaternion()
			node.children = {}
			local node_type
			-- See https://github.com/blitz-research/blitz3d/blob/master/blitz3d/loader_b3d.cpp#L263
			-- Order is not validated; double occurrences of mutually exclusive node def are
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
			-- Ensure frames are sorted ascendingly
			table.sort(node.keys, function(a, b)
				assert(a.frame ~= b.frame, "duplicate frame")
				return a.frame < b.frame
			end)
			return node
		end,
		BB3D = function()
			local version = int()
			local self = {
				version = {
					major = math.floor(version / 100),
					minor = version % 100,
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

-- Writer

local function write_rope(self)
	local rope = {}

	local written_len = 0
	local function write(str)
		written_len = written_len + #str
		table.insert(rope, str)
	end

	local function byte(val)
		write(string_char(val))
	end

	local function int(val)
		write_int(byte, val, 4)
	end

	local function id(val)
		int(val - 1)
	end

	local function optional_id(val)
		int(val and (val - 1) or -1)
	end

	local function string(val)
		write(val)
		write"\0"
	end

	local function float(val)
		write_single(byte, fround(val))
	end

	local function float_array(arr, len)
		assert(#arr == len)
		for i = 1, len do
			float(arr[i])
		end
	end

	local function color(val)
		float(val.r)
		float(val.g)
		float(val.b)
		float(val.a)
	end

	local function vector3(val)
		float_array(val, 3)
	end

	local function quaternion(quat)
		float(quat[4])
		float(quat[1])
		float(quat[2])
		float(quat[3])
	end

	local function chunk(name, write_func)
		write(name)

		-- Insert placeholder for the 4-bit len
		table.insert(rope, false)
		written_len = written_len + 4
		local len_idx = #rope -- save index of placeholder

		local prev_written_len = written_len
		write_func()

		-- Write the length of this chunk
		local chunk_len = written_len - prev_written_len
		local len_binary = {}
		write_int(function(byte)
			table.insert(len_binary, string_char(byte))
		end, chunk_len, 4)
		rope[len_idx] = table.concat(len_binary)
	end

	local function NODE(node)
		chunk("NODE", function()
			string(node.name)
			vector3(node.position)
			vector3(node.scale)
			quaternion(node.rotation)
			local mesh = node.mesh
			if mesh then
				chunk("MESH", function()
					optional_id(mesh.brush_id)
					local vertices = mesh.vertices
					chunk("VRTS", function()
						int(vertices.flags)
						int(vertices.tex_coord_sets)
						int(vertices.tex_coord_set_size)
						for _, vertex in ipairs(vertices) do
							if vertex.pos then vector3(vertex.pos) end
							if vertex.normal then vector3(vertex.normal) end
							if vertex.color then color(vertex.color) end
							for tex_coord_set = 1, vertices.tex_coord_sets do
								local tex_coords = vertex.tex_coords[tex_coord_set]
								for tex_coord = 1, vertices.tex_coord_set_size do
									float(tex_coords[tex_coord])
								end
							end
						end
					end)
					for _, triangle_set in ipairs(mesh.triangle_sets) do
						chunk("TRIS", function()
							id(triangle_set.brush_id)
							for _, tri in ipairs(triangle_set.vertex_ids) do
								id(tri[1])
								id(tri[2])
								id(tri[3])
							end
						end)
					end
				end)
			end
			if node.bone then
				chunk("BONE", function()
					for vertex_id, weight in pairs(node.bone) do
						id(vertex_id)
						float(weight)
					end
				end)
			end
			if node.keys then
				local keys_by_flags = {}
				for _, key in ipairs(node.keys) do
					local flags = 0
					flags = flags
						+ (key.position and 1 or 0)
						+ (key.scale and 2 or 0)
						+ (key.rotation and 4 or 0)
					keys_by_flags[flags] = keys_by_flags[flags] or {}
					table.insert(keys_by_flags[flags], key)
				end
				for flags, keys in pairs(keys_by_flags) do
					chunk("KEYS", function()
						int(flags)
						for _, frame in ipairs(keys) do
							int(frame.frame)
							if frame.position then vector3(frame.position) end
							if frame.scale then vector3(frame.scale) end
							if frame.rotation then quaternion(frame.rotation) end
						end
					end)
				end
			end
			local anim = node.animation
			if anim then
				chunk("ANIM", function()
					int(anim.flags)
					int(anim.frames)
					float(anim.fps)
				end)
			end
			for _, child in ipairs(node.children) do
				NODE(child)
			end
		end)
	end

	chunk("BB3D", function()
		int(self.version.major * 100 + self.version.minor)
		if self.textures[1] then
			chunk("TEXS", function()
				for _, tex in ipairs(self.textures) do
					string(tex.file)
					int(tex.flags)
					int(tex.blend)
					float_array(tex.pos, 2)
					float_array(tex.scale, 2)
					float(tex.rotation)
				end
			end)
		end
		if self.brushes[1] then
			local max_n_texs = 0
			for _, brush in ipairs(self.brushes) do
				for n in pairs(brush.texture_id) do
					if n > max_n_texs then
						max_n_texs = n
					end
				end
			end
			chunk("BRUS", function()
				int(max_n_texs)
				for _, brush in ipairs(self.brushes) do
					string(brush.name)
					color(brush.color)
					float(brush.shininess)
					int(brush.blend)
					int(brush.fx)
					for index = 1, max_n_texs do
						optional_id(brush.texture_id[index])
					end
				end
			end)
		end
		if self.node then
			NODE(self.node)
		end
	end)
	return rope
end

function write_string(self)
	return table.concat(write_rope(self))
end

function write(self, stream)
	for _, str in ipairs(write_rope(self)) do
		stream:write(str)
	end
end

local binary_search_frame = modlib.table.binary_search_comparator(function(a, b)
	return modlib.table.default_comparator(a, b.frame)
end)

--> list of { bone_name = string, parent_bone_name = string, position = vector, rotation = quaternion, scale = vector }
function get_animated_bone_properties(self, keyframe, interpolate)
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
			rotation = (a.rotation and b.rotation and modlib.quaternion.slerp(a.rotation, b.rotation, ratio)) or a.rotation or b.rotation,
			scale = (a.scale and b.scale and modlib.vector.interpolate(a.scale, b.scale, ratio)) or a.scale or b.scale,
		}
	end
	local bone_properties = {}
	local function get_props(node, parent_bone_name)
		local properties = {parent_bone_name = parent_bone_name}

		if keyframe > 0 and node.keys and next(node.keys) ~= nil then
			modlib.table.add_all(properties, get_frame_values(node.keys))
		end

		if not properties.position then -- animation not present, fall back to node position
			properties.position = modlib.table.copy(node.position)
		end

		if properties.rotation then -- animation is relative to node rotation
			properties.rotation = modlib.quaternion.compose(node.rotation, properties.rotation)
		else
			properties.rotation = modlib.table.copy(node.rotation)
		end

		if not properties.scale then -- animation not present, fall back to node scale
			properties.scale = modlib.table.copy(node.scale)
		end

		if node.bone then
			properties.bone_name = node.name
			table.insert(bone_properties, properties)
		end
		for _, child in pairs(node.children or {}) do
			get_props(child, properties.bone_name)
		end
	end
	get_props(self.node)
	return bone_properties
end

-- Export environment
return _ENV
