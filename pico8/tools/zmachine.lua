-- Lightweight Z-machine interpreter core written in Lua
-- Intended to run inside Picotron (Lua 5.4) or the Pico-8 Lua subset
-- This focuses on Version 3 story files such as the compiled Zork I asset
-- at COMPILED/zork1.z3. The implementation is intentionally compact and
-- targets the core opcodes exercised during boot and early gameplay.

local zmachine = {}

local function read_file_bytes(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local data = f:read("*all")
  f:close()
  local bytes = {}
  for i = 1, #data do
    bytes[i] = data:byte(i)
  end
  return bytes
end

local function read_word(mem, addr)
  return mem[addr + 1] * 256 + mem[addr + 2]
end

local function write_word(mem, addr, value)
  mem[addr + 1] = math.floor(value / 256) % 256
  mem[addr + 2] = value % 256
end

-- Provide a bit32-compatible shim for Lua 5.3+ bit operators
local bit32 = bit32 or {
  band = function(a, b) return a & b end,
  bor = function(a, b) return a | b end,
  bxor = function(a, b) return a ~ b end,
  bnot = function(a) return ~a end,
  lshift = function(a, b) return a << b end,
  rshift = function(a, b) return a >> b end,
}

local function make_output_buffer()
  local buffer = {}
  return {
    write = function(text)
      table.insert(buffer, text)
    end,
    flush = function()
      local chunk = table.concat(buffer)
      buffer = {}
      return chunk
    end,
    get = function()
      return buffer
    end
  }
end

-- alphabets per the Version 3 Z-machine spec
local alphabets = {
  {" ", "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"},
  {" ", "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"},
  {" ", "\n","0","1","2","3","4","5","6","7","8","9",".",",","!","?","_","#","'","\"","/","\\","-",":","(",")"}
}

local function decode_zscii(vm, addr)
  local mem = vm.memory
  local output = {}
  local alphabet = 1
  local shift_lock = false
  local i = addr
  while true do
    local word = read_word(mem, i)
    local is_end = bit32.band(word, 0x8000) ~= 0
    local zchars = {
      bit32.rshift(bit32.band(word, 0x7c00), 10),
      bit32.rshift(bit32.band(word, 0x03e0), 5),
      bit32.band(word, 0x001f)
    }
    for _, zc in ipairs(zchars) do
      if zc == 0 then
        table.insert(output, " ")
      elseif zc == 1 or zc == 2 or zc == 3 then
        -- Abbreviation base table index; next zchar chooses the entry
        vm.pending_abbrev = (zc - 1) * 32
      elseif zc == 4 then
        alphabet = 2
        shift_lock = false
      elseif zc == 5 then
        alphabet = 3
        shift_lock = false
      else
        if vm.pending_abbrev then
          local entry = read_word(mem, vm.header.abbrev_table + (vm.pending_abbrev + zc) * 2)
          vm.pending_abbrev = nil
          local addr2 = entry * 2
          local abbrev = decode_zscii(vm, addr2)
          table.insert(output, abbrev)
        else
          table.insert(output, alphabets[alphabet][zc + 1] or "")
        end
        if not shift_lock then alphabet = 1 end
      end
    end
    i = i + 2
    if is_end then break end
  end
  return table.concat(output)
end

local function branch(vm, cond, pc_after_operands)
  local offset = vm:read_byte(pc_after_operands)
  local short_form = bit32.band(offset, 0x40) ~= 0
  local invert = bit32.band(offset, 0x80) ~= 0
  local branch_true = cond ~= invert
  offset = bit32.band(offset, 0x3f)
  if offset == 0 then
    if branch_true then vm:ret(false) end
    return nil
  elseif offset == 1 then
    if branch_true then vm:ret(true) end
    return nil
  end
  local new_pc
  if short_form then
    new_pc = pc_after_operands + offset - 2
  else
    local hi = offset
    local lo = vm:read_byte(pc_after_operands + 1)
    local signed = bit32.lshift(hi, 8) + lo
    if signed >= 0x8000 then signed = signed - 0x10000 end
    new_pc = pc_after_operands + signed - 2
    vm.pc = new_pc
    return pc_after_operands + 2
  end
  vm.pc = new_pc
  return pc_after_operands + 1
end

local function make_vm(memory)
  local vm = {
    memory = memory,
    header = {},
    pc = 0,
    stack = {},
    callstack = {},
    output = make_output_buffer(),
    halted = false,
    pending_abbrev = nil,
  }

  function vm:read_byte(addr)
    return self.memory[addr + 1] or 0
  end

  function vm:store_byte(addr, value)
    self.memory[addr + 1] = value % 256
  end

  function vm:store_word(addr, value)
    write_word(self.memory, addr, value)
  end

  function vm:push(value)
    table.insert(self.stack, value % 0x10000)
  end

  function vm:pop()
    local v = self.stack[#self.stack]
    self.stack[#self.stack] = nil
    return v or 0
  end

  function vm:load_var(var)
    if var == 0 then
      return self:pop()
    elseif var < 0x10 then
      return self.callstack[#self.callstack].locals[var]
    else
      local addr = self.header.globals + (var - 0x10) * 2
      return read_word(self.memory, addr)
    end
  end

  function vm:store_var(var, value)
    value = value % 0x10000
    if var == 0 then
      self:push(value)
    elseif var < 0x10 then
      self.callstack[#self.callstack].locals[var] = value
    else
      write_word(self.memory, self.header.globals + (var - 0x10) * 2, value)
    end
  end

  function vm:ret(value)
    local frame = table.remove(self.callstack)
    if not frame then
      self.halted = true
      return
    end
    if frame.store_var then
      self:store_var(frame.store_var, value or 0)
    end
    if frame.return_pc then
      self.pc = frame.return_pc
    else
      self.halted = true
    end
  end

  function vm:call(addr, args, store_var, opts)
    if addr == 0 then
      if store_var then self:store_var(store_var, 0) end
      return
    end
    local byte_addr = (opts and opts.packed == false) and addr or (addr * 2)
    local local_count = self:read_byte(byte_addr)
    local locals = {}
    local pos = byte_addr + 1
    for i = 1, local_count do
      locals[i] = read_word(self.memory, pos)
      pos = pos + 2
    end
    for i = 1, #args do
      locals[i] = args[i]
    end
    local return_pc = opts and opts.return_pc or self.pc
    table.insert(self.callstack, { return_pc = return_pc, locals = locals, store_var = store_var })
    self.pc = pos
  end

  function vm:print(str)
    self.output:write(str)
  end

  function vm:println(str)
    self.output:write((str or "") .. "\n")
  end

  function vm:flush_output()
    return self.output:flush()
  end

  function vm:step()
    if self.halted then return false end
    local opcode_addr = self.pc
    local opcode = self:read_byte(opcode_addr)
    local op_class
    local form
    if opcode == 0xbe then
      op_class = "ext"
      form = "ext"
    elseif bit32.band(opcode, 0xc0) == 0xc0 then
      op_class = "var"
      form = "var"
    elseif bit32.band(opcode, 0x80) == 0x80 then
      op_class = "1op"
      form = "short"
    elseif bit32.band(opcode, 0x40) == 0x40 then
      op_class = "0op"
      form = "short"
    else
      op_class = "2op"
      form = "long"
    end

    local operands = {}
    local types = {}
    local pc = opcode_addr + 1

    local function read_operand(type_code)
      if type_code == 0 then
        local value = self:read_byte(pc)
        pc = pc + 1
        return value
      elseif type_code == 1 then
        local value = read_word(self.memory, pc)
        pc = pc + 2
        return value
      elseif type_code == 2 then
        local var = self:read_byte(pc)
        pc = pc + 1
        return self:load_var(var)
      end
      return nil
    end

    if op_class == "0op" then
      -- no operands
    elseif op_class == "1op" then
      local type_code = bit32.band(bit32.rshift(opcode, 4), 0x03)
      operands[1] = read_operand(type_code)
      types[1] = type_code
    elseif op_class == "2op" then
      local type_a = bit32.band(bit32.rshift(opcode, 6), 0x01)
      local type_b = bit32.band(bit32.rshift(opcode, 5), 0x01)
      types[1] = type_a == 1 and 2 or 0 -- small const vs var
      types[2] = type_b == 1 and 2 or 0
      operands[1] = read_operand(types[1])
      operands[2] = read_operand(types[2])
    elseif op_class == "var" or op_class == "ext" then
      local type_byte = self:read_byte(pc)
      pc = pc + 1
      for i = 0, 3 do
        local t = bit32.band(bit32.rshift(type_byte, 6 - i * 2), 0x03)
        if t == 3 then break end
        operands[#operands + 1] = read_operand(t)
        types[#types + 1] = t
      end
    end

    local store = nil
    local branch_offset = nil

    local opcode_num = opcode
    if op_class == "var" and opcode >= 0xe0 then
      opcode_num = bit32.band(opcode, 0x1f)
    elseif op_class == "1op" then
      opcode_num = bit32.band(opcode, 0x0f) + 16
    elseif op_class == "0op" then
      opcode_num = bit32.band(opcode, 0x0f)
    else
      opcode_num = bit32.band(opcode, 0x1f)
    end

    -- determine store/branch flags per opcode groups
    local function need_store()
      local store_ops = {
        [0x0d] = true, [0x0c] = true, [0x10] = true, [0x11] = true, [0x12] = true, [0x13] = true,
        [0x14] = true, [0x15] = true, [0x16] = true, [0x17] = true, [0x18] = true, [0x1a] = true,
        [0x1b] = true, [0x1c] = true, [0x1d] = true, [0x1e] = true, [0x1f] = true,
        [0x21] = true, [0x22] = true, [0x23] = true, [0x24] = true, [0x25] = true, [0x26] = true,
        [0x27] = true, [0x28] = true, [0x29] = true, [0x2b] = true,
      }
      return store_ops[opcode_num] or false
    end

    local function need_branch()
      local branch_ops = {
        [0x01] = true, [0x02] = true, [0x03] = true, [0x04] = true, [0x05] = true, [0x06] = true,
        [0x07] = true, [0x08] = true, [0x09] = true, [0x0a] = true, [0x0b] = true,
        [0x10] = true, [0x11] = true, [0x12] = true, [0x13] = true,
        [0x14] = true, [0x15] = true,
        [0x1b] = true, [0x1c] = true, [0x1d] = true, [0x1e] = true,
      }
      return branch_ops[opcode_num] or false
    end

    if need_store() then
      store = self:read_byte(pc)
      pc = pc + 1
    end

    if need_branch() then
      branch_offset = pc
      -- branch decoding done inside opcode execution
    end

    self.pc = pc

    local function branch_if(cond)
      if branch_offset then
        local next_pc = branch(self, cond, branch_offset)
        if next_pc then self.pc = next_pc end
      end
    end

    local function store_result(value)
      if store then self:store_var(store, value) end
    end

    -- Execute opcode subset
    if opcode_num == 0x00 then -- rtrue
      self:ret(1)
    elseif opcode_num == 0x01 then -- rfalse
      self:ret(0)
    elseif opcode_num == 0x02 then -- print
      local text = decode_zscii(self, self.pc)
      self:print(text)
      while bit32.band(read_word(self.memory, self.pc), 0x8000) == 0 do
        self.pc = self.pc + 2
      end
      self.pc = self.pc + 2
    elseif opcode_num == 0x03 then -- print_ret
      local text = decode_zscii(self, self.pc)
      self:println(text)
      while bit32.band(read_word(self.memory, self.pc), 0x8000) == 0 do
        self.pc = self.pc + 2
      end
      self.pc = self.pc + 2
      self:ret(1)
    elseif opcode_num == 0x04 then -- nop
      -- nothing
    elseif opcode_num == 0x0b then -- new_line
      self:println("")
    elseif opcode_num == 0x0c or opcode_num == 0x0d then -- show_status / verify
      store_result(1)
    elseif opcode_num == 0x0f then -- restart
      self.pc = self.header.initial_pc
      self.stack = {}
      self.callstack = {}
    elseif opcode_num == 0x10 then -- ret_popped
      local v = self:pop()
      self:ret(v)
    elseif opcode_num == 0x14 then -- inc
      local var = types[1] == 2 and self:read_byte(opcode_addr + 1) or nil
      local value = (operands[1] + 1) % 0x10000
      if var then self:store_var(var, value) end
    elseif opcode_num == 0x15 then -- dec
      local var = types[1] == 2 and self:read_byte(opcode_addr + 1) or nil
      local value = (operands[1] - 1) % 0x10000
      if var then self:store_var(var, value) end
    elseif opcode_num == 0x16 then -- print_addr
      local addr = operands[1] * 2
      local text = decode_zscii(self, addr)
      self:print(text)
    elseif opcode_num == 0x17 then -- call_1s
      self:call(operands[1], {}, store)
    elseif opcode_num == 0x19 then -- remove_obj
      -- stub: object tree not yet implemented
    elseif opcode_num == 0x1a then -- print_obj
      self:print("[obj:" .. tostring(operands[1]) .. "]")
    elseif opcode_num == 0x1b then -- ret
      self:ret(operands[1])
    elseif opcode_num == 0x1c then -- jump
      local offset = operands[1]
      if offset >= 0x8000 then offset = offset - 0x10000 end
      self.pc = self.pc + offset - 2
    elseif opcode_num == 0x1d then -- print_paddr
      local text = decode_zscii(self, operands[1] * 2)
      self:print(text)
    elseif opcode_num == 0x1e then -- load
      store_result(self:load_var(self:read_byte(opcode_addr + 1)))
    elseif opcode_num == 0x1f then -- not
      store_result(bit32.bnot(operands[1]) % 0x10000)
    elseif opcode_num == 0x20 then -- je
      branch_if(operands[1] == operands[2] or operands[1] == (operands[3] or -1) or operands[1] == (operands[4] or -1))
    elseif opcode_num == 0x21 then -- jl
      branch_if(operands[1] < operands[2])
    elseif opcode_num == 0x22 then -- jg
      branch_if(operands[1] > operands[2])
    elseif opcode_num == 0x23 then -- dec_chk
      local target = (operands[1] - 1) % 0x10000
      branch_if(target < operands[2])
    elseif opcode_num == 0x24 then -- inc_chk
      local target = (operands[1] + 1) % 0x10000
      branch_if(target > operands[2])
    elseif opcode_num == 0x25 then -- jin
      branch_if(false) -- object tree not handled
    elseif opcode_num == 0x26 then -- test
      branch_if(bit32.band(operands[1], operands[2]) == operands[2])
    elseif opcode_num == 0x27 then -- or
      store_result(bit32.bor(operands[1], operands[2]))
    elseif opcode_num == 0x28 then -- and
      store_result(bit32.band(operands[1], operands[2]))
    elseif opcode_num == 0x29 then -- test_attr (stub)
      branch_if(false)
    elseif opcode_num == 0x2a then -- set_attr (stub)
      -- ignored
    elseif opcode_num == 0x2b then -- clear_attr (stub)
      -- ignored
    elseif opcode_num == 0x2c then -- store
      self:store_var(operands[1], operands[2])
    elseif opcode_num == 0x2d then -- insert_obj (stub)
      -- ignored
    elseif opcode_num == 0x2e then -- loadw
      local base = operands[1] + operands[2] * 2
      store_result(read_word(self.memory, base))
    elseif opcode_num == 0x2f then -- loadb
      local base = operands[1] + operands[2]
      store_result(self:read_byte(base))
    elseif opcode_num == 0x30 then -- get_prop (stub)
      store_result(0)
    elseif opcode_num == 0x31 then -- get_prop_addr (stub)
      store_result(0)
    elseif opcode_num == 0x32 then -- get_next_prop (stub)
      store_result(0)
    elseif opcode_num == 0x33 then -- add
      store_result((operands[1] + operands[2]) % 0x10000)
    elseif opcode_num == 0x34 then -- sub
      store_result((operands[1] - operands[2]) % 0x10000)
    elseif opcode_num == 0x35 then -- mul
      store_result((operands[1] * operands[2]) % 0x10000)
    elseif opcode_num == 0x36 then -- div
      store_result(math.floor(operands[1] / operands[2]))
    elseif opcode_num == 0x37 then -- mod
      store_result(operands[1] % operands[2])
    elseif opcode_num == 0x38 then -- call_2s
      self:call(operands[1], { operands[2] }, store)
    elseif opcode_num == 0x39 then -- call_2n
      self:call(operands[1], { operands[2] }, nil)
    elseif opcode_num == 0x3a then -- set_colour (ignored)
    elseif opcode_num == 0x3b then -- throw
      self:ret(operands[1])
    elseif opcode_num == 0x3c then -- call
      self:call(operands[1], { operands[2], operands[3], operands[4] }, store)
    elseif opcode_num == 0x3d then -- storew
      write_word(self.memory, operands[1] + operands[2] * 2, operands[3])
    elseif opcode_num == 0x3e then -- storeb
      self:store_byte(operands[1] + operands[2], operands[3])
    elseif opcode_num == 0x3f then -- put_prop (stub)
    elseif opcode_num == 0x40 then -- sread/read (stub: echo input)
      local text = (self.input_provider and self.input_provider()) or ""
      -- naive write of ZSCII bytes into provided text buffer address
      local addr = operands[1]
      self:store_byte(addr, #text)
      for i = 1, #text do
        self:store_byte(addr + i, string.byte(text, i))
      end
    elseif opcode_num == 0x41 then -- print_char
      self:print(string.char(operands[1]))
    elseif opcode_num == 0x42 then -- print_num
      self:print(tostring(operands[1]))
    elseif opcode_num == 0x43 then -- random
      store_result(math.random(operands[1]))
    elseif opcode_num == 0x44 then -- push
      self:push(operands[1])
    elseif opcode_num == 0x45 then -- pull
      store_result(self:pop())
    elseif opcode_num == 0x46 then -- split_window
      -- ignored
    elseif opcode_num == 0x47 then -- set_window
      -- ignored
    elseif opcode_num == 0x49 then -- erase_window
      -- ignored
    elseif opcode_num == 0x4a then -- erase_line
    elseif opcode_num == 0x4b then -- set_cursor
    elseif opcode_num == 0x4c then -- get_cursor
      store_result(0)
    elseif opcode_num == 0x4d then -- not (ext form) fallback
      store_result(bit32.bnot(operands[1]) % 0x10000)
    elseif opcode_num == 0x58 then -- quit
      self.halted = true
    else
      self:println("[unhandled opcode " .. string.format("0x%02x", opcode_num) .. "]")
      self.halted = true
    end

    return not self.halted
  end

  function vm:run(max_steps)
    local steps = 0
    while not self.halted do
      self:step()
      steps = steps + 1
      if max_steps and steps >= max_steps then break end
    end
    return self:flush_output()
  end

  return vm
end

function zmachine.load(path)
  local memory, err = read_file_bytes(path)
  if not memory then return nil, err end
  local vm = make_vm(memory)
  vm.header.version = memory[1]
  vm.header.initial_pc = read_word(memory, 0x06)
  vm.header.globals = read_word(memory, 0x0c) * 2
  vm.header.abbrev_table = read_word(memory, 0x18) * 2
  vm.pc = vm.header.initial_pc
  vm:call(vm.header.initial_pc, {}, nil, { packed = false, return_pc = nil })
  return vm
end

return zmachine
