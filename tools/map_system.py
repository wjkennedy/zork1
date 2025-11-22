#!/usr/bin/env python3
"""Map extraction and rendering helpers for the Zork I sources.

This utility parses the ZIL room definitions to produce a normalized
JSON description, and can render that JSON into multiple textual
formats (Graphviz DOT, Mermaid, or a Markdown adjacency list).
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

DIRECTIONS = [
    "NORTH",
    "SOUTH",
    "EAST",
    "WEST",
    "NE",
    "NW",
    "SE",
    "SW",
    "UP",
    "DOWN",
    "IN",
    "OUT",
]


class MapParseError(Exception):
    """Raised when the ZIL source cannot be parsed."""


def read_zil_rooms(zil_path: Path) -> Dict[str, List[Dict]]:
    """Parse the ZIL source and return a map description.

    The resulting structure matches the JSON schema written by this script:
    {
      "rooms": [
        {
          "id": "WEST-OF-HOUSE",
          "name": "West of House",
          "description": "You are ...",
          "exits": {"north": "NORTH-OF-HOUSE", ...}
        }
      ]
    }
    """

    rooms: List[Dict] = []
    block: List[str] = []
    in_room = False

    for raw_line in zil_path.read_text().splitlines():
        line = raw_line.strip()
        if line.startswith("<ROOM "):
            if in_room:
                raise MapParseError(f"Nested room block encountered near: {line}")
            in_room = True
            block = [line]
            continue

        if in_room:
            block.append(line)
            if ">" in line:
                rooms.append(parse_room_block(block))
                in_room = False

    if in_room:
        raise MapParseError("Reached end of file while still inside a room block.")

    rooms.sort(key=lambda r: (r.get("name") or r["id"]).lower())
    return {"rooms": rooms}


def parse_room_block(block: Iterable[str]) -> Dict:
    """Convert a single <ROOM ...> block into a dictionary."""

    lines = list(block)
    if not lines:
        raise MapParseError("Empty room block encountered.")

    header = lines[0]
    header_match = re.match(r"<ROOM\s+([A-Z0-9-]+)", header)
    if not header_match:
        raise MapParseError(f"Could not parse room header: {header}")

    room_id = header_match.group(1)
    text_block = "\n".join(lines)

    desc_match = re.search(r"\(DESC\s+\"([^\"]+)\"\)", text_block)
    name = desc_match.group(1) if desc_match else room_id

    ldesc_match = re.search(r"\(LDESC\s+\"([\s\S]*?)\"\)", text_block)
    description = ldesc_match.group(1).replace("\n", " ") if ldesc_match else name

    exits: Dict[str, str] = {}
    for direction, target in find_exits(text_block):
        exits[direction.lower()] = target

    return {
        "id": room_id,
        "name": name,
        "description": description,
        "exits": exits,
    }


def find_exits(text_block: str) -> Iterable[Tuple[str, str]]:
    """Yield (direction, destination) tuples from a room block."""

    for direction in DIRECTIONS:
        pattern = rf"\({direction}\s+TO\s+([A-Z0-9-]+)"
        for match in re.finditer(pattern, text_block):
            yield direction, match.group(1)


def render_graphviz(map_data: Dict) -> str:
    """Render the map to Graphviz DOT syntax."""

    lines = ["digraph zork_map {", "  rankdir=LR;", "  node [shape=box style=rounded fontsize=10];"]

    for room in map_data.get("rooms", []):
        title = escape_label(room.get("name") or room.get("id"))
        node_label = f"{title}\\n({room['id']})"
        lines.append(f'  "{room['id']}" [label="{node_label}"];')

    for room in map_data.get("rooms", []):
        for direction, target in room.get("exits", {}).items():
            lines.append(f'  "{room['id']}" -> "{target}" [label="{direction}"];')

    lines.append("}")
    return "\n".join(lines)


def render_mermaid(map_data: Dict) -> str:
    """Render the map to a Mermaid flow chart."""

    lines = ["graph LR"]
    for room in map_data.get("rooms", []):
        name = escape_label(room.get("name") or room.get("id"))
        lines.append(f"  {room['id']}[{name}]")

    for room in map_data.get("rooms", []):
        for direction, target in room.get("exits", {}).items():
            lines.append(f"  {room['id']} -- {direction} --> {target}")

    return "\n".join(lines)


def render_adjacency_table(map_data: Dict) -> str:
    """Render the map as a Markdown adjacency table."""

    lines = ["| Room | Exits |", "| --- | --- |"]
    for room in map_data.get("rooms", []):
        label = room.get("name") or room.get("id")
        exits = room.get("exits", {})
        exit_text = ", ".join(
            f"{direction} → {target}" for direction, target in sorted(exits.items())
        )
        lines.append(f"| {label} ({room['id']}) | {exit_text} |")
    return "\n".join(lines)


def escape_label(label: str) -> str:
    """Escape characters that would break diagram renderers."""

    return label.replace("\\", "\\\\").replace("\"", "\\\"")


def write_output(path: Path, content: str) -> None:
    if path == Path("-"):
        sys.stdout.write(content)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build and render Zork I maps from ZIL.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    export_parser = subparsers.add_parser("export", help="Generate JSON from the ZIL source")
    export_parser.add_argument("--zil", default="1dungeon.zil", type=Path, help="Path to the ZIL world file")
    export_parser.add_argument("--json", default=Path("maps/zork1_map.json"), type=Path, help="Where to write the map JSON")

    render_parser = subparsers.add_parser("render", help="Render a JSON map into another format")
    render_parser.add_argument("--json", default=Path("maps/zork1_map.json"), type=Path, help="JSON map to read")
    render_parser.add_argument("--format", choices=["dot", "mermaid", "adjacency"], default="dot")
    render_parser.add_argument("--out", default=Path("-"), type=Path, help="Where to write the rendered output (use '-' for stdout)")

    args = parser.parse_args()

    if args.command == "export":
        map_data = read_zil_rooms(args.zil)
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(map_data, indent=2))
        sys.stdout.write(
            f"Wrote {args.json} with {len(map_data['rooms'])} rooms and {sum(len(r['exits']) for r in map_data['rooms'])} exits.\n"
        )
    elif args.command == "render":
        map_data = json.loads(args.json.read_text())
        if args.format == "dot":
            content = render_graphviz(map_data)
        elif args.format == "mermaid":
            content = render_mermaid(map_data)
        else:
            content = render_adjacency_table(map_data)
        write_output(args.out, content)


if __name__ == "__main__":
    main()
