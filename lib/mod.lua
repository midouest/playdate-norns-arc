local mod = require('core/mods')

local ArcDate = {}
ArcDate.__index = ArcDate

function ArcDate.new(id, serial, name, dev)
  local device = setmetatable({}, ArcDate)
  device.quads = {}
  device.dirty = true
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
  self.quads[ring][x] = val
  self.dirty = true
end

function ArcDate:all(val)
  for _, quad in ipairs(self.quads) do
    for i=1,64 do
      quad[i] = val
    end
  end
  self.dirty = true
end

function ArcDate:refresh()
  for i, quad in ipairs(self.quads) do
    local data = ''
    for j=1,64 do
      data = data .. string.char((0xf & quad[j]) + 48)
    end
    local msg = "~arc: map "..string.char((0x3&(i-1))+48).." "..data
    playdate.send(msg)
  end
  self.dirty = false
end

function ArcDate:segment(ring, from, to, level)
  arc.segment(self, ring, from, to, level)
end

mod.hook.register("system_post_startup", "init playdate arc handlers", function()
  local function connect_playdate_arc(id, name, dev)
    local g = ArcDate.new(id, name, "", dev)
    arc.devices[id] = g
    arc.update_devices()
    if arc.add ~= nil then arc.add(g) end
  end
  
  table.insert(_norns.playdate.add_hooks, function(id, name, dev)
    print("adding playdate arc")
    connect_playdate_arc(id, name, dev)
  end)
  
  table.insert(_norns.playdate.remove_hooks, function(id)
    print("removing playdate arc")
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
  end)
  
  table.insert(_norns.playdate.event_hooks, function(id, msg)
    if msg:sub(1, 11) == "~~arc: enc " then
      local n = tonumber(msg:sub(12, 12))
      local delta = tonumber(msg:sub(14, #msg))
      _norns.arc.delta(id, n+1, delta)
    elseif msg:sub(1, 11) == "~~arc: key " then
      local n = tonumber(msg:sub(12, 12))
      local s = tonumber(msg:sub(14, 14))
      _norns.arc.key(id, n+1, s)
    end
  end)
end)
