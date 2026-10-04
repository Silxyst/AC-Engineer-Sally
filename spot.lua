-- Spotter de proximidade estilo CrewChief: "car left/right", "three wide",
-- "still there" e "clear". Geometria propria, sem dependencias.

local Spot = {}

local function safe(fn)
  local ok, value = pcall(fn)
  if ok then return value end
  return nil
end

local function number(v)
  local n = tonumber(v)
  if not n or n ~= n then return nil end
  return n
end

local function readCar(car)
  if not car then return nil end
  if safe(function() return car.isActive end) == false then return nil end
  if safe(function() return car.isConnected end) == false then return nil end
  local px = number(safe(function() return car.position.x end))
  local py = number(safe(function() return car.position.y end))
  local pz = number(safe(function() return car.position.z end))
  if not px or not pz then return nil end
  local vx = number(safe(function() return car.velocity.x end)) or 0
  local vz = number(safe(function() return car.velocity.z end)) or 0
  local lx, lz
  do
    local look = safe(function() return car.look end)
    local sx, sz
    if look then sx, sz = number(look.x), number(look.z) end
    if (not sx or not sz) and safe(function() return car.transform end) then
      local t = safe(function() return car.transform.look end)
      if t then sx, sz = number(t.x), number(t.z) end
    end
    local len = sx and sz and math.sqrt(sx * sx + sz * sz) or 0
    if len > 0.001 then lx, lz = sx / len, sz / len end
    if (not lx) and (math.abs(vx) + math.abs(vz) > 0.5) then
      local vl = math.sqrt(vx * vx + vz * vz)
      lx, lz = vx / vl, vz / vl
    end
  end
  local speed = number(safe(function() return car.speedKmh end))
  if not speed then speed = math.sqrt(vx * vx + vz * vz) * 3.6 end
  return {
    id = number(safe(function() return car.index end)),
    x = px, y = py or 0, z = pz, vx = vx, vz = vz,
    lx = lx, lz = lz, speed = speed or 0,
    inPit = safe(function() return car.isInPitlane end) == true,
  }
end

