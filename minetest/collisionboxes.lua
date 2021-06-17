-- Localize globals
local assert, ipairs, math, minetest, pairs, table, type, vector = assert, ipairs, math, minetest, pairs, table, type, vector

-- Set environment
local _ENV = ...
setfenv(1, _ENV)

-- Minetest allows shorthand collisionbox = {...} instead of {{...}}
local function get_collisionboxes(box_or_boxes)
	return type(box_or_boxes[1]) == "number" and {box_or_boxes} or box_or_boxes
end

--> list of collisionboxes in Minetest format
function get_node_collisionboxes(pos)
	local node = minetest.get_node(pos)
	local node_def = minetest.registered_nodes[node.name]
	if (not node_def) or node_def.walkable == false then
		return {}
	end
	local boxes = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
	local def_collision_box = node_def.collision_box or (node_def.drawtype == "nodebox" and node_def.node_box)
	if def_collision_box then
		local box_type = def_collision_box.type
		if box_type == "regular" then
			return boxes
		end
		local fixed = def_collision_box.fixed
		boxes = get_collisionboxes(fixed or {})
		local paramtype2 = node_def.paramtype2
		if box_type == "leveled" then
			boxes = table.copy(boxes)
			local level = (paramtype2 == "leveled" and node.param2 or node_def.leveled or 0) / 255 - 0.5
			for _, box in pairs(boxes) do
				box[5] = level
			end
		elseif box_type == "wallmounted" then
			-- TODO complete if only wall_top is given
			local dir = minetest.wallmounted_to_dir((paramtype2 == "colorwallmounted" and node.param2 % 8 or node.param2) or 0)
			local box
			if dir.y > 0 then
				box = def_collision_box.wall_top
			elseif dir.y < 0 then
				box = def_collision_box.wall_bottom
			else
				box = def_collision_box.wall_side
				if dir.z > 0 then
					box = {box[3], box[2], -box[4], box[6], box[5], -box[1]}
				elseif dir.z < 0 then
					box = {-box[6], box[2], box[1], -box[3], box[5], box[4]}
				elseif dir.x > 0 then
					box = {-box[4], box[2], box[3], -box[1], box[5], box[6]}
				else
					box = {box[1], box[2], -box[6], box[4], box[5], -box[3]}
				end
			end
			return {assert(box, "incomplete wallmounted collisionbox definition of " .. node.name)}
		end
		if box_type == "connected" then
			boxes = table.copy(boxes)
			local connect_sides = {
				top = {x = 0, y = 1, z = 0},
				bottom = {x = 0, y = -1, z = 0},
				front = {x = 0, y = 0, z = -1},
				left = {x = -1, y = 0, z = 0},
				back = {x = 0, y = 0, z = 1},
				right = {x = 1, y = 0, z = 0}
			}
			if node_def.connect_sides then
				for side in pairs(connect_sides) do
					if not node_def.connect_sides[side] then
						connect_sides[side] = nil
					end
				end
			end
			local function add_collisionbox(key)
				for _, box in ipairs(get_collisionboxes(def_collision_box[key] or {})) do
					table.insert(boxes, box)
				end
			end
			local matchers = {}
			for _, nodename_or_group in pairs(node_def.connects_to or {}) do
				table.insert(matchers, nodename_matcher(nodename_or_group))
			end
			local function connects_to(nodename)
				for _, matcher in pairs(matchers) do
					if matcher(nodename) then
						return true
					end
				end
			end
			local connected, connected_sides
			for side, direction in pairs(connect_sides) do
				local neighbor = minetest.get_node(vector.add(pos, direction))
				local connects = connects_to(neighbor.name)
				connected = connected or connects
				connected_sides = connected_sides or (side ~= "top" and side ~= "bottom")
				add_collisionbox((connects and "connect_" or "disconnected_") .. side)
			end
			if not connected then
				add_collisionbox("disconnected")
			end
			if not connected_sides then
				add_collisionbox("disconnected_sides")
			end
			return boxes
		end
		if box_type == "fixed" and paramtype2 == "facedir" or paramtype2 == "colorfacedir" then
			local param2 = paramtype2 == "colorfacedir" and node.param2 % 32 or node.param2 or 0
			if param2 ~= 0 then
				boxes = table.copy(boxes)
				local axis = ({5, 6, 3, 4, 1, 2})[math.floor(param2 / 4) + 1]
				local other_axis_1, other_axis_2 = (axis % 3) + 1, ((axis + 1) % 3) + 1
				local rotation = (param2 % 4) / 2 * math.pi
				local flip = axis > 3
				if flip then axis = axis - 3; rotation = -rotation end
				local sin, cos = math.sin(rotation), math.cos(rotation)
				if axis == 2 then
					sin = -sin
				end
				for _, box in pairs(boxes) do
					for off = 0, 3, 3 do
						local axis_1, axis_2 = other_axis_1 + off, other_axis_2 + off
						local value_1, value_2 = box[axis_1], box[axis_2]
						box[axis_1] = value_1 * cos - value_2 * sin
						box[axis_2] = value_1 * sin + value_2 * cos
					end
					if not flip then
						box[axis], box[axis + 3] = -box[axis + 3], -box[axis]
					end
					local function fix(coord)
						if box[coord] > box[coord + 3] then
							box[coord], box[coord + 3] = box[coord + 3], box[coord]
						end
					end
					fix(other_axis_1)
					fix(other_axis_2)
				end
			end
		end
	end
	return boxes
end
