-- Estrategia e aprendizado: consumo por volta, autonomia, voltas restantes,
-- ritmo e setores medios. Tudo derivado da telemetria ao vivo.

local Strat = {}
Strat.__index = Strat

function Strat.new(reserve)
  local self = setmetatable({}, Strat)
  self:reset(reserve or 1.0)
  return self
end

function Strat.fresh()
  return { fuel = nil, perLap = nil, samples = 0, samplesList = {},
    range = nil, remaining = nil, totalLaps = nil, timed = false,
    finished = false, need = nil, margin = nil,
    laps = {}, paceMs = nil, paceTrendMs = nil, paceN = 0,
    secAvg = { nil, nil, nil }, secBest = { nil, nil, nil },
    secBuf = { {}, {}, {} }, lastMs = nil, bestMs = nil,
    stintStartLap = nil, stintLaps = 0,
    available = false }
end

function Strat:reset(reserve)
  if reserve then self.reserve = reserve end
  self.state = Strat.fresh()
  self._lap = nil
  self._secIdx = 0
  self._secLap = nil
  self._secClock = 0
  self._prevSpline = nil
  self._secTimes = {}
end

function Strat:pitExit(lap)
  self.state.stintStartLap = lap or 0
end

local function pushCapped(list, value, max)
  list[#list + 1] = value
  while #list > max do table.remove(list, 1) end
end

local function average(list)
  if #list == 0 then return nil end
  local sum = 0
  for _, v in ipairs(list) do sum = sum + v end
  return sum / #list
end

-- Chamado quando o contador de voltas muda (volta fechada).
-- IMPORTANTE: chamar closeLap ANTES de trackSectors no frame da virada.
function Strat:closeLap(S)
  local st = self.state
  local lap = S.lap or 0
  local prev = self._lap
  self._lap = { lap = lap, fuel = S.fuel, t = S.lapMs }
  if not prev then return end
  if lap <= prev.lap then return end -- volta para tras/restart: ignora
  -- Fecha o setor 3 (tempo desde a marca de 2/3).
  if self._secIdx == 2 and self._secClock and self._secClock > 5 and self._secClock < 300 then
    self._secTimes[3] = self._secClock
  end
  if S.inPit then return end
  local used = prev.fuel and S.fuel and (prev.fuel - S.fuel) or nil
  -- Combustivel e ritmo sao independentes: sem consumo ainda ha volta valida.
  if used and used > 0.02 and used < 35 then
    pushCapped(st.samplesList, used, 5)
    st.samples = #st.samplesList
    st.perLap = average(st.samplesList)
  end
  local lapMs = S.lastMs
  if lapMs and lapMs > 30000 and lapMs < 1200000 then
    pushCapped(st.laps, { timeMs = lapMs, fuelUsedL = used }, 12)
    -- Ritmo: media recente.
    local times = {}
    for _, l in ipairs(st.laps) do times[#times + 1] = l.timeMs end
    -- Total de voltas validas, independente da janela de 12 voltas.
    st.paceN = st.paceN + 1
    if #times >= 2 then
      st.paceMs = average(times)
      if #times >= 4 then
        local n, half = #times, math.floor(#times / 2)
        local a, b = 0, 0
        for i = 1, half do a = a + times[i] end
        for i = half + 1, #times do b = b + times[i] end
        st.paceTrendMs = (b / (#times - half)) - (a / half)
      end
    end
    if not st.bestMs or lapMs < st.bestMs then st.bestMs = lapMs end
    st.lastMs = lapMs
  end
  -- Setores da volta fechada: prefere os splits reais do jogo
  -- (S.lastSplits); senao usa o rastreador de spline.
  local sec = self._secTimes
  if S.inPit then sec = {} end
  if (not (sec[1] and sec[2] and sec[3])) and S.lastSplits then sec = S.lastSplits end
  st.lastPurple = nil
  st.purpleLap = nil
  if sec[1] and sec[2] and sec[3] then
    local lapMs = S.lastMs
    local sumOk = true
    if lapMs and lapMs > 30000 then
      sumOk = math.abs((sec[1] + sec[2] + sec[3]) - lapMs / 1000) < 8
    end
    if sumOk then
      for i = 1, 3 do
        if S.bestSplits and S.bestSplits[i] and (not st.secBest[i] or S.bestSplits[i] < st.secBest[i]) then
          st.secBest[i] = S.bestSplits[i]
        end
        if st.secBest[i] and sec[i] < st.secBest[i] - 0.01 then
          st.lastPurple = i
          st.purpleLap = prev and prev.lap or nil
        end
        pushCapped(st.secBuf[i], sec[i], 5)
        st.secAvg[i] = average(st.secBuf[i])
        local best
        for _, v in ipairs(st.secBuf[i]) do best = math.min(best or v, v) end
        if st.secBest[i] then best = math.min(best, st.secBest[i]) end
        st.secBest[i] = best
      end
    end
  end
end

-- Rastreador simples de setores: cruza 1/3 e 2/3 da spline; o setor 3
-- fecha na virada (ver closeLap). Chamar DEPOIS de closeLap.
function Strat:trackSectors(dt, S)
  if not S or not S.spline then return end
  local lap = S.lap or 0
  if (self._secLap or lap) ~= lap then
    self._secLap, self._secIdx, self._secClock, self._secTimes = lap, 0, 0, {}
    self._prevSpline = S.spline
    return
  end
  self._secLap = lap
  local prev = self._prevSpline
  self._prevSpline = S.spline
  if not prev then self._secClock = 0; return end
  self._secClock = (self._secClock or 0) + dt
  for i, mark in ipairs({ 1 / 3, 2 / 3 }) do
    if prev < mark and S.spline >= mark and (S.spline - prev) < 0.5
        and (self._secIdx or 0) == i - 1 then
      self._secTimes[i] = self._secClock
      self._secIdx = i
      self._secClock = 0
    end
  end
end

function Strat:update(S)
  local st = self.state
  if not S or not S.started then
    st.available = false
    return st
  end
  st.available = true
  -- On a live reload the tyre age is unknowable; count only from app startup
  -- instead of incorrectly presenting laps since race start as the tyre stint.
  if st.stintStartLap == nil then st.stintStartLap = S.lap or 0 end
  -- Guarda o combustivel da volta atual para poder medir ja a primeira
  -- volta fechada depois que o app inicia.
  if not self._lap then
    self._lap = { lap = S.lap or 0, fuel = S.fuel, t = S.lapMs }
  end
  if S.fuel then st.fuel = S.fuel end
  if st.samples == 0 and S.fuelPerLap then st.perLap = S.fuelPerLap end
  st.totalLaps = S.totalLaps
  st.timed = S.timed == true
  st.finished = S.finished == true
  st.stintLaps = math.max(0, (S.lap or 0) - st.stintStartLap)
  if S.lastMs then st.lastMs = S.lastMs end
  if S.bestMs and (not st.bestMs or S.bestMs < st.bestMs) then st.bestMs = S.bestMs end
  -- Autonomia e conta de chegada.
  if st.fuel and st.perLap and st.perLap > 0 then
    st.range = st.fuel / st.perLap
  else
    st.range = nil
  end
  st.remaining, st.need, st.margin = nil, nil, nil
  if st.totalLaps and st.totalLaps > 0 then
    st.remaining = math.max(0, st.totalLaps - (S.lap or 0))
  elseif st.timed and st.paceMs and st.paceMs > 0 and S.timeLeftS and S.timeLeftS > 0 then
    st.remaining = math.max(0, S.timeLeftS * 1000 / st.paceMs + 1)
  end
  if st.finished then st.remaining = 0 end
  if st.remaining and st.perLap then
    local target = (st.remaining + (self.reserve or 1)) * st.perLap
    st.need = math.max(0, target - (st.fuel or 0))
    st.margin = (st.fuel or 0) - target
  end
  return st
end

return Strat
