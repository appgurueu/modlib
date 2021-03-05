# Modding Library (`modlib`)

Multipurpose Minetest Modding Library

## About

No dependencies. Licensed under the MIT License. Written by Lars Mueller aka LMD or appguru(eu).

## API

Mostly self-documenting code. Mod namespace is `modlib` or `_ml`, containing all variables & functions.

### Bluon

Binary Lua object notation. **Experimental.** Handling of subnormal numbers (very small floats) may be broken.

#### `new(def)`

```lua
def = {
    aux_is_valid = function(object)
        return is_valid
    end,
    aux_len = function(object)
        return length_in_bytes
    end,
    -- read type byte, stream providing :read(count), map of references -> id
    aux_read = function(type, stream, references)
        ... = stream:read(...)
        return object
    end,
    -- object to be written, stream providing :write(text), list of references
    aux_write = function(object, stream, references)
        stream:write(...)
    end
}
```

#### `:is_valid(object)`

Returns whether the given object can be represented by the instance as boolean.

#### `:len(object)`

Returns the expected length of the object if serialized by the current instance in bytes.

#### `:write(object, stream)`

Writes the object to a stream supporting `:write(text)`. Throws an error if invalid.

#### `:read(stream)`

Reads a single bluon object from a stream supporting `:read(count)`. Throws an error if invalid bluon.

Checking whether the stream has been fully consumed by doing `assert(not stream:read(1))` is left up to the user.

#### Format

* `nil`: nothing (`""`)
* `false`: 0
* `true`: 1
* Numbers:
  * Constants: 0, nan, +inf, -inf
  * Integers: Little endian `U8`, `U16`, `U32`, `U64`, `-U8`, `-U16`, `-U32`, `-U64`
  * Floats: Little endian `F32`, `F64`
* Strings:
  * Constant: `""`
  * Length as unsigned integer: `T8`, `T16`, `T32`, `T64`
* Tables:
  * List and map part count as unsigned integers
  * `L0`, `L8`, `L16`, `L32`, `L64` times `M0`, `M8`, `M16`, `M32`, `M64`
* Reference:
  * Reference ID as unsigned integer: `R8`, `R16`, `R32`, `R64`
* Reserved types:
  * Everything <= 55 => 200 free types

#### Features

* Embeddable: Written in pure Lua
* Storage efficient: No duplication of strings or reference-equal tables
* Flexible: Can serialize circular references and strings containing null

#### Simple example

```lua
local object = ...
-- Write to file
local file = io.open(..., "w")
modlib.bluon:write(object, file)
file:close()
-- Write to text
local rope = modlib.table.rope{}
modlib.bluon:write(object, rope)
text = rope:to_text()
-- Read from text
local inputstream = modlib.text.inputstream"\1"
assert(modlib.bluon:read(object, rope) == true)
```

#### Advanced example

```lua
-- Serializes all userdata to a constant string:
local custom_bluon = bluon.new{
    aux_is_valid = function(object)
        return type(object) == "userdata"
    end,
    aux_len = function(object)
        return 1 + ("userdata"):len())
    end,
    aux_read = function(type, stream, references)
        assert(type == 100, "unsupported type")
        assert(stream:read(("userdata"):len()) == "userdata")
        return userdata()
    end,
    -- object to be written, stream providing :write(text), list of references
    aux_write = function(object, stream, references)
        assert(type(object) == "userdata")
        stream:write"\100userdata"
    end
}
-- Write to text
local rope = modlib.table.rope{}
custom_bluon:write(userdata(), rope)
assert(rope:to_text() == "\100userdata")
```

## Configuration

### Legacy

1. Configuration is loaded from `<worldpath>/config/<modname>.<extension>`, the following extensions are supported and loaded (in the given order), with loaded configurations overriding properties of previous ones:
   1. [`json`](https://json.org)
   2. [`lua`](https://lua.org)
   3. [`luon`](https://github.com/appgurueu/luon), Lua but without the `return`
   4. [`conf`](https://github.com/minetest/minetest/blob/master/doc/lua_api.txt)
2. Settings are loaded from `minetest.conf` and override configuration values

### Locations

0. Default configuration: `<modfolder>/conf.lua`
1. World configuration: `config/<modname>.<format>`
2. Mod configuration: `<modfolder>/conf.<format>`
3. Minetest configuration: `minetest.conf`

### Formats

1. [`lua`](https://lua.org)
  * Lua, with the environment being the configuration object
  * `field = value` works
  * Return new configuration object to replace
2. [`luon`](https://github.com/appgurueu/luon)
  * Single Lua literal
  * Booleans, numbers, strings and tables
3. [`conf`](https://github.com/minetest/minetest/blob/master/doc/lua_api.txt)
  * Minetest-like configuration files
4. [`json`](https://json.org)
  * Not recommended