# Pico-8 Port Workbench

This directory contains the early scaffold for running Zork I inside a Pico-8 cartridge. The current cart focuses on text rendering and verb handling rather than full story content.

## Files
- `main.lua` – Pico-8 cart code that draws a console-style UI, reads keyboard input, and runs a minimal command parser.
- `game_data.lua` – Trimmmed-down room and object data to exercise the engine while we shape the full data export pipeline.

## Running inside Pico-8
1. Copy the contents of this directory into a `.p8` cart or `p8` folder cartridge.
2. Start Pico-8 with devkit keyboard enabled (desktop builds): `poke(0x5f2d, 1)` is executed during `_init`.
3. Type commands such as `look`, `n`, `take leaflet`, `open window`, `enter`/`out`, or `inventory`. The cart echoes your input and updates the world state in-memory.

## Picotron packing
Picotron makes iteration easier thanks to its terminal and keyboard support. To create a Picotron-ready cartridge:

1. Ensure you have `lua` available on your host or inside Picotron.
2. Run `lua pico8/tools/pack_for_picotron.lua` from the repo root.
3. Open the generated `pico8/build/zork1.p64` inside Picotron with `load("pico8/build/zork1.p64")`, then type `run`.

The packer inlines `game_data.lua` into `main.lua` and writes the result into a minimal Picotron `.p64` text cart so you can test keyboard and terminal flows.

## Picotron/Pico-8 Z-machine interpreter
To run the compiled Zork I story file directly under Picotron or a desktop Lua runtime, a small Z-machine interpreter now lives in `pico8/tools/zmachine.lua`.

### Desktop Lua
1. Ensure you have a Lua 5.3+ interpreter on your PATH.
2. From the repo root, run `lua pico8/tools/run_zmachine.lua` to execute `COMPILED/zork1.z3`.
3. Optionally pass a custom story path and/or a step ceiling: `lua pico8/tools/run_zmachine.lua COMPILED/zork1.z3 10000`.

### Picotron terminal
1. Copy `pico8/tools/zmachine.lua` and `COMPILED/zork1.z3` into your Picotron filesystem.
2. From the Picotron terminal, run `load('zmachine.lua')` followed by `vm = require('zmachine').load('zork1.z3')`.
3. Bind `vm.input_provider` to return user input (e.g., `function vm.input_provider() return read() end`) and step the VM inside a loop to render output in the terminal or a custom UI.

This interpreter focuses on Version 3 story files and prioritizes the opcode set hit during startup and early gameplay so you can iterate on the asset pipeline before shipping into the constrained Pico-8 cart.

## Next steps
- Flesh out the room/object data exporter so the full ZIL world can be loaded into Lua tables.
- Add save/load slots that serialize the player state into a cartdata blob.
- Implement token compression to keep the Lua source within Pico-8's 8192 token limit once the full script is imported.
- Expand the indoor space with kitchen/living room furniture interactions and the trap door loop.
