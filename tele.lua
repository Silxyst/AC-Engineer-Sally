-- Leitura segura da telemetria (carro 0 + sim). Tudo com pcall/tonumber:
-- nunca quebra o app se um campo nao existir.

local Tele = {}

local function safe(fn)
  local ok, value = pcall(fn)
  if ok then return value end
  return nil
end

local function number(v)
  local n = tonumber(v)
  if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
  return n
end

local function wheelTemp(wheels, i)
  local w = wheels and wheels[i]
  if not w then return nil end
  local core = number(safe(function() return w.tyreCoreTemperature end))
  if core and core <= 0 then core = nil end
  local sum, count = 0, 0
  for _, key in ipairs({ 'tyreInsideTemperature', 'tyreMiddleTemperature', 'tyreOutsideTemperature' }) do
    local v = number(safe(function() return w[key] end))
    if v and v > 0 then sum, count = sum + v, count + 1 end
  end
  local surface = count > 0 and sum / count or nil
  local bulk = core and surface and core * 0.75 + surface * 0.25 or core or surface
  local psi = number(safe(function() return w.tyrePressure end))
  if psi and psi <= 0 then psi = nil end
  if not bulk then return nil end
  local inner, outer
  for _, spec in ipairs({ { 'tyreInsideTemperature', 'inner' }, { 'tyreOutsideTemperature', 'outer' } }) do
    local v = number(safe(function() return w[spec[1]] end))
    if v and v > 0 then
      if spec[2] == 'inner' then inner = v else outer = v end
    end
  end
  local wear = number(safe(function() return w.tyreWear end))
  if wear and (wear < 0 or wear > 1) then wear = nil end
  local vkm = number(safe(function() return w.tyreVirtualKM end))
  if vkm and vkm < 0 then vkm = nil end
  local brake = number(safe(function() return w.brakeTemperature end))
  if brake and brake <= 0 then brake = nil end
  local optimum = number(safe(function() return w.tyreOptimumTemperature end))
  if optimum and (optimum < 40 or optimum > 140) then optimum = nil end
  local staticP = number(safe(function() return w.tyreStaticPressure end))
  if staticP and staticP <= 0 then staticP = nil end
  local blown = safe(function() return w.isBlown end) == true
  return { temp = bulk, psi = psi, inner = inner, outer = outer,
    wear = wear, vkm = vkm, brake = brake, optimum = optimum,
    staticP = staticP, blown = blown }
end

