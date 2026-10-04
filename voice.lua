-- Fila de audio sequencial com interrupcao do spotter, beep, chiado de
-- radio e legendas. So toca .wav da Sally (+ sfx). Sem TTS, sem rede.

local Voice = {}
Voice.__index = Voice

local START_GRACE = 0.35
local HARD_TIMEOUT = 12

local function num(v)
  local n = tonumber(v)
  if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
  return n
end

local function clamp(v, lo, hi, fb)
  return math.max(lo, math.min(hi, num(v) or fb))
end

local function dispose(ev)
  if not ev then return end
  pcall(function() ev:stop() end)
  pcall(function() ev:dispose() end)
end

local function makeEvent(path, looped)
  if type(path) ~= 'string' or path == '' then return nil end
  if not ac.AudioEvent or not ac.AudioEvent.fromFile then return nil end
  local ok, ev = pcall(ac.AudioEvent.fromFile, { filename = path, use3D = false, loop = looped == true }, false)
  if not ok or not ev then return nil end
  return ev
end

local function probe(ev, member)
  local ok, value = pcall(function()
    local v = ev[member]
    if type(v) == 'function' then return v(ev) end
    return v
  end)
  if ok then return value end
end

local function rank(entry)
  if entry.interrupt then return 100 end
  if entry.priorityValue then return entry.priorityValue end
  return entry.priority and 90 or 20
end

function Voice.new(root)
  return setmetatable({ root = root or '', queue = {}, playing = nil,
    bg = nil, bgPath = nil, bgPlaying = false, bgFailed = false,
    volume = 22.5, speed = 1, pitch = 1, bgVolume = 0.5,
    clock = 0, gate = nil, onCaption = nil, onIdle = nil }, Voice)
end

function Voice:setVolume(v) self.volume = clamp(v, 0, 50, 22.5) end
function Voice:setSpeed(v) self.speed = clamp(v, 0.5, 2, 1) end
function Voice:setPitch(v) self.pitch = clamp(v, 0.5, 2, 1) end
function Voice:setBackgroundVolume(v)
  self.bgVolume = clamp(v, 0, 8, 0.5)
  if self.bg then pcall(function() self.bg.volume = self.bgVolume end) end
end
function Voice:setBackground(path)
  dispose(self.bg)
  self.bg, self.bgPath, self.bgPlaying, self.bgFailed = nil, path, false, false
end

function Voice:_ensureBg()
  if self.bg or not self.bgPath or self.bgFailed then return end
  self.bg = makeEvent(self.bgPath, true)
  self.bgFailed = self.bg == nil
end

function Voice:_startBg()
  self:_ensureBg()
  if not self.bg or self.bgPlaying then return end
  local ok = pcall(function() self.bg.volume = self.bgVolume; self.bg:start() end)
  self.bgPlaying = ok
  if not ok then dispose(self.bg); self.bg, self.bgFailed = nil, true end
end

function Voice:_stopBg()
  dispose(self.bg)
  self.bg, self.bgPlaying = nil, false
end

-- opts: {beep, vol, priority(nivel), group, ttl, valid(fn), key}
function Voice:enqueue(path, caption, who, opts)
  if type(path) ~= 'string' or path == '' then return false end
  opts = type(opts) == 'table' and opts or {}
  local ttl = num(opts.ttl)
  local entry = { path = path, caption = caption, speaker = who,
    isBeep = opts.beep == true, volume = opts.vol, priority = opts.priority == true,
    priorityValue = num(opts.priorityValue or opts.priority),
    createdAt = self.clock, group = opts.group, key = opts.key or path,
    valid = opts.valid, expiresAt = ttl and (self.clock + math.max(0, ttl)) or nil }
  local current = self.playing and self.playing.entry
  if current and rank(entry) > rank(current) then
    if current.group then self:cancel(current.group, true)
    else dispose(self.playing.event); self.playing = nil; self:_stopBg() end
  end
  local index = #self.queue + 1
  for i, queued in ipairs(self.queue) do
    if rank(queued) < rank(entry) then index = i; break end
  end
  table.insert(self.queue, index, entry)
  -- The queue is sorted from highest to lowest priority: drop the least urgent
  -- backlog entry, never an alert or spotter call at the front.
  while #self.queue > 40 do table.remove(self.queue) end
  return true
end

function Voice:cancel(group, stopPlaying)
  if group == nil then return end
  for i = #self.queue, 1, -1 do
    if self.queue[i].group == group then table.remove(self.queue, i) end
  end
  if stopPlaying and self.playing and self.playing.entry.group == group then
    dispose(self.playing.event)
    self.playing = nil
    self:_stopBg()
  end
end

