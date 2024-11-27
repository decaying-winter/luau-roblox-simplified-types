# luau-roblox

A luau library to manipulate Roblox instances from place/model files, powered by Zune.

Supported:
- Binary (.rbxl, .rbxm)
    - [x] deserialization
    - [ ] serialization
- XML (.rbxlx, .rbxmx)
    - [ ] deserialization
    - [ ] serialization

Warnings:
- 64-bit integer data could not be represented fully due to luau's number limitations, the max precision is 2^53.