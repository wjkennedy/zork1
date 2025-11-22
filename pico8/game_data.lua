-- lightweight world slice to exercise the pico-8 text engine
-- this data is intentionally small while we work toward a full port

rooms = {
  west_of_house = {
    name = "West of House",
    description = "You are standing in an open field west of a white house, with a boarded front door.",
    exits = { n = "north_of_house", s = "south_of_house", e = "house_front" }
  },
  house_front = {
    name = "Front Porch",
    description = "You are on the small porch of the white house. The front door is boarded shut.",
    exits = { w = "west_of_house" }
  },
  north_of_house = {
    name = "North of House",
    description = "You are facing the north side of a white house. There is no door here, and all the windows are boarded.",
    exits = { s = "west_of_house", e = "behind_house" }
  },
  behind_house = {
    name = "Behind House",
    description = "You are behind the white house. In one corner of the house there is a small window which is slightly ajar.",
    exits = { w = "north_of_house", e = "forest" },
    objects = { "window" }
  },
  forest = {
    name = "Forest",
    description = "The forest becomes impenetrable to the east.",
    exits = { w = "behind_house" }
  },
  south_of_house = {
    name = "South of House",
    description = "You are facing the south side of a white house. There is no door here, and all the windows are boarded.",
    exits = { n = "west_of_house" }
  },
  kitchen = {
    name = "Kitchen",
    description = "You are in the kitchen of the white house. A table seems to have been used recently for the preparation of food.",
    exits = { e = "living_room" }
  },
  living_room = {
    name = "Living Room",
    description = "You are in the living room. There is a doorway to the east, a wooden door with a small window to the south, and the kitchen is to the west.",
    exits = { w = "kitchen" }
  }
}

objects = {
  mailbox = { name = "mailbox", list_name = "a small mailbox", location = "west_of_house", portable = false, description = "It's just an ordinary small mailbox." },
  leaflet = { name = "leaflet", list_name = "a leaflet", location = "mailbox", portable = true, description = "WELCOME TO ZORK! Adventure awaits inside." },
  window = { name = "window", list_name = "a small window", location = "behind_house", portable = false, open = false, description = "A small window is slightly ajar, perhaps enough to open further." },
  table = { name = "table", list_name = "a kitchen table", location = "kitchen", portable = false, description = "A kitchen table stands ready for meal prep." },
  bottle = { name = "bottle", list_name = "a brown bottle", location = "kitchen", portable = true, description = "A glass bottle containing a quantity of water." },
  lamp = { name = "lamp", list_name = "a brass lamp", location = "living_room", portable = true, description = "A brass lantern that's seen better days." }
}

player = {
  location = "west_of_house",
  inventory = {},
}

synonyms = {
  n = "north", s = "south", e = "east", w = "west",
  north = "north", south = "south", east = "east", west = "west",
  u = "up", d = "down", ne = "northeast", nw = "northwest", se = "southeast", sw = "southwest",
  i = "inventory", inv = "inventory",
  l = "look", x = "examine",
  enter = "in", inside = "in", in = "in", out = "out", outside = "out",
  climb = "in", go = "go", walk = "go",
  open = "open", close = "close", read = "read", examine = "examine"
}
