# luau-roblox

A luau library to manipulate Roblox instances from place/model files, powered by Zune.

## Usage

Setup the library, ideally with `.luaurc`.

### Virtual DataModel

Using the Virtual DataModel is easier, but it has overhead. Equivalent to Lune's `roblox` module.

```luau
local roblox = require("@roblox");

local placeContents = ...; -- read the place file
local game = roblox.deserializePlace(placeContents);

-- do something with the game

local content = roblox.serializePlace(game);
```

### DOM

Using the DOM over the Virtual DataModel is ideally faster, with zero overhead.
The downside is that you have to manually handle the instances, parents, and references.

```luau
local roblox = require("@roblox");

local dom = roblox.dom;

local placeContents = ...; -- read the place file
local doc = dom.deserialize(placeContents);

-- do something with the doc

local content = dom.serialize(doc, "BINARY");
```

## Information

`DOM` Supported:
- `Binary` (.rbxl, .rbxm)
    - [x] deserialization
    - [x] serialization
- `XML` (.rbxlx, .rbxmx)
    - [ ] deserialization
    - [ ] serialization

Warnings:
- 64-bit integer data could not be represented fully due to luau's number limitations, the max precision is 2^53.