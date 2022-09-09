# ![Logo](logo.svg) Modding Library (`modlib`)

Multipurpose Minetest Modding Library

## About

No dependencies. Licensed under the MIT License. Written by Lars Mueller aka LMD or appguru(eu). Notable contributions by [luk3yx](https://github.com/luk3yx) in the form of suggestions, bug reports and fixes. Another [bugfix](https://github.com/appgurueu/modlib/pull/7) by [NobWow](https://github.com/NobWow/).

### Principles

* Game-agnostic: Modlib aims to provide nothing game-specific;
* Minimal invasiveness: Modlib should not disrupt other mods;
  even at the expense of syntactic sugar, changes to the global
  environment - apart from the addition of the modlib scope - are forbidden
* Architecture: Modlib is organized hierarchically
* Performance: Modlib tries to not compromise performance for convenience; modlib loads lazily

## Tests

The tests are located in a different repo, [`modlib_test`](https://github.com/appgurueu/modlib_test), as they are quite heavy due to testing the PNG reader using PngSuite. Reading the tests for examples of API usage is recommended.

## API

(Incomplete) documentation resides in the `doc` folder; you'll have to dive into the code for everything else.

The mod namespace is `modlib`, containing all modules which in turn contain variables & functions.

Modules are lazily loaded by indexing the `modlib` table. Do `_ = modlib.<module>` to avoid file load spikes at run time.

Localizing modules (`local <module> = modlib.<module>`) is recommended.
