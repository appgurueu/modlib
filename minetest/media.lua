local minetest, modlib, pairs, ipairs
	= minetest, modlib, pairs, ipairs

--! experimental

-- TODO support for server texture packs (and possibly client TPs in singleplayer?)
local media_foldernames = {"textures", "sounds", "media", "models", "locale"}
local media_extensions = modlib.table.set{
	-- Textures
	"png", "jpg", "bmp", "tga", "pcx", "ppm", "psd", "wal", "rgb";
	-- Sounds
	"ogg";
	-- Models
	"x", "b3d", "md2", "obj";
	-- Translations
	"tr";
}

local function collect_media(modname)
	local media = {}
	local function traverse(folder)
		local filenames = minetest.get_dir_list(folder, false)
		for _, filename in pairs(filenames) do
			local _, ext = modlib.file.get_extension(filename)
			if media_extensions[ext] then
				media[filename] = folder .. "/" .. filename
			end
		end
		local folderpaths = minetest.get_dir_list(folder, true)
		for _, folderpath in pairs(folderpaths) do
			local first = folderpath:sub(1, 1)
			if first ~= "_" and first ~= "." then
				traverse(modlib.mod.get_resource(modname, folderpath))
			end
		end
	end
	-- Can't use foreach_value because order matters
	-- TODO foreach_ipairs?
	for _, foldername in ipairs(media_foldernames) do
		traverse(modlib.mod.get_resource(modname, foldername))
	end
	return media
end

local paths = {}
for _, mod in ipairs(modlib.minetest.get_mod_load_order()) do
	local mod_media = collect_media(mod.name)
	for medianame, path in pairs(mod_media) do
		paths[medianame] = path
	end
end

return {paths = paths}