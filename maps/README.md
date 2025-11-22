# Zork I map exports

This directory contains a normalized JSON representation of every room in Zork I, plus helper commands for rendering that map in different formats. The JSON file acts as an intermediate description layer so that any renderer (Graphviz, Mermaid, Pico-8, etc.) can reuse the same source data.

## Files
- `zork1_map.json` – Generated from `1dungeon.zil` via `tools/map_system.py export`. Each room entry lists a stable id, display name, description, and its exits keyed by direction.

## Usage
1. Rebuild the JSON export from the ZIL source (optional if you just want to read the committed file):
   ```bash
   python tools/map_system.py export --zil 1dungeon.zil --json maps/zork1_map.json
   ```
2. Render the JSON into another format:
   ```bash
   # Graphviz DOT
   python tools/map_system.py render --json maps/zork1_map.json --format dot --out maps/zork1_map.dot

   # Mermaid (suitable for Markdown viewers)
   python tools/map_system.py render --json maps/zork1_map.json --format mermaid --out maps/zork1_map.mmd

   # Markdown adjacency table
   python tools/map_system.py render --json maps/zork1_map.json --format adjacency --out maps/zork1_map.md
   ```

You can also supply your own output path or pipe to stdout by setting `--out -`. The JSON schema is intentionally simple to make it easy to feed into additional renderers.
