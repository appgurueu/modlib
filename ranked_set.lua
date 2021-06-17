-- Localize globals
local assert, modlib, pairs, setmetatable, table = assert, modlib, pairs, setmetatable, table

-- Set environment
local _ENV = {}
setfenv(1, _ENV)

local metatable = {__index = _ENV}

comparator = modlib.table.default_comparator

--+ Uses a weight-balanced binary tree
function new(comparator)
	return setmetatable({comparator = comparator, root = {total = 0}}, metatable)
end

function len(self)
	return self.root.total
end
metatable.__len = len

function is_empty(self)
	return len(self) == 0
end

local function insert_all(tree, _table)
	if tree.left then
		insert_all(tree.left, _table)
	end
	table.insert(_table, tree.key)
	if tree.right then
		insert_all(tree.right, _table)
	end
end

function to_table(self)
	local table = {}
	if not is_empty(self) then
		insert_all(self.root, table)
	end
	return table
end

--> iterator: function() -> `rank, key` with ascending rank
function ipairs(self, min, max)
	if is_empty(self) then
		return function() end
	end
	min = min or 1
	local tree = self.root
	local current_rank = (tree.left and tree.left.total or 0) + 1
	repeat
		if min == current_rank then
			break
		end
		local left, right = tree.left, tree.right
		if min < current_rank then
			current_rank = current_rank - (left and left.right and left.right.total or 0) - 1
			tree = left
		else
			current_rank = current_rank + (right and right.left and right.left.total or 0) + 1
			tree = right
		end
	until not tree
	max = max or len(self)
	local to_visit = {tree}
	tree = nil
	local rank = min - 1
	local function next()
		if not tree then
			local len = #to_visit
			if len == 0 then return end
			tree = to_visit[len]
			to_visit[len] = nil
		else
			while tree.left do
				table.insert(to_visit, tree)
				tree = tree.left
			end
		end
		local key = tree.key
		tree = tree.right
		return key
	end
	return function()
		if rank >= max then
			return
		end
		local key = next()
		if key == nil then
			return
		end
		rank = rank + 1
		return rank, key
	end
end

local function _right_rotation(parent, right, left)
	local new_parent = parent[left]
	parent[left] = new_parent[right]
	new_parent[right] = parent
	parent.total = (parent[left] and parent[left].total or 0) + (parent[right] and parent[right].total or 0) + 1
	assert(parent.total > 0 or (parent.left == nil and parent.right == nil))
	new_parent.total = (new_parent[left] and new_parent[left].total or 0) + parent.total + 1
	return new_parent
end

local function right_rotation(parent)
	return _right_rotation(parent, "right", "left")
end

local function left_rotation(parent)
	return _right_rotation(parent, "left", "right")
end

local function _rebalance(parent)
	local left_count, right_count = (parent.left and parent.left.total or 0), (parent.right and parent.right.total or 0)
	if right_count > 1 and left_count * 2 < right_count then
		return left_rotation(parent)
	end
	if left_count > 1 and right_count * 2 < left_count then
		return right_rotation(parent)
	end
	return parent
end

-- Rebalances a parent chain
local function rebalance(self, len, parents, sides)
	if len <= 1 then
		return
	end
	for i = len, 2, -1 do
		parents[i] = _rebalance(parents[i])
		parents[i - 1][sides[i - 1]] = parents[i]
	end
	self.root = parents[1]
end

local function _insert(self, key, replace)
	assert(key ~= nil)
	if is_empty(self) then
		self.root = {key = key, total = 1}
		return
	end
	local comparator = self.comparator
	local parents, sides = {}, {}
	local tree = self.root
	repeat
		local tree_key = tree.key
		local compared = comparator(key, tree_key)
		if compared == 0 then
			if replace then
				tree.key = key
				return tree_key
			end
			return
		end
		table.insert(parents, tree)
		local side = compared < 0 and "left" or "right"
		table.insert(sides, side)
		tree = tree[side]
	until not tree
	local len = #parents
	parents[len][sides[len]] = {key = key, total = 1}
	for _, parent in pairs(parents) do
		parent.total = parent.total + 1
	end
	rebalance(self, len, parents, sides)
