-- Run a Z-machine story file using the lightweight Lua interpreter
-- Default story is COMPILED/zork1.z3 in this repository.

package.path = package.path .. ';./pico8/tools/?.lua;./?.lua'

local zmachine = require('zmachine')

local story_path = arg[1] or 'COMPILED/zork1.z3'
local max_steps = tonumber(arg[2])

local vm, err = zmachine.load(story_path)
if not vm then
  io.stderr:write('Failed to load story: ' .. tostring(err) .. "\n")
  os.exit(1)
end

vm.input_provider = function()
  io.write('> ')
  io.flush()
  return io.read('*l') or ''
end

local steps = 0
while not vm.halted do
  vm:step()
  local chunk = vm:flush_output()
  if #chunk > 0 then io.write(chunk) io.flush() end
  steps = steps + 1
  if max_steps and steps >= max_steps then
    io.stderr:write('\n[step limit reached]\n')
    break
  end
end

local remaining = vm:flush_output()
if #remaining > 0 then io.write(remaining) end
