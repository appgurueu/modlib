minetest.mkdir(minetest.get_worldpath().."/data")
function create_mod_storage(modname)
    minetest.mkdir(minetest.get_worldpath().."/data/"..modname)
	
function get_path(modname, filename)
    return minetest.get_worldpath().."/data/"..modname.."/"..filename
	
function load(modname, filename)
    return minetest.deserialize(modlib.file.read(get_path(modname, filename)..".lua"))
	
function save(modname, filename, stuff)
    return modlib.file.write(get_path(modname, filename)..".lua", minetest.serialize(stuff))
	
function load_json(modname, filename)
    return minetest.parse_json(modlib.file.read(get_path(modname, filename)..".json") or "null")
	
function save_json(modname, filename, stuff)
    return modlib.file.write(get_path(modname, filename)..".json", minetest.write_json(stuff))
	