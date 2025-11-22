-- pico-8 scaffold for a text adventure port of zork i
-- this cart focuses on interaction flow; world data lives in game_data.lua

#include game_data.lua

local text_buffer = {}
local input_line = ""
local max_lines = 18
local wrap_width = 31
local cursor_timer = 0
local cursor_state = true

function _init()
  poke(0x5f2d, 1) -- enable devkit keyboard for desktop builds
  add_output("WELCOME TO ZORK (PICO-8 WIP)")
  add_output("Type commands like 'look', 'n', or 'take leaflet'.")
  describe_location()
end

function _update60()
  cursor_timer = (cursor_timer + 1) % 30
  if cursor_timer == 0 then
    cursor_state = not cursor_state
  end
  read_keyboard()
end

function _draw()
  cls(0)
  local y = 2
  for line in all(text_buffer) do
    print(line, 2, y, 7)
    y += 6
  end
  rectfill(0, 112, 127, 127, 1)
  print("> " .. input_line .. (cursor_state and "_" or " "), 2, 116, 11)
end

function read_keyboard()
  local char_code = stat(31)
  while char_code ~= 0 do
    handle_char(char_code)
    char_code = stat(31)
  end
end

function handle_char(code)
  if code == 8 then -- backspace
    if #input_line > 0 then
      input_line = sub(input_line, 1, #input_line - 1)
    end
  elseif code == 13 then -- enter
    local command = input_line
    input_line = ""
    execute_command(command)
  else
    local char = chr(code)
    if char >= " " and char <= "~" then
      input_line ..= lower(char)
    end
  end
end

function execute_command(raw)
  local command = trim(raw)
  if #command == 0 then return end

  add_output("> " .. command)
  local verb, noun = parse_command(command)

  if verb == "look" then
    describe_location(true)
  elseif verb == "inventory" then
    show_inventory()
  elseif verb == "examine" then
    examine_object(noun)
  elseif verb == "read" then
    read_object(noun)
  elseif is_direction(verb) then
    move_player(verb)
  elseif verb == "go" then
    if noun == "" then
      add_output("Go where?")
    else
      move_player(synonyms[noun] or noun)
    end
  elseif verb == "take" then
    take_object(noun)
  elseif verb == "drop" then
    drop_object(noun)
  elseif verb == "open" and noun == "mailbox" then
    open_mailbox()
  elseif verb == "open" and noun == "window" then
    open_window()
  elseif verb == "close" and noun == "window" then
    close_window()
  elseif verb == "help" then
    add_output("Supported: look/l, n/s/e/w/in/out, take/drop <obj>, inventory, examine/read <obj>")
  else
    add_output("I don't know how to '" .. verb .. "'.")
  end
end

function parse_command(text)
  local verb = ""
  local noun = ""
  for token in all(split(text, " ")) do
    if verb == "" then
      verb = token
    else
      noun = noun == "" and token or noun .. " " .. token
    end
  end
  verb = synonyms[verb] or verb
  return verb, noun
end

function is_direction(word)
  return word == "north" or word == "south" or word == "east" or word == "west" or
         word == "northeast" or word == "northwest" or word == "southeast" or word == "southwest" or
         word == "up" or word == "down" or word == "in" or word == "out"
end

function move_player(direction)
  if not direction or direction == "" then
    add_output("You can't go that way.")
    return
  end

  if direction == "in" then
    crawl_inside()
    return
  elseif direction == "out" then
    crawl_out()
    return
  end

  local room = rooms[player.location]
  local target = room.exits and room.exits[sub(direction, 1, 1)] or nil
  if target then
    player.location = target
    describe_location(true)
  else
    add_output("You can't go that way.")
  end
end

function describe_location(show_name)
  local room = rooms[player.location]
  if show_name then add_output(room.name) end
  add_output(room.description)
  local items = objects_at_location(player.location)
  if #items > 0 then
    add_output("You see " .. join_list(items) .. ".")
  end
end

function objects_at_location(loc)
  local results = {}
  for _, obj in pairs(objects) do
    if obj.location == loc then
      if obj.name == "window" then
        local descriptor = obj.open and "an open window" or "a small window (closed)"
        add(results, descriptor)
      elseif obj.list_name then
        add(results, obj.list_name)
      else
        add(results, obj.name)
      end
    elseif obj.location == "mailbox" and loc == "west_of_house" and obj.name == "leaflet" then
      add(results, "a leaflet in the mailbox")
    end
  end
  return results
end

function take_object(noun)
  if noun == "" then
    add_output("Take what?")
    return
  end

  for id, obj in pairs(objects) do
    if obj.name == noun and obj.location == player.location then
      if not obj.portable then
        add_output("You can't take the " .. noun .. ".")
        return
      end
      obj.location = "inventory"
      add(player.inventory, id)
      add_output("Taken.")
      return
    end
  end

  add_output("There isn't a " .. noun .. " here.")
end

function drop_object(noun)
  if noun == "" then
    add_output("Drop what?")
    return
  end

  for i = #player.inventory, 1, -1 do
    local id = player.inventory[i]
    if objects[id].name == noun then
      objects[id].location = player.location
      deli(player.inventory, i)
      add_output("Dropped.")
      return
    end
  end

  add_output("You aren't carrying a " .. noun .. ".")
end

function show_inventory()
  if #player.inventory == 0 then
    add_output("You are empty-handed.")
  else
    local names = {}
    for item in all(player.inventory) do
      add(names, objects[item].list_name or objects[item].name)
    end
    add_output("You are carrying " .. join_list(names) .. ".")
  end
end

function open_mailbox()
  if player.location ~= "west_of_house" then
    add_output("You see no mailbox here.")
    return
  end

  if objects.leaflet.location ~= "mailbox" then
    add_output("The mailbox is empty.")
  else
    objects.leaflet.location = player.location
    add_output("Opening the mailbox reveals a leaflet.")
  end
end

function open_window()
  if player.location ~= "behind_house" then
    add_output("There's nothing here you can open that way.")
    return
  end

  if objects.window.open then
    add_output("The window is already open.")
  else
    objects.window.open = true
    add_output("With some effort, you open the window wide enough to enter.")
  end
end

function close_window()
  if player.location ~= "behind_house" and player.location ~= "kitchen" then
    add_output("There is no window you can close here.")
    return
  end

  if not objects.window.open then
    add_output("The window is already closed.")
  else
    objects.window.open = false
    add_output("You close the window.")
  end
end

function crawl_inside()
  if player.location ~= "behind_house" then
    add_output("You can't go that way.")
    return
  end

  if objects.window.open then
    player.location = "kitchen"
    add_output("You crawl through the window and find yourself in the kitchen.")
    describe_location(true)
  else
    add_output("The window is closed and too small to pass through as-is.")
  end
end

function crawl_out()
  if player.location == "kitchen" then
    if objects.window.open then
      player.location = "behind_house"
      add_output("You squeeze back out the kitchen window.")
      describe_location(true)
    else
      add_output("The window is closed and you can't get through.")
    end
  else
    add_output("You can't go that way.")
  end
end

function add_output(text)
  for line in all(wrap_text(text)) do
    add(text_buffer, line)
  end
  while #text_buffer > max_lines do
    deli(text_buffer, 1)
  end
end

function find_object(noun)
  for id, obj in pairs(objects) do
    if obj.name == noun then
      return id, obj
    end
  end
  return nil, nil
end

function read_object(noun)
  if noun == "" then
    add_output("Read what?")
    return
  end

  local id, obj = find_object(noun)
  if not id then
    add_output("There's nothing like that to read.")
    return
  end

  if obj.location == "inventory" or obj.location == player.location or (obj.location == "mailbox" and player.location == "west_of_house") then
    if id == "leaflet" then
      add_output("WELCOME TO ZORK! Adventure awaits inside.")
    else
      add_output("There's nothing written on the " .. noun .. ".")
    end
  else
    add_output("You can't see any " .. noun .. " here.")
  end
end

function examine_object(noun)
  if noun == "" then
    add_output("Examine what?")
    return
  end

  local id, obj = find_object(noun)
  if not id then
    add_output("You don't see that here.")
    return
  end

  if obj.location == player.location or obj.location == "inventory" or (obj.location == "mailbox" and player.location == "west_of_house") then
    if id == "window" then
      local state = obj.open and "It is open wide enough to crawl through." or "It looks like it could be pried open."
      add_output(obj.description .. " " .. state)
    else
      add_output(obj.description or ("It's just a " .. noun .. "."))
    end
  else
    add_output("You don't see that here.")
  end
end

function wrap_text(text)
  local lines = {}
  local current = ""
  for word in all(split(text, " ")) do
    if #current + #word + 1 > wrap_width then
      add(lines, current)
      current = word
    else
      current = current == "" and word or current .. " " .. word
    end
  end
  if #current > 0 then add(lines, current) end
  return lines
end

function trim(str)
  while #str > 0 and sub(str, 1, 1) == " " do
    str = sub(str, 2)
  end
  while #str > 0 and sub(str, #str, #str) == " " do
    str = sub(str, 1, #str - 1)
  end
  return str
end

function join_list(items)
  if #items == 1 then return items[1] end
  if #items == 2 then return items[1] .. " and " .. items[2] end
  local result = ""
  for i=1,#items do
    if i == #items then
      result ..= "and " .. items[i]
    else
      result ..= items[i] .. ", "
    end
  end
  return result
end
