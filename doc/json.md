# JSON

Advantages over `core.write_json`/`core.parse_json`:

* Twice as fast in most benchmarks (for pre-5.6 at least)
* Uses streams instead of strings
* Customizable
* Useful error messages
* Pure Lua
