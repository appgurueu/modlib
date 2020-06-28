# Modding Library (`modlib`)

Multipurpose Minetest Modding Library

## About

No dependencies. Licensed under the MIT License. Written by Lars Mueller aka LMD or appguru(eu).

## API

Mostly self-documenting code. Mod namespace is `modlib` or `_ml`, containing all variables & functions.

## Configuration

1. Configuration is loaded from `<worldpath>/config/<modname>.<extension>`, the following extensions are supported and loaded (in the given order), with loaded configurations overriding properties of previous ones:
   1. [`json`](https://json.org)
   2. [`lua`](https://lua.org)
   3. [`luon`](https://github.com/appgurueu/luon), Lua but without the `return`
   4. [`conf`](https://github.com/minetest/minetest/blob/master/doc/lua_api.txt)
2. Settings are loaded from `minetest.conf` and override configuration values