end

function insert(self, key)
	return _insert(self, key)
end

function insert_or_replace(self, key)
	return _insert(self, key, true)
end

local function _delete(self, key, is_rank)
	assert(key ~= nil)
	if is_empty(self) then
		return
	end
	local comparator = self.comparator
	local parents, sides = {}, {}
	local tree = self.root
	local rank = (tree.left and tree.left.total or 0) + 1
	repeat
		local tree_key = tree.key
		local compared
		if is_rank then
			if key == rank then
				compared = 0
			elseif key < rank then
				rank = rank - (tree.left and tree.left.right and tree.left.right.total or 0) - 1
				compared = -1
			else
				rank = rank + (tree.right and tree.right.left and tree.right.left.total or 0) + 1
				compared = 1
			end
		else
			compared = comparator(key, tree_key)
		end
		if compared == 0 then
			local len = #parents
			local left, right = tree.left, tree.right
			if left then
				tree.total = tree.total - 1
				if right then
					-- Obtain successor
					local side = left.total > right.total and "left" or "right"
					local other_side = side == "left" and "right" or "left"
					local sidemost = tree[side]
					while sidemost[other_side] do
						sidemost.total = sidemost.total - 1
						table.insert(parents, sidemost)
						table.insert(sides, other_side)
						sidemost = sidemost[other_side]
					end
					-- Replace deleted key
					tree.key = sidemost.key
					-- Replace the successor by it's single child
					parents[len][sides[len]] = sidemost[side]
				else
					if len == 0 then
						self.root = left or {total = 0}
					else
						parents[len][sides[len]] = left
					end
				end
			elseif right then
				if len == 0 then
					self.root = right or {total = 0}
				else
					tree.total = tree.total - 1
					parents[len][sides[len]] = right
				end
			else
				if len == 0 then
					self.root = {total = 0}
				else
					parents[len][sides[len]] = nil
				end
			end
			for _, parent in pairs(parents) do
				parent.total = parent.total - 1
			end
			rebalance(self, len, parents, sides)
			if is_rank then
				return tree_key
			end
			return rank, tree_key
		end
		table.insert(parents, tree)
		local side
		if compared < 0 then
			side = "left"
		else
			side = "right"
		end
		table.insert(sides, side)
		tree = tree[side]
	until not tree
end

function delete(self, key)
	return _delete(self, key)
end

delete_by_key = delete

function delete_by_rank(self, rank)
	return _delete(self, rank, true)
end

--> `rank, key` if the key was found
--> `rank` the key would have if inserted
function get(self, key)
	if is_empty(self) then return end
	local comparator = self.comparator
	local tree = self.root
	local rank = (tree.left and tree.left.total or 0) + 1
	while tree do
		local compared = comparator(key, tree.key)
		if compared == 0 then
			return rank, tree.key
		end
		if compared < 0 then
			rank = rank - (tree.left and tree.left.right and tree.left.right.total or 0) - 1
			tree = tree.left
		else
			rank = rank + (tree.right and tree.right.left and tree.right.left.total or 0) + 1
			tree = tree.right
		end
	end
	return rank
end

get_by_key = get

--> key
function get_by_rank(self, rank)
	local tree = self.root
	local current_rank = (tree.left and tree.left.total or 0) + 1
	repeat
		if rank == current_rank then
			return tree.key
		end
		local left, right = tree.left, tree.right
		if rank < current_rank then
			current_rank = current_rank - (left and left.right and left.right.total or 0) - 1
			tree = left
		else
			current_rank = current_rank + (right and right.left and right.left.total or 0) + 1
			tree = right
		end
	until not tree
end

-- Export environment
return _ENV