-- Spotter: interrompe tudo do relatorio atual. preserveQueue mantém a fila.
function Voice:interruptWith(path, caption, who, volume, preserveQueue, opts)
  if type(path) ~= 'string' or path == '' then return false end
  opts = type(opts) == 'table' and opts or {}
  local ttl = num(opts.ttl)
  local entry = { path = path, caption = caption, speaker = who, volume = volume,
    interrupt = true, createdAt = self.clock, group = opts.group, key = opts.key or path,
    priorityValue = 100, valid = opts.valid,
    expiresAt = ttl and (self.clock + math.max(0, ttl)) or nil }
  local current = self.playing and self.playing.entry
  if current and current.interrupt and current.key == entry.key then return true end
  if not current and self.queue[1] and self.queue[1].interrupt and self.queue[1].key == entry.key then
    self.queue[1].expiresAt = entry.expiresAt
    return true
  end
  local interruptedGroup = current and current.group
  if self.playing then dispose(self.playing.event) end
  self.playing = nil
  local pending = self.queue
  self.queue = { entry }
  for _, queued in ipairs(pending) do
    local sameReport = interruptedGroup ~= nil and queued.group == interruptedGroup
    if not queued.interrupt and not sameReport and (preserveQueue or rank(queued) >= 70) then
      self.queue[#self.queue + 1] = queued
    end
  end
  while #self.queue > 40 do table.remove(self.queue) end
  self:_stopBg()
  return true
end

function Voice:clear()
  self.queue = {}
  if self.playing then dispose(self.playing.event) end
  self.playing = nil
  self:_stopBg()
end

function Voice:isBusy() return self.playing ~= nil or #self.queue > 0 end
function Voice:isBusyAtOrAbove(priority)
  if self.playing and rank(self.playing.entry) >= priority then return true end
  for _, entry in ipairs(self.queue) do
    if rank(entry) >= priority then return true end
  end
  return false
end

function Voice:_startNext()
  self.playing = nil
  while #self.queue > 0 do
    local first = self.queue[1]
    if first.expiresAt and self.clock >= first.expiresAt then
      table.remove(self.queue, 1)
      self:cancel(first.group, false)
    elseif self.gate and rank(first) < 70 and not self.gate(first) then
      self:_stopBg()
      return
    else
      local entry = table.remove(self.queue, 1)
      local valid = true
      if entry.valid then local ok, result = pcall(entry.valid); valid = ok and result == true end
      if not valid then
        self:cancel(entry.group, false)
      else
        local ev = makeEvent(entry.path, false)
        local speed = entry.isBeep and 1 or self.speed
        local pitch = entry.isBeep and 1 or self.pitch
        local effective = clamp(speed * pitch, 0.5, 2, 1)
        local vol = clamp(entry.volume, 0, 50, self.volume)
        local ok = false
        if ev then ok = pcall(function() ev.volume = vol; ev.pitch = effective; ev:start() end) end
        if ok then
          local duration = num(probe(ev, 'getDuration'))
          local expected = duration and duration / effective or nil
          self.playing = { event = ev, entry = entry, startedAt = self.clock,
            expectedDuration = expected, effectivePitch = effective, observedPlaying = false,
            maxDur = math.max(HARD_TIMEOUT / math.min(effective, 1), (expected or 0) + 1) }
          self:_startBg()
          if not entry.isBeep and entry.caption and self.onCaption then
            pcall(self.onCaption, entry.caption, entry.speaker, entry)
          end
          return
        end
        dispose(ev)
        if not entry.isBeep then self:cancel(entry.group, false) end
      end
    end
  end
  self:_stopBg()
  if self.onIdle then pcall(self.onIdle) end
end

local function evEnded(playing, now)
  local ev, elapsed = playing.event, now - playing.startedAt
  if not ev or elapsed >= playing.maxDur then return true end
  local isPlaying = probe(ev, 'isPlaying')
  if isPlaying == true then playing.observedPlaying = true; return false end
  local position = num(probe(ev, 'getTimelinePosition'))
  if position and position > 0 then playing.observedPlaying = true end
  if not playing.observedPlaying and elapsed < START_GRACE then return false end
  if isPlaying == false then
    if not playing.observedPlaying and playing.expectedDuration then
      return elapsed >= playing.expectedDuration + START_GRACE
    end
    return true
  end
  if probe(ev, 'isValid') == false or probe(ev, 'stopped') == true or probe(ev, 'alive') == false then return true end
  return playing.expectedDuration ~= nil and elapsed >= playing.expectedDuration + START_GRACE
end

function Voice:update(dt)
  self.clock = self.clock + math.max(0, num(dt) or 0)
  if not self.playing then
    if #self.queue > 0 then self:_startNext() end
    return
  end
  if evEnded(self.playing, self.clock) then
    dispose(self.playing.event)
    self:_startNext()
  end
end

return Voice
