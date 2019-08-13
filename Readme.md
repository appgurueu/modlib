# modlib
Lightweight Minetest Modding Library

## About
No dependencies. Compatibility is checked automatically.  
Licensed under the MIT License. Written by Lars Mueller aka LMD or appguru(eu).

## API
### Some more stuff
The things listed below are just a few, and as the library grows, I am not mentioning them all here, but I hope the function names are self-explaining. If not, feel free to contact me or create an issue / PR on GitHub.
### `table_ext`
Table Helpers. Self-explaining - merge tables, count tables, add items to tables, etc.
### `number_ext`
Number Helpers. Also self-explaining. Currently only rounding.
### `log`
Several logchannels which can be written to. Look at sourcecode.
### `conf`
Configuration files as .json - world specific. Constraint checks can be done.
Use `load_or_create(confname, replacement_file, constraints)` to load the conf, if it does not exist create it using replacement file, and then load it, checking the constraints.
##### Constraints
Are a table.
```
{
  type="boolean"/"number"/"string"/"table",
  If type = table : 
  keys = constraints_for_keys,
  values = constraints_for_values
  children = {child_key:constraints_for_value},
  If type = number or string :
  range={start=num, end=num},
  func=function(value) returns error or nil,
  possible_values = {v1, v2}
}
```
