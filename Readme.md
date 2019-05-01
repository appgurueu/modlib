# modlib
Lightweight Minetest Modding Library

## API
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