-- Quadro atual: jogador + oponentes validos.
function Spot.frame()
  local player = readCar(safe(function() return ac.getCar and ac.getCar(0) end))
  local opponents = {}
  if player and player.lx then
    local seen = {}
    local iterator = safe(function() return ac.iterateCars and ac.iterateCars.ordered end)
    if iterator then
      pcall(function()
        for _, car in ac.iterateCars.ordered() do
          local r = readCar(car)
          if r and r.id and r.id ~= 0 and not seen[r.id] then
            seen[r.id] = true
            opponents[#opponents + 1] = r
          end
        end
      end)
    end
    if #opponents == 0 then
      local sim = safe(function() return ac.getSim and ac.getSim() end)
      local count = (sim and number(safe(function() return sim.carsCount end)) or 1)
      for i = 1, count - 1 do
        local r = readCar(safe(function() return ac.getCar(i) end))
        if r then
          r.id = r.id or i
          if not seen[r.id] then seen[r.id] = true; opponents[#opponents + 1] = r end
        end
      end
    end
  end
  return { player = player, opponents = opponents }
end

function Spot.newState()
  return { now = 0, tick = 0, left = 0, right = 0, prevL = 0, prevR = 0,
    pending = nil, holdAt = nil, active = false, nearby = 0,
    observed = 'clear', lastCall = '' }
end

local function closing(player, o, maxClosing)
  return math.abs(o.vx - player.vx) < maxClosing and math.abs(o.vz - player.vz) < maxClosing
end

local function countSide(frame, st, o)
  local left, right, nearby = 0, 0, 0
  local p = frame.player
  local latRange = math.max(o.carWidth, o.latRange)
  for _, opp in ipairs(frame.opponents) do
    if not opp.inPit and math.abs((opp.y or 0) - (p.y or 0)) <= o.vertRange then
      local dx, dz = opp.x - p.x, opp.z - p.z
      -- Base lateral (sinal validado): x<0 = direita, x>=0 = esquerda.
      local rx, rz = p.lz, -p.lx
      local x = dx * rx + dz * rz
      local z = -(dx * p.lx + dz * p.lz)
      if math.abs(x) <= o.zone and math.abs(z) <= o.zone then
        nearby = nearby + 1
        local side
        if math.abs(x) > latRange then
          -- Perto mas nao ao lado: so conta diagnostico.
        elseif x < 0 then
          if st.prevR > 0 then
            if math.abs(z) < o.carLen + o.clearGap then side = 'right' end
          elseif ((z <= 0 and -z < o.carLen) or (z > 0 and z < o.carLen + 0.4))
              and math.abs(x) > o.carWidth and closing(p, opp, o.maxClosing) then
            side = 'right'
          end
        else
          if st.prevL > 0 then
            if math.abs(z) < o.carLen + o.clearGap then side = 'left' end
          elseif ((z <= 0 and -z < o.carLen) or (z > 0 and z < o.carLen + 0.4))
              and math.abs(x) > o.carWidth and closing(p, opp, o.maxClosing) then
            side = 'left'
          end
        end
        if side == 'left' then left = left + 1
        elseif side == 'right' then right = right + 1 end
      end
    end
  end
  return left, right, nearby
end

local function stillValid(line, left, right)
  if line == 'car_left' then return left > 0 and right == 0 end
  if line == 'car_right' then return right > 0 and left == 0 end
  if line == 'three_wide' then return left > 0 and right > 0 end
  if line == 'three_wide_on_left' then return right > 1 and left == 0 end
  if line == 'three_wide_on_right' then return left > 1 and right == 0 end
  if line == 'clear_left' then return left == 0 end
  if line == 'clear_right' then return right == 0 end
  if line == 'all_clear' then return left == 0 and right == 0 end
  return left > 0 or right > 0
end

local function onChange(st, o)
  local l, r, pl, pr = st.left, st.right, st.prevL, st.prevR
  if l == pl and r == pr then return end
  st.pending = nil
  local function later(line, delay) st.pending = { line = line, due = st.now + (delay or 0) } end
  if l == 0 and r == 0 and pl > 0 and pr > 0 then later('all_clear', o.clearDelay)
  elseif l == 0 and pl > 0 and ((r == 0 and pr == 0) or (r > 0 and pr > 0)) then later('clear_left', o.clearDelay)
  elseif r == 0 and pr > 0 and ((l == 0 and pl == 0) or (l > 0 and pl > 0)) then later('clear_right', o.clearDelay)
  elseif l > 0 and r > 0 and (pl == 0 or pr == 0) then later('three_wide', (pl > 0 and pr > 0) and o.holdRepeat / 2 or 0)
  elseif l > 0 and r == 0 and pl == 0 and pr == 0 then later(l > 1 and 'three_wide_on_right' or 'car_left', 0)
  elseif r > 0 and l == 0 and pl == 0 and pr == 0 then later(r > 1 and 'three_wide_on_left' or 'car_right', 0)
  elseif l > 1 and r == 0 and pl == 1 and pr == 0 then later('three_wide_on_right', 0.5)
  elseif r > 1 and l == 0 and pr == 1 and pl == 0 then later('three_wide_on_left', 0.5)
  elseif l == 1 and pl > 1 and r == 0 then later('car_left', 0)
  elseif r == 1 and pr > 1 and l == 0 then later('car_right', 0) end
end

-- Roda a cada frame. announce(line) fala e retorna false para vetar.
function Spot.update(st, dt, frame, o, announce)
  st.now = st.now + dt
  st.tick = st.tick + dt
  if st.tick < 0.05 then return end
  st.tick = 0
  local p = frame and frame.player
  st.active = frame ~= nil and p ~= nil and p.lx ~= nil and o.enabled
    and not p.inPit and p.speed >= o.minSpeed and st.now >= o.warmup
  if not st.active then
    st.left, st.right, st.prevL, st.prevR = 0, 0, 0, 0
    st.nearby, st.observed, st.pending, st.holdAt = 0, 'clear', nil, nil
    return
  end
  st.prevL, st.prevR = st.left, st.right
  st.left, st.right, st.nearby = countSide(frame, st, o)
  st.observed = st.left > 0 and (st.right > 0 and 'both' or 'left')
    or (st.right > 0 and 'right' or 'clear')
  onChange(st, o)
  if st.pending and st.now >= st.pending.due then
    local line = st.pending.line
    st.pending = nil
    if stillValid(line, st.left, st.right) and announce(line) ~= false then
      st.lastCall = line
      st.holdAt = (st.left > 0 or st.right > 0) and (st.now + o.holdRepeat) or nil
    end
  elseif not st.pending and st.holdAt and st.now >= st.holdAt and (st.left > 0 or st.right > 0) then
    if announce('still_there') ~= false then st.lastCall = 'still_there' end
    st.holdAt = st.now + o.holdRepeat
  end
end

function Spot.defaults()
  return { enabled = true, minSpeed = 36, carLen = 4.5, carWidth = 1.8,
    clearGap = 0.5, maxClosing = 12, clearDelay = 0.15, holdRepeat = 3,
    latRange = 8, vertRange = 4, zone = 20, warmup = 5 }
end

return Spot
