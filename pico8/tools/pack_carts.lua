-- bundle the pico-8 zork workbench into both pico-8 and picotron cartridges
-- run with: lua pico8/tools/pack_carts.lua
-- compatible with stock Lua 5.3+ (as shipped with Picotron)

local function read_file(path)
  local fh, err = io.open(path, 'r')
  assert(fh, ('unable to open %s: %s'):format(path, err))
  local data = fh:read('*a')
  fh:close()
  return data
end

local function ensure_dir(path)
  local ok = os.execute(string.format("mkdir -p %q", path))
  assert(ok == true or ok == 0, 'failed to create directory: ' .. tostring(path))
end

local function inline_game_data(main_src, data_src)
  local output = {}
  for line in main_src:gmatch('([^\n]*\n?)') do
    if line == '' then break end
    if line:match('^#include%s+game_data.lua') then
      table.insert(output, data_src)
    else
      table.insert(output, line)
    end
  end
  return table.concat(output)
end

local function write_pico8_cart(path, lua_source)
  local header = 'pico-8 cartridge // http://www.pico-8.com\nversion 41\n__lua__\n'
  local fh, err = io.open(path, 'w')
  assert(fh, ('unable to write %s: %s'):format(path, err))
  fh:write(header)
  fh:write(lua_source)
  fh:close()
end

local function write_picotron_cart(path, lua_source)
  local header = 'picotron cartridge // http://www.lexaloffle.com/picotron\nversion 1\n__lua__\n'
  local fh, err = io.open(path, 'w')
  assert(fh, ('unable to write %s: %s'):format(path, err))
  fh:write(header)
  fh:write(lua_source)
  fh:close()
end

local function script_dir()
  local src = debug.getinfo(1, 'S').source
  local dir = src:match('@(.+)/pack_carts.lua')
  assert(dir, 'unable to resolve script directory')
  return dir
end

local function main()
  local base = script_dir():gsub('/tools$', '') .. '/'
  local main_src = read_file(base .. 'main.lua')
  local data_src = read_file(base .. 'game_data.lua')
  local merged = inline_game_data(main_src, data_src)

  local build_dir = base .. 'build'
  ensure_dir(build_dir)

  local pico8_target = build_dir .. '/zork1.p8'
  write_pico8_cart(pico8_target, merged)
  print('Wrote Pico-8 cart to ' .. pico8_target)

  local picotron_target = build_dir .. '/zork1.p64'
  write_picotron_cart(picotron_target, merged)
  print('Wrote Picotron cart to ' .. picotron_target)

  print('Load Pico-8 cart with: load(' .. string.format('%q', pico8_target) .. ') then run')
  print('Load Picotron cart with: load(' .. string.format('%q', picotron_target) .. ') then run')
end

main()