-- Le splits (setores) com base 1 ou 0; retorna {segundos x3} validado ou nil.
local function readSplits(car, key, refMs)
  local arr = safe(function() return car[key] end)
  if type(arr) ~= 'table' and type(arr) ~= 'userdata' then return nil end
  for _, base in ipairs({ 1, 0 }) do
    local probe = number(safe(function() return arr[base] end))
    if probe and probe > 0 then
      local vals = {}
      for i = 0, 2 do
        local v = number(safe(function() return arr[base + i] end))
        if not v or v <= 0 then break end
        vals[#vals + 1] = v / 1000
      end
      if #vals == 3 then
        local sum = vals[1] + vals[2] + vals[3]
        -- Segmentos somam ~= volta; cumulativos terminam ~= volta.
        if refMs and refMs > 30000 then
          if math.abs(sum - refMs / 1000) < 8 then return vals end
          local last = vals[3]
          if math.abs(last - refMs / 1000) < 8 then
            local d2, d3 = vals[2] - vals[1], vals[3] - vals[2]
            if d2 > 0 and d3 > 0 then return { vals[1], d2, d3 } end
          end
          return nil
        end
        return vals
      end
      return nil
    end
  end
  return nil
end

local function compoundClip(longName)
  local n = tostring(longName or ''):lower()
  if n == '' then return nil end
  if n:find('super', 1, true) then return 'super_softs' end
  if n:find('ultra', 1, true) then return 'ultra_softs' end
  if n:find('inter', 1, true) then return 'intermediates' end
  if n:find('wet', 1, true) or n:find('rain', 1, true) then return 'wets' end
  if n:find('medium', 1, true) then return 'mediums' end
  if n:find('hard', 1, true) then return 'hards' end
  if n:find('prime', 1, true) then return 'primes' end
  if n:find('option', 1, true) then return 'options' end
  if n:find('soft', 1, true) then return 'softs' end
  return nil
end

-- Retorna snapshot ou nil (sem carro/sim).
function Tele.snap()
  local car = safe(function() return ac.getCar and ac.getCar(0) end)
  local sim = safe(function() return ac.getSim and ac.getSim() end)
  if not car or not sim then return nil end
  local wheels = safe(function() return car.wheels end)
  local S = {}
  S.fuel = number(safe(function() return car.fuel end))
  S.maxFuel = number(safe(function() return car.maxFuel end))
  S.fuelPerLap = number(safe(function() return car.fuelPerLap end))
  if S.fuelPerLap and S.fuelPerLap <= 0 then S.fuelPerLap = nil end
  S.pos = number(safe(function() return car.racePosition end))
  S.lap = number(safe(function() return car.lapCount end)) or 0
  S.speed = number(safe(function() return car.speedKmh end)) or 0
  S.rpm = number(safe(function() return car.rpm end))
  S.spline = number(safe(function() return car.splinePosition end))
  S.inPit = safe(function() return car.isInPitlane end) == true
  S.inStall = safe(function() return car.isInPit end) == true
  S.changingTyres = safe(function() return car.isChangingTyres end) == true
  S.repairing = safe(function() return car.isRepairing end) == true
  S.refueling = safe(function() return car.isRefueling end) == true
  S.pitRequested = safe(function() return car.isRequestingPitStop end) == true
  S.limiterOn = safe(function() return car.speedLimiterInAction end) == true
  S.limiterManual = safe(function() return car.manualPitsSpeedLimiterEnabled end) == true
  S.limiterForcedOff = safe(function() return car.isPitsSpeedLimiterForced end) == false
  S.pitLimit = number(safe(function() return car.speedLimiter end))
  if S.pitLimit and S.pitLimit <= 0 then S.pitLimit = nil end
  S.drs = nil
  if safe(function() return car.drsPresent end) == true then
    S.drs = { avail = safe(function() return car.drsAvailable end) == true,
      active = safe(function() return car.drsActive end) == true }
  end
  S.kersMax = number(safe(function() return car.kersMaxKJ end))
  if S.kersMax and S.kersMax > 0 then
    S.kersPct = number(safe(function() return car.kersCurrentKJ end))
    if S.kersPct then S.kersPct = math.max(0, math.min(100, S.kersPct / S.kersMax * 100)) end
  else
    S.kersMax = nil
  end
  S.p2p = number(safe(function() return car.p2pActivations end))
  S.susp = {}
  local susp = safe(function() return car.suspensionDamage end)
  if susp then
    for i = 0, 3 do S.susp[i + 1] = number(safe(function() return susp[i] end)) or 0 end
  end
  S.gearbox = number(safe(function() return car.gearboxDamage end))
  if S.gearbox and (S.gearbox < 0 or S.gearbox > 1) then S.gearbox = nil end
  S.compoundIdx = number(safe(function() return car.compoundIndex end))
  S.compoundName = safe(function()
    return car.tyresLongName and car:tyresLongName() or nil end)
  if type(S.compoundName) ~= 'string' or S.compoundName == '' then S.compoundName = nil end
  S.compound = compoundClip(S.compoundName)
  S.lapMs = number(safe(function() return car.lapTimeMs end))
  S.lastMs = number(safe(function() return car.lastLapMs end))
  S.bestMs = number(safe(function() return car.bestLapMs end))
  S.lastSplits = readSplits(car, 'lastSplits', S.lastMs)
  S.bestSplits = readSplits(car, 'bestSplits', S.bestMs)
  S.steer = number(safe(function() return car.steer end)) or 0
  S.brake = number(safe(function() return car.brake end)) or 0
  S.latG = 0
  local acc = safe(function() return car.acceleration end)
  if acc then
    S.latG = number(safe(function() return acc.x end)) or 0
    S.longG = number(safe(function() return acc.z end)) or 0
  end
  S.dmg = {}
  S.dmgTotal = 0
  local dmg = safe(function() return car.damage end)
  if dmg then
    for i = 0, 3 do
      local d = number(safe(function() return dmg[i] end)) or 0
      S.dmg[i + 1] = d
      S.dmgTotal = S.dmgTotal + d
    end
  end
  S.engLife = number(safe(function() return car.engineLifeLeft end))
  S.oilC = number(safe(function() return car.oilTemperature end))
  if S.oilC and S.oilC <= 0 then S.oilC = nil end
  S.waterC = number(safe(function() return car.waterTemperature end))
  if S.waterC and S.waterC <= 0 then S.waterC = nil end
  S.lapValid = safe(function() return car.isLapValid end)
  if S.lapValid ~= true and S.lapValid ~= false then S.lapValid = nil end
  S.lastValid = safe(function() return car.isLastLapValid end)
  if S.lastValid ~= true and S.lastValid ~= false then S.lastValid = nil end
  S.cuts = number(safe(function() return car.lapCutsCount end))
  S.cutsLast = number(safe(function() return car.lastLapCutsCount end))
  S.wheelsOut = number(safe(function() return car.wheelsOutside end))
  S.collidedWith = number(safe(function() return car.collidedWith end))
  S.collisionDepth = number(safe(function() return car.collisionDepth end))
  S.penaltyType = number(safe(function() return car.currentPenaltyType end))
  S.penaltyParameter = number(safe(function() return car.currentPenaltyParameter end))
  S.prevSectorMs = number(safe(function() return car.previousSectorTime end))
  if S.prevSectorMs and S.prevSectorMs <= 0 then S.prevSectorMs = nil end
  S.sector = number(safe(function() return car.currentSector end))
  if S.sector then S.sector = math.floor(S.sector) end
  S.wheels = {}
  for i = 0, 3 do S.wheels[i + 1] = wheelTemp(wheels, i) end
  S.airC = number(safe(function() return sim.ambientTemperature end))
    or number(safe(function() return sim.airTemperature end))
  S.trackC = number(safe(function() return sim.roadTemperature end))
    or number(safe(function() return sim.trackTemperature end))
  S.rain = number(safe(function() return sim.rainIntensity end))
  if S.rain and (S.rain < 0 or S.rain > 1) then S.rain = nil end
  S.wind = number(safe(function() return sim.windSpeedKmh end))
  S.flag = safe(function() return sim.raceFlagType end)
  S.sessType = number(safe(function() return sim.raceSessionType end))
    or number(safe(function() return sim.sessionType end))
  S.started = safe(function() return sim.isSessionStarted end) == true
  S.finished = safe(function() return sim.isSessionFinished end) == true
  S.replay = safe(function() return sim.isReplayActive end) == true
  S.paused = safe(function() return sim.isPaused end) == true
  S.timeLeftS = number(safe(function() return sim.sessionTimeLeft end))
  if S.timeLeftS then S.timeLeftS = S.timeLeftS / 1000 end
  S.carsCount = number(safe(function() return sim.carsCount end)) or 1
  S.trackLen = number(safe(function() return sim.trackLengthM end))
    or number(safe(function() return sim.trackLength end)) or 5000
  S.sessIdx = number(safe(function() return sim.currentSessionIndex end)) or 0
  S.totalLaps, S.timed, S.sessMinutes = nil, false, nil
  local sessions = safe(function() return sim.sessions end)
  local session = sessions and sessions[S.sessIdx]
  if session then
    local laps = number(safe(function() return session.laps end))
    if laps and laps > 0 then S.totalLaps = math.floor(laps) end
    S.timed = safe(function() return session.isTimedRace end) == true
    S.sessMinutes = number(safe(function() return session.durationMinutes end))
  end
  if safe(function() return sim.isTimedRace end) == true then S.timed = true end
  return S
end

function Tele.isRace(S) return S ~= nil and S.sessType == 3 end

function Tele.token(S)
  if not S then return 'none' end
  return tostring(S.sessType) .. '|' .. tostring(S.sessIdx) .. '|' .. tostring(S.totalLaps)
    .. '|' .. tostring(S.timed)
end

-- Gap em segundos para uma posicao alvo (ex. lider = 1). Retorna seg, metros.
function Tele.gapTo(target)
  local sim = safe(function() return ac.getSim and ac.getSim() end)
  local car = safe(function() return ac.getCar and ac.getCar(0) end)
  if not sim or not car or not target or target < 1 then return nil end
  local speed = number(safe(function() return car.speedKmh end))
  if not speed or speed < 10 then return nil end
  local mySp = number(safe(function() return car.splinePosition end))
  if not mySp then return nil end
  for i = 0, (number(safe(function() return sim.carsCount end)) or 0) - 1 do
    local c = safe(function() return ac.getCar(i) end)
    if c and number(safe(function() return c.racePosition end)) == target then
      local ahSp = number(safe(function() return c.splinePosition end))
      if not ahSp then return nil end
      local frac = ahSp - mySp
      if frac < 0 then frac = frac + 1 end
      if frac > 0.5 or frac <= 0 then return nil end
      local trackLen = number(safe(function() return sim.trackLengthM end)) or 5000
      local meters = frac * trackLen
      return meters / (speed / 3.6), meters
    end
  end
  return nil
end

-- Gap em segundos para o carro da frente (posicao - 1). Retorna seg, metros.
function Tele.gapAhead()
  local sim = safe(function() return ac.getSim and ac.getSim() end)
  local car = safe(function() return ac.getCar and ac.getCar(0) end)
  if not sim or not car then return nil end
  local pos = number(safe(function() return car.racePosition end))
  if not pos or pos < 2 then return nil end
  local speed = number(safe(function() return car.speedKmh end))
  if not speed or speed < 10 then return nil end
  local mySp = number(safe(function() return car.splinePosition end))
  if not mySp then return nil end
  local target = pos - 1
  for i = 0, (number(safe(function() return sim.carsCount end)) or 0) - 1 do
    local c = safe(function() return ac.getCar(i) end)
    if c and number(safe(function() return c.racePosition end)) == target then
      local ahSp = number(safe(function() return c.splinePosition end))
      if not ahSp then return nil end
      local frac = ahSp - mySp
      if frac < 0 then frac = frac + 1 end
      if frac > 0.5 or frac <= 0 then return nil end
      local trackLen = number(safe(function() return sim.trackLengthM end)) or 5000
      local meters = frac * trackLen
      local oSpeed = number(safe(function() return c.speedKmh end))
      local oPit = safe(function() return c.isInPitlane end) == true
      return meters / (speed / 3.6), meters, oSpeed, oPit
    end
  end
  return nil
end

-- Gap para o carro de tras (posicao + 1), na velocidade dele.
function Tele.gapBehind()
  local sim = safe(function() return ac.getSim and ac.getSim() end)
  local car = safe(function() return ac.getCar and ac.getCar(0) end)
  if not sim or not car then return nil end
  local pos = number(safe(function() return car.racePosition end))
  if not pos then return nil end
  local mySp = number(safe(function() return car.splinePosition end))
  if not mySp then return nil end
  local target = pos + 1
  for i = 0, (number(safe(function() return sim.carsCount end)) or 0) - 1 do
    local c = safe(function() return ac.getCar(i) end)
    if c and number(safe(function() return c.racePosition end)) == target then
      local bSpeed = number(safe(function() return c.speedKmh end))
      if not bSpeed or bSpeed < 10 then return nil end
      local bhSp = number(safe(function() return c.splinePosition end))
      if not bhSp then return nil end
      local frac = mySp - bhSp
      if frac < 0 then frac = frac + 1 end
      if frac > 0.5 or frac <= 0 then return nil end
      local trackLen = number(safe(function() return sim.trackLengthM end)) or 5000
      local meters = frac * trackLen
      return meters / (bSpeed / 3.6), meters
    end
  end
  return nil
end

-- Reta tranquila para mensagens secundarias (fora de curva/frenagem).
function Tele.isCalm(S)
  if not S then return false end
  return math.abs(S.latG or 0) < 0.55 and (S.brake or 0) < 0.35 and math.abs(S.steer or 0) < 60
end

return Tele
