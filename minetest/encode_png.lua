if minetest.encode_png then
	(...).encode_png = minetest.encode_png
	return
end

local assert, char, ipairs, insert, concat, floor = assert, string.char, ipairs, table.insert, table.concat, math.floor

-- TODO move to modlib.bit eventually
local bit_xor = bit.xor or function(a, b)
	local res = 0
	local bit = 1
	for _ = 1, 32 do
		if a % 2 ~= b % 2 then
			res = res + bit
		end
		a = floor(a / 2)
		b = floor(b / 2)
		bit = bit * 2
	end
	return res
end

local crc_table = {}
for i = 0, 255 do
	local c = i
	for _ = 0, 7 do
		if c % 2 > 0 then
			c = bit_xor(0xEDB88320, floor(c / 2))
		else
			c = floor(c / 2)
		end
	end
	crc_table[i] = c
end

local function encode_png(width, height, data, compression, raw_write)
	local write = raw_write
	local function byte(value)
		write(char(value))
	end
	local function _uint(value)
		local div = 0x1000000
		for _ = 1, 4 do
			byte(floor(value / div) % 0x100)
			div = div / 0x100
		end
	end
	local function uint(value)
		assert(value < 2^31)
		_uint(value)
	end
	local chunk_content
	local function chunk_write(text)
		insert(chunk_content, text)
	end
	local function chunk(type)
		chunk_content = {}
		write = chunk_write
		write(type)
	end
	local function end_chunk()
		write = raw_write
		local chunk_len = 0
		for i = 2, #chunk_content do
			chunk_len = chunk_len + #chunk_content[i]
		end
		uint(chunk_len)
		write(concat(chunk_content))
		local chunk_crc = 0xFFFFFFFF
		for _, text in ipairs(chunk_content) do
			for i = 1, #text do
				chunk_crc = bit_xor(crc_table[bit_xor(chunk_crc % 0x100, text:byte(i))], floor(chunk_crc / 0x100))
			end
		end
		_uint(bit_xor(chunk_crc, 0xFFFFFFFF))
	end
	-- Signature
	write"\137\80\78\71\13\10\26\10"
	chunk"IHDR"
	uint(width)
	uint(height)
	-- Always use bit depth 8
	byte(8)
	-- Always use color type "truecolor with alpha"
	byte(6)
	-- Compression method: deflate
	byte(0)
	-- Filter method: PNG filters
	byte(0)
	-- No interlace
	byte(0)
	end_chunk()
	chunk"IDAT"
	local data_rope = {}
	for y = 0, height - 1 do
		local base_index = y * width
		insert(data_rope, "\0")
		for x = 1, width do
			local colorspec = modlib.minetest.colorspec.from_any(data[base_index + x])
			insert(data_rope, char(colorspec.r, colorspec.g, colorspec.b, colorspec.a))
		end
	end
	write(minetest.compress(type(data) == "string" and data or concat(data_rope), "deflate", compression))
	end_chunk()
	chunk"IEND"
	end_chunk()
end

(...).encode_png = function(width, height, data, compression)
	local rope = {}
	encode_png(width, height, data, compression or 9, function(text)
		insert(rope, text)
	end)
	return concat(rope)
end