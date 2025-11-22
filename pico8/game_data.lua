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
  }
}

objects = {
  mailbox = { name = "mailbox", location = "west_of_house", portable = false },
  leaflet = { name = "leaflet", location = "mailbox", portable = true },
  window = { name = "window", location = "behind_house", portable = false }
}

player = {
  location = "west_of_house",
  inventory = {}
}

synonyms = {
  n = "north", s = "south", e = "east", w = "west",
  north = "north", south = "south", east = "east", west = "west",
  u = "up", d = "down", ne = "northeast", nw = "northwest", se = "southeast", sw = "southwest"
}
