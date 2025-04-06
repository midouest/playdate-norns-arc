local mod = require('core/mods')

local ArcDate = {}
ArcDate.__index = ArcDate

function ArcDate.new(id, serial, name, dev)
  local device = setmetatable({}, ArcDate)
  device.quads = {}
  device.dirty = { true, true, true, true }
  for _=1,4 do
    local quad = {}
    for _=1,64 do
      table.insert(quad, 0)
    end
    table.insert(device.quads, quad)
  end
  
  device.id = id
  device.serial = serial
  device.name = name.." "..serial
  device.dev = dev -- opaque pointer
  device.delta = nil -- delta event callback
  device.key = nil -- key event callback
  device.remove = nil -- device unplug callback
  device.port = nil

  -- autofill next postiion
  local connected = {}
  for i=1,4 do
    table.insert(connected, arc.vports[i].name)
  end
  if not tab.contains(connected, device.name) then
    for i=1,4 do
      if arc.vports[i].name == "none" then
        arc.vports[i].name = device.name
        break
      end
    end
  end
  
  return device
end

function ArcDate:led(ring, x, val)
  if x < 0 then
    x = x + 65
  end
  if x == 0 then
    x = 1
  end
  self.quads[ring][x] = val
  self.dirty[ring] = true
end

function ArcDate:all(val)
  for i, quad in ipairs(self.quads) do
    for j=1,64 do
      quad[j] = val
    end
    self.dirty[i] = true
  end
end

function ArcDate:refresh()
  for i, quad in ipairs(self.quads) do
    if self.dirty[i] then
      local data = ''
      for j=1,64 do
        data = data .. string.char((0xf & quad[j]) + 48)
      end
      local msg = "arc: map "..string.char((0x3&(i-1))+48).." "..data
      playdate.send(msg)
      self.dirty[i] = false
    end
  end
end

function ArcDate:segment(ring, from, to, level)
  arc.segment(self, ring, from, to, level)
end

local function connect_playdate_arc(id, name, dev)
  print("playdate arc add: "..id)
  local g = ArcDate.new(id, name, "", dev)
  arc.devices[id] = g
  arc.update_devices()
  if arc.add ~= nil then arc.add(g) end
end

local function remove_playdate_arc(id)
  print("playdate arc remove: "..id)
  local g = arc.devices[id]
  if g then
    if arc.vports[g.port].remove then
      arc.vports[g.port].remove()
    end
    if arc.remove then
      arc.remove(arc.devices[id])
    end
  end
  arc.devices[id] = nil
  arc.update_devices()
end

local arc_date_connected = false

local function handle_playdate_arc_event(id, msg)
  local prefix = msg:sub(1, 9)
  if prefix == "arc: mod " then
    local s = tonumber(msg:sub(10, 10))
    if s then
      connect_playdate_arc(id, "Playdate", playdate.dev)
    else
      remove_playdate_arc(id)
    end
  elseif prefix == "arc: enc " then
    local n = tonumber(msg:sub(10, 10))
    local delta = tonumber(msg:sub(12, #msg))
    _norns.arc.delta(id, n+1, delta)
  elseif prefix == "arc: key " then
    local n = tonumber(msg:sub(10, 10))
    local s = tonumber(msg:sub(12, 12))
    _norns.arc.key(id, n+1, s)
  end
end

mod.hook.register("system_post_startup", "playdate arc emulation", function()
  _norns.playdate.mod_add:register("playdate arc add", function(id, name, dev)
    playdate.send("arc: mod?")
  end)
  
  _norns.playdate.mod_remove:register("playdate arc remove", function(id)
    remove_playdate_arc(id)
  end)
  
  _norns.playdate.mod_event:register("playdate arc event", function(id, line)
    handle_playdate_arc_event(id, line)
  end)
  
  playdate.send("arc: mod?")
end)

