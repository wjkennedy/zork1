-- utility to bundle the pico-8 zork workbench into a picotron-friendly cart
-- run with: lua pico8/tools/pack_for_picotron.lua
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
  local dir = src:match('@(.+)/pack_for_picotron.lua')
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

  local target = build_dir .. '/zork1.p64'
  write_picotron_cart(target, merged)
  print('Wrote Picotron cart to ' .. target)
  print('Load inside Picotron with: load(' .. string.format('%q', target) .. ') then run')
end

main()
