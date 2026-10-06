-- Avisos automaticos com cooldowns. Tudo Sally, tudo com telemetria real.
-- api: {say(cat,phrase,cap,opts), num(v), started(reportId), done(), now}

local Warn = {}
Warn.__index = Warn

function Warn.new()
  local self = setmetatable({}, Warn)
  self:reset()
  return self
end

function Warn:reset()
  self.cd, self.once = {}, {}
  self._maxFuel, self._coldSince, self._yellowLap = nil, nil, nil
  self._pushSince, self._base, self._prevDmg = nil, nil, nil
  self._lastPos, self._lossCount = nil, 0
  self._spinSince, self._psiBase, self._wasInPit = nil, nil, nil
  self._engBase, self._wasHot, self._blankets = nil, nil, nil
  self._briefSeen, self._pendingBrief = 0, nil
  self._penaltyType, self._penaltySince = nil, nil
  self._penaltyActive, self._pitWaitPending = false, false
  self._nextFuelStatus, self._pendingRant = nil, nil
  self._t0, self._gridPos, self._wasBattle = nil, nil, false
  self._spins, self._gapT, self._gapPrevA, self._gapPrevB = 0, 0, nil, nil
  self._hadYellow, self._pitEnterT = nil, nil
  self._oppT, self._oppPit, self._pressSince = 0, nil, nil
  self.lapdiffahead, self.lapdiffbehind, self._lastBlueT = nil, nil, nil
  self._rainT, self._rainCand, self._rainCandN, self._rainBand = 0, nil, 0, nil
  self._lastBriefAt = nil
  self._tempT, self._tempBase = 0, nil
  self._drsWas, self._drsIdle, self._compound = nil, nil, nil
  self._pitReq, self._p2p = nil, nil
  self._pitServiceStarted, self._pitServiceClearSince = false, nil
  self._pitServiceCompleteCalled, self._pitStopRequested = false, false
  self._lastLapKey, self._lastCutsKey = nil, nil
  self._nextTyreReportAt = nil
  self._lowBattLatched = false
  self._criticalBattLatched = false
  self._slowCarState, self._slowCarClearSince = nil, nil
end

local function ready(self, id, seconds, now)
  if (self.cd[id] or -1e9) + seconds > now then return false end
  self.cd[id] = now
  return true
end

local function once(self, id)
  if self.once[id] then return false end
  self.once[id] = true
  return true
end

-- Evita que pressao, camber, temperatura e desgaste gerem uma sequencia de
-- radios no mesmo ciclo. Alertas urgentes podem furar a janela compartilhada.
local function tyreReady(self, id, seconds, now, urgent)
  if not urgent and (self._nextTyreReportAt or -1e9) > now then return false end
  if not ready(self, id, seconds, now) then return false end
  self._nextTyreReportAt = math.max(self._nextTyreReportAt or -1e9,
    now + (urgent and 10 or 45))
  return true
end

local RANT_TAKES = {
  collision = { '9', '17', '27', '28' },
  penalty = { '18', '26', '27', '28' },
  loss = { '17', '18', '19', '24', '26', '27', '29' },
  spin = { '9', '18', '24', '27', '28' },
}
local function planRant(self, kind, C, now)
  local level = math.max(0, math.min(3, math.floor(tonumber(C.rantLevel) or 0)))
  if level == 0 then return end
  local cooldown = level == 3 and 45 or (level == 2 and 90 or 180)
  if ready(self, 'rant', cooldown, now) then
    self._pendingRant = { kind = kind, at = now }
  end
end

local HOT_WHEEL = { 'cooking_left_front_tyre', 'cooking_right_front_tyre',
  'cooking_left_rear_tyre', 'cooking_right_rear_tyre' }
local MILD_HOT_WHEEL = { 'hot_left_front_tyre', 'hot_right_front_tyre',
  'hot_left_rear_tyre', 'hot_right_rear_tyre' }
local PRESS_WHEEL = { 'left_front', 'right_front', 'left_rear', 'right_rear' }

-- Faixas de temperatura: manta detectada no inicio, senao 70/95.
local function thresholds(self, S, C)
  if C.tyHot and C.tyHot > 0 and C.tyCold and C.tyCold > 0 and C.tyHot > C.tyCold then
    return C.tyCold, C.tyHot
  end
  if not self._base and S.wheels[1] and S.wheels[2] and S.wheels[3] and S.wheels[4] then
    local sum, lo, hi = 0, 1e9, -1e9
    for i = 1, 4 do
      local t = S.wheels[i].temp
      sum, lo, hi = sum + t, math.min(lo, t), math.max(hi, t)
    end
    local avg = sum / 4
    local ambient = S.airC or 20
    self._blankets = avg >= math.max(35, ambient + 10) and (hi - lo) <= 12
    self._base = avg
  end
  if self._blankets and self._base then return self._base - 18, self._base + 18 end
  return 70, 95
end

function Warn:update(dt, S, G, api, C, now, gaps, calm, nearby, overlap)
  if not S or not S.started or S.replay then return end
  gaps = gaps or {}

  -- Inicio / fim de sessao (radio check primeiro, depois a chamada).
  if once(self, 'start') then
    api.started('auto_start')
    api.say('radio_check', 'test', 'Radio check', {})
    if S.sessType == 3 then api.say('lap_counter', 'green_green_green', 'Largada!', { noBeep = true })
    else api.say('lap_counter', 'get_ready', 'Prepare-se', { noBeep = true }) end
    api.done()
  end
  -- O numero nos WAVs representa uma variacao da fala, nao a colocacao.
  -- So anuncia resultado quando a sessao encerrada for uma corrida.
  if S.finished and S.sessType == 3 and once(self, 'finish') then
    api.started('auto_finish', 70)
    local pos = tonumber(S.pos)
    local fieldSize = tonumber(S.carsCount)
    if pos then pos = math.floor(pos) end
    if fieldSize then fieldSize = math.floor(fieldSize) end

    local phrase, caption = 'finished_race', 'Fim de corrida'
    if pos and pos >= 1 then
      if pos == 1 then
        phrase, caption = 'won_race', 'Vitória! Primeiro lugar.'
      elseif pos <= 3 then
        phrase = 'podium_finish'
        caption = pos == 2 and 'P2! Pódio.' or 'P3! Pódio.'
      elseif fieldSize and fieldSize > 1 and pos == fieldSize then
        phrase, caption = 'finished_race_last', 'Último lugar. Vamos recuperar.'
      elseif fieldSize and fieldSize > 1 and pos <= math.ceil(fieldSize / 2) then
        phrase, caption = 'finished_race_good_finish', 'Boa chegada!'
      end
    end
    local finishOptions = { priority = true }
    if phrase == 'podium_finish' then
      finishOptions.takes = {
        '1_op_suffix_well_done', '2_op_suffix_well_done', '3_op_prefix_well_done',
      }
    end
    api.say('lap_counter', phrase, caption, finishOptions)
    if G.bestMs and G.bestMs > 0 then
      api.say('lap_times', 'personal_best', 'Sua melhor', { noBeep = true })
      local total = G.bestMs / 1000
      local m = math.floor(total / 60)
      if m > 0 then api.num(m) end
      api.num(string.format('%.1f', total % 60))
      api.say('timings', 'seconds', 'segundos', { noBeep = true })
    end
    api.done()
  end
  if S.finished and S.sessType and S.sessType ~= 3 and once(self, 'session_end') then
    api.started('auto_session_end', 70)
    api.say('lap_counter', 'end_of_session', 'Sessão concluída', { priority = true })
    api.done()
  end
  -- O sinal de fim pode durar so um frame; a trava do evento evita avisos de
  -- estrategia (por exemplo, push e DRS) durante a volta de retorno.
  if S.finished or self.once.finish then return end

  -- Bandeiras.
  if C.warnFlags and ac and ac.FlagType then
    local flag = S.flag
    if flag == ac.FlagType.Caution then
      if S.lap ~= self._yellowLap then
        self._yellowLap = S.lap
        api.started('auto_flag')
        api.say('flags', 'local_yellow_ahead', 'Bandeira amarela', { priority = true })
        api.done()
      end
    elseif flag == ac.FlagType.FasterCar then
      if ready(self, 'blue', 45, now) then
        self._lastBlueT = now
        api.started('auto_flag')
        api.say('flags', 'blue_flag', 'Bandeira azul', { priority = true })
        api.done()
      end
    elseif flag == ac.FlagType.Stop and S.penaltyType ~= 4 then
      if ready(self, 'black', 60, now) then
        api.started('auto_flag')
        api.say('flags', 'black_flag', 'Bandeira preta', { priority = true })
        api.done()
      end
    elseif flag == ac.FlagType.OneLapLeft then
      if once(self, 'onelap') then
        api.started('auto_flag')
        api.say('lap_counter', 'white_flag_last_lap', 'Última volta', { priority = true })
        api.done()
      end
    end
    -- Amarela liberada: confirma pista livre.
    if flag == ac.FlagType.Caution then
      self._hadYellow = true
    elseif self._hadYellow then
      self._hadYellow = nil
      if ready(self, 'yellclr', 30, now) then
        api.started('auto_flagclear')
        api.say('flags', 'local_yellow_clear', 'Pista livre', {})
        api.done()
      end
    end
  end

  -- O tipo de penalidade do CSP e autoritativo quando disponivel. A bandeira
  -- ReturnToPits nao identifica o tipo e serve apenas como fallback.
  local current, previous = S.penaltyType, self._penaltyType
  local nativeActive = current ~= nil and current > 0 and current ~= 5
  local returnToPits = S.returnToPits == true
  local returnToPitsOnly = returnToPits and not nativeActive
  local active = nativeActive or returnToPitsOnly
  local wasActive = self._penaltyActive == true
  local typeChanged = current ~= nil and current ~= previous
  if current ~= nil then self._penaltyType = current end

  if current == 2 then self._pitWaitPending = true end

  if active and (not wasActive or (nativeActive and typeChanged and previous
      and previous > 0 and previous ~= 5)) then
    self._penaltyActive = true
    self._penaltySince = now
    api.started('auto_penalty', 90)
    local param = S.penaltyParameter
    if not nativeActive then
      api.say('penalties', 'you_have_a_penalty', 'Retorne aos boxes para cumprir a penalidade', {})
    elseif current == 3 then
      api.say('penalties', 'new_penalty_slowdown', 'Penalidade: reduza', {})
      if param and param > 0 then
        api.num(param)
        api.say('timings', 'seconds', 'segundos', { noBeep = true })
      end
    elseif current == 4 then
      api.say('penalties', 'new_penalty_black_flag', 'Bandeira preta', {})
    elseif current == 2 then
      api.say('penalties', 'you_have_a_penalty', 'Aguarde nos boxes', {})
      if param and param > 0 then
        api.num(param)
        api.say('timings', 'seconds', 'segundos', { noBeep = true })
      end
    elseif current == 1 then
      api.say('penalties', 'you_have_a_penalty', 'Parada obrigatória', {})
      if param and param > 0 then
        api.num(param)
        api.say('race_time', 'laps_remaining', 'voltas', { noBeep = true })
      end
    else
      api.say('penalties', 'you_have_a_penalty', 'Voce tem penalidade', {})
    end
    api.done()
    if (C.rantLevel or 0) >= 2 or current == 4 then
      planRant(self, 'penalty', C, now)
    end
  elseif not active and wasActive then
    self._penaltyActive = false
    self._penaltySince = nil
    api.started('auto_penalty_served')
    if self._pitWaitPending then
      api.say('penalties', 'penalty_served', 'Penalidade cumprida', { priority = true })
      self._pitWaitPending = false
    else
      api.say('penalties', 'penalty_served', 'Penalidade cumprida', {})
    end
    api.done()
  else
    self._penaltyActive = active
  end

  if active and self._penaltySince
      and now - self._penaltySince > 75 and ready(self, 'penalty_reminder', 90, now) then
    api.started('auto_penalty_reminder')
    local pitWaitPending = nativeActive and current == 2
    if pitWaitPending then
      api.say('penalties', 'you_still_have_a_penalty', 'Aguarde nos boxes para cumprir a penalidade', {})
    elseif returnToPitsOnly then
      api.say('penalties', 'you_still_have_a_penalty', 'Retorne aos boxes para cumprir a penalidade', {})
    else
      api.say('penalties', 'you_still_have_a_penalty', 'Penalidade pendente', {})
    end
    api.done()
  end

  -- Combustivel.
  if C.warnFuel and G.available and G.fuel then
    local tank = S.maxFuel and S.maxFuel > 0 and S.maxFuel or G.fuel
    if not self._maxFuel or tank > self._maxFuel then self._maxFuel = tank end
    if self._maxFuel and self._maxFuel > 1 and G.fuel < self._maxFuel * 0.5 and once(self, 'half_fuel') then
      api.started('auto_fuel')
      api.say('fuel', 'half_tank_warning', 'Meio tanque', {})
      api.done()
    end
    if not S.inPit and (G.fuel < 0.5 or (G.range and G.range < 1.2)) then
      if ready(self, 'fuelcrit', 60, now) then
        api.started('auto_fuelcrit')
        api.say('fuel', 'about_to_run_out', 'Combustivel acabando', { priority = true })
        api.done()
      end
    elseif G.range and G.remaining and G.remaining > 0 then
      if G.range < G.remaining - 0.2 and ready(self, 'fuelneed', 120, now) then
        api.started('auto_fuel')
        api.say('fuel', 'we_will_need_to_pit_for_fuel', 'Vai faltar', {})
        if G.need and G.need > 0 then
          api.num(string.format('%.1f', G.need))
          api.say('fuel', 'litres_to_get_to_the_end', 'litros até o fim', { noBeep = true })
        end
        api.done()
      elseif G.range < G.remaining + (C.reserve or 1)
          and ready(self, 'fueltight', 180, now) then
        api.started('auto_fueltight')
        api.say('fuel', 'fuel_will_be_tight', 'Combustivel apertado', {})
        api.done()
      end
    end
  end

  -- Pneus.
  if C.warnTyres and S.wheels[1] then
    local cold, hot = thresholds(self, S, C)
    local hottest, hottestT, allCold = 1, -1e9, true
    for i = 1, 4 do
      local w = S.wheels[i]
      if w then
        if w.temp > hottestT then hottest, hottestT = i, w.temp end
        if w.temp >= cold then allCold = false end
      else allCold = false end
    end
    if allCold then
      self._coldSince = (self._coldSince or now)
      if now - self._coldSince > 10 and once(self, 'coldwarn') then
        local frontsCold = S.wheels[1] and S.wheels[2]
        local rearsCold = S.wheels[3] and S.wheels[4]
        api.started('auto_tyre')
        if frontsCold and not rearsCold then
          api.say('tyre_monitor', 'cold_front_tyres', 'Dianteiros frios', { priority = true })
        elseif rearsCold and not frontsCold then
          api.say('tyre_monitor', 'cold_rear_tyres', 'Traseiros frios', { priority = true })
        else
          api.say('tyre_monitor', 'cold_tyres_all_round', 'Pneus frios', { priority = true })
        end
        api.done()
        self._nextTyreReportAt = now + 45
      end
    else
      self._coldSince = nil
      if hottestT > hot then
        local severe = hottestT > hot + 8
        local band = (severe and 'cook' or 'mild') .. hottest
        if self._wasHot ~= band then
          self._wasHot = band
          if tyreReady(self, 'hot' .. band, 90, now, severe) then
            api.started('auto_tyre')
            local clip = severe and HOT_WHEEL[hottest] or MILD_HOT_WHEEL[hottest]
            api.say('tyre_monitor', clip, severe and 'Pneu pegando fogo' or 'Pneu quente', { priority = true })
            api.done()
          end
        end
      elseif hottestT < hot - 7 then
        self._wasHot = nil
      end
    end
  end

  -- Contato do CSP + variacao de dano. A pergunta sobre o piloto nao afirma
  -- dano quando a batida nao deixou avaria mensuravel.
  local biggest = 0
  if S.dmg then
    if self._prevDmg then
      for i = 1, 4 do
        biggest = math.max(biggest, (S.dmg[i] or 0) - (self._prevDmg[i] or 0))
      end
    else
      self._prevDmg = {}
    end
    for i = 1, 4 do self._prevDmg[i] = S.dmg[i] or 0 end
  end
  local hit = S.hit
  local damage = math.max(biggest, hit and hit.damageDelta or 0)
  local impact = hit and not S.inPit and ((hit.damageDelta or 0) >= 2
    or (hit.speedDrop or 0) >= 6 or (hit.impactSpeed or 0) >= 60)
  -- So pergunta pelo piloto apos uma colisao realmente grave. Velocidade alta
  -- sozinha nao indica batida: saltos e saidas de pista tambem geram contato.
  local askDriver = hit and not S.inPit and (
    damage >= 30
    or ((hit.speedDrop or 0) >= 55 and (hit.impactSpeed or 0) >= 90)
    or hit.engineLost == true)
  if C.warnDamage and (damage >= 7 or askDriver)
      and ready(self, damage >= 20 and 'dmg_severe' or 'dmg', damage >= 20 and 60 or 25, now) then
    api.started('auto_damage', 90)
    if askDriver then
      api.say('damage_reporting', 'are_you_ok_first_try', 'Voce esta bem?', {})
    end
    if damage >= 20 then
      api.say('damage_reporting', 'severe_aero_damage', 'Dano grave', { noBeep = true })
    elseif damage >= 15 then
      api.say('damage_reporting', 'minor_aero_damage', 'Dano leve', { noBeep = true })
    elseif damage >= 7 then
      api.say('damage_reporting', 'trivial_aero_damage_general', 'Só um toque', { noBeep = true })
    end
    api.done()
  end
  if impact and (damage >= 5 or (hit.speedDrop or 0) >= 10) then
    planRant(self, 'collision', C, now)
  end

  -- Transmissao/motor: queda de vida util desde a referencia.
  if S.engLife then
    if not self._engBase then self._engBase = S.engLife end
    if self._engBase - S.engLife > 150 then
      self._engBase = S.engLife
      if ready(self, 'transm', 300, now) then
        api.started('auto_transm')
        api.say('damage_reporting', 'minor_transmission_damage', 'Câmbio!', {})
        api.done()
      end
    end
    if S.engLife <= 0 and once(self, 'engdead') then
      api.started('auto_engdead')
      api.say('damage_reporting', 'busted_engine', 'Motor quebrou!', { priority = true })
      api.done()
    end
  end

  -- Volta invalidada + cortes (track limits).
  if S.lastMs and S.lastMs > 30000 then
    if S.lastValid == false and self._lastLapKey ~= (S.lap or 0) then
      self._lastLapKey = S.lap or 0
      if ready(self, 'invalid', 90, now) then
        api.started('auto_invalid')
        api.say('penalties', 'lap_deleted', 'Volta invalidada', {})
        api.done()
      end
    end
    if S.cutsLast and S.cutsLast > 0 and self._lastCutsKey ~= (S.lap or 0) then
      self._lastCutsKey = S.lap or 0
      local rpCoveredThisLap = self._lastRPCutAt and now - self._lastRPCutAt < 90
      if not rpCoveredThisLap and ready(self, 'cuts', 120, now) then
        api.started('auto_cuts')
        api.say('penalties', 'cut_track_race_1', 'Track limits', {})
        api.num(S.cutsLast)
        api.done()
      end
    end
  end
  if S.cuts and S.cuts >= 3 and (S.speed or 0) > 60 and ready(self, 'cutslive', 120, now) then
    api.started('auto_cutslive')
    api.say('penalties', 'cut_track_race_1', 'Corta!', {})
    api.done()
  end

  -- Desgaste dos pneus (0..1) + furo.
  do
    local worst, worstW, blown = 0, 0, false
    for i = 1, 4 do
      local w = S.wheels[i]
      if w then
        if w.blown then blown = true end
        if w.wear and w.wear > worstW then worstW, worst = w.wear, i end
      end
    end
    if blown and ready(self, 'blown', 120, now) then
      api.started('auto_blown')
      api.say('mandatory_pit_stops', 'pit_now', 'Pneu furado, box!', { priority = true })
      api.done()
    elseif worstW >= 0.9 and ready(self, 'wearcrit', 240, now) then
      api.started('auto_wear')
      api.say('tyre_monitor', 'knackered_all_round', 'Pneus gastos!', { priority = true })
      api.done()
    elseif worstW >= 0.7 and ready(self, 'wearhi', 240, now) then
      local names = { 'worn_left_front', 'worn_right_front', 'worn_left_rear', 'worn_right_rear' }
      api.started('auto_wear')
      api.say('tyre_monitor', names[worst] or 'worn_all_round', 'Desgaste', {})
      api.done()
    elseif worstW >= 0.5 and ready(self, 'wearmid', 300, now) then
      api.started('auto_wear')
      if worst == 1 or worst == 2 then
        api.say('tyre_monitor', 'minor_wear_fronts', 'Desgaste leve', {})
      elseif worst == 3 or worst == 4 then
        api.say('tyre_monitor', 'minor_wear_rears', 'Desgaste leve', {})
      else
        api.say('tyre_monitor', 'worn_all_round', 'Desgaste', {})
      end
      api.done()
    end
  end

  -- Oleo, agua e freios.
  if S.oilC and S.oilC > 150 and ready(self, 'hotoil', 240, now) then
    api.started('auto_oil')
    api.say('engine_monitor', 'hot_oil', 'Óleo quente', {})
    api.done()
  end
  if S.waterC and S.waterC > 125 and ready(self, 'hotwater', 240, now) then
    api.started('auto_water')
    api.say('engine_monitor', 'hot_water', 'Água quente', {})
    api.done()
  end
  do
    local fb, rb = 0, 0
    for i = 1, 4 do
      local w = S.wheels[i]
      if w and w.brake then
        if i <= 2 then fb = math.max(fb, w.brake) else rb = math.max(rb, w.brake) end
      end
    end
    local function brakeWarn(temp, pre, label)
      if temp > 950 and ready(self, 'brkcook' .. pre, 180, now) then
        api.started('auto_brake')
        api.say('tyre_monitor', 'cooking_' .. pre .. '_brakes', label, {})
        api.done()
      elseif temp > 800 and ready(self, 'brkhot' .. pre, 180, now) then
        api.started('auto_brake')
        api.say('tyre_monitor', 'hot_' .. pre .. '_brakes', label, {})
        api.done()
      end
    end
    if fb > 0 then brakeWarn(fb, 'front', 'Freios dianteiros') end
    if rb > 0 then brakeWarn(rb, 'rear', 'Freios traseiros') end
  end

  -- Suspensao por canto + cambio 0..1.
  do
    local worstS, worstG = 0, 0
    for i = 1, 4 do worstS = math.max(worstS, (S.susp and S.susp[i]) or 0) end
    if S.gearbox then worstG = S.gearbox end
    if worstS > 0.7 and ready(self, 'sevsusp', 180, now) then
      api.started('auto_susp')
      api.say('damage_reporting', 'severe_suspension_damage', 'Suspensão grave', { priority = true })
      api.done()
    elseif worstS > 0.35 and ready(self, 'minsusp', 180, now) then
      api.started('auto_susp')
      api.say('damage_reporting', 'minor_suspension_damage', 'Suspensão', {})
      api.done()
    end
    if worstG > 0.95 then
      if ready(self, 'bustrans', 300, now) then
        api.started('auto_trans2')
        api.say('damage_reporting', 'busted_transmission', 'Câmbio quebrou!', { priority = true })
        api.done()
      end
    elseif worstG > 0.5 and ready(self, 'mintrans', 300, now) then
      api.started('auto_trans2')
      api.say('damage_reporting', 'minor_transmission_damage', 'Câmbio!', {})
      api.done()
    end
  end

  -- Composto novo detectado.
  if S.compound then
    if self._compound and self._compound ~= S.compound then
      if ready(self, 'compound', 30, now) then
        api.started('auto_compound')
        api.say('tyre_monitor', S.compound, S.compound, {})
        api.done()
      end
    end
    self._compound = S.compound
  end

  -- DRS (so em carro com DRS).
  if S.drs then
    if S.drs.avail and not self._drsWas and ready(self, 'drs', 60, now) then
      api.started('auto_drs')
      api.say('overtaking_aids', 'drs_enabled', 'DRS!', {})
      api.done()
    elseif S.drs.avail and not S.drs.active then
      self._drsIdle = (self._drsIdle or now)
      if now - self._drsIdle > 20 and ready(self, 'drsrem', 120, now) then
        api.started('auto_drsrem')
        api.say('overtaking_aids', 'dont_forget_drs', 'DRS aberto?', {})
        api.done()
      end
    else
      self._drsIdle = nil
    end
    self._drsWas = S.drs.avail
  end

  -- Limitador esquecido no box.
  if S.inPit and (S.speed or 0) > 25 and not S.limiterManual and S.limiterForcedOff
      and ready(self, 'limiter', 300, now) then
    api.started('auto_limiter')
    api.say('mandatory_pit_stops', 'engage_limiter', 'Limitador!', { priority = true })
    api.done()
  end

    -- Pronto para sair: so depois de um servico observado e encerrado no box.
    local serviceActive = S.changingTyres or S.refueling or S.repairing
    if not S.inPit then
      self._pitServiceStarted, self._pitServiceClearSince = false, nil
      self._pitServiceCompleteCalled = false
    elseif S.inStall then
      if serviceActive then
        self._pitServiceStarted = true
        self._pitServiceClearSince = nil
      elseif self._pitServiceStarted and not self._pitServiceCompleteCalled then
        self._pitServiceClearSince = self._pitServiceClearSince or now
        if now - self._pitServiceClearSince >= 1.0 and ready(self, 'pitcomplete', 30, now) then
          self._pitServiceStarted, self._pitServiceCompleteCalled = false, true
          if not self._pitWaitPending then
            api.started('auto_pitcomplete', 60)
            api.say('mandatory_pit_stops', 'stop_complete_go', 'Parada concluída, pode sair', { priority = true })
            api.done()
          end
        end
      end
    end

    -- Pedido de box confirmado.
  if S.pitRequested and not self._pitReq then
    self._pitStopRequested = true
    if ready(self, 'pitreq', 60, now) then
      api.started('auto_pitreq')
      api.say('mandatory_pit_stops', 'pit_stop_requested', 'Box pedido', {})
      api.done()
    end
  elseif not S.pitRequested and not S.inPit then
    self._pitStopRequested = false
  end
  self._pitReq = S.pitRequested

  -- ERS/bateria e push-to-pass (so em carro com ERS).
  if S.kersMax then
    if S.kersPct and S.kersPct >= 15 then self._criticalBattLatched = false end
    if S.kersPct and S.kersPct >= 35 then
      self._lowBattLatched = false
    end
    if S.kersPct and S.kersPct < 10 and not self._criticalBattLatched then
      self._criticalBattLatched = true
      self._lowBattLatched = true
      if ready(self, 'battcritical', 240, now) then
        api.started('auto_battcritical', 85)
        api.say('battery', 'critical_battery', 'Bateria crítica', { priority = true })
        api.done()
      end
    elseif S.kersPct and S.kersPct < 25 and not self._lowBattLatched then
      self._lowBattLatched = true
      if ready(self, 'lowbatt', 240, now) then
        api.started('auto_batt')
        api.say('battery', 'low_battery', 'Bateria baixa', {})
        api.done()
      end
    end
    if S.p2p and S.p2p == 1 and self._p2p ~= 1 and ready(self, 'p2p1', 300, now) then
      api.started('auto_p2p')
      api.say('overtaking_aids', 'one_activation_remaining', 'Último push!', {})
      api.done()
    end
    self._p2p = S.p2p
  end

  -- Sem rastreio de setor (elogios automaticos removidos).

  -- Posicao ganha/perdida. Quando os comentarios locais estao ativos, eles ja
  -- avaliam a mudanca ao fechar a volta e evitamos repetir a mesma informacao.
  if S.sessType == 3 and S.pos and S.pos >= 1 then
    if not C.raceCommentary then
      if self._lastPos and S.pos < self._lastPos and ready(self, 'gain', 25, now) then
        local jumped = self._lastPos - S.pos
        api.started('auto_gain')
        if jumped >= 2 then
          api.say('pearls_of_wisdom', 'keep_it_up', 'Duas de uma vez!', {})
        elseif math.random() < 0.5 then
          api.say('position', 'overtaking', 'Ultrapassagem!', {})
        else
          api.say('pearls_of_wisdom', 'keep_it_up', 'Ultrapassagem!', {})
        end
        api.done()
      elseif self._lastPos and S.pos > self._lastPos then
        self._lossCount = self._lossCount + 1
        if ready(self, 'loss', 25, now) then
          api.started('auto_loss')
          api.say('position', 'being_overtaken', 'Perdeu posição', {})
          api.done()
        end
        local level = tonumber(C.rantLevel) or 0
        if not S.inPit and (S.speed or 0) > 30
            and (level >= 3 or (level == 2 and self._lossCount % 2 == 0)
              or (level == 1 and self._lossCount % 3 == 0)) then
          planRant(self, 'loss', C, now)
        end
      end
    end
    self._lastPos = S.pos
  end

  -- Rodada/parada (qualquer volta, inclusive a 1a: sem gate de volta).
  local speed = tonumber(S.speed)
  if speed and speed < 2 and not S.inPit and not S.finished then
    self._spinSince = self._spinSince or now
    if now - self._spinSince > 4 and ready(self, 'stall', 180, now) then
      self._spins = (self._spins or 0) + 1
      api.started('auto_stall')
      if self._spins >= 2 then
        api.say('pearls_of_wisdom', 'must_do_better', 'De novo?!', {})
      else
        api.say('engine_monitor', 'stalled', 'Rodou?', {})
      end
      api.done()
      if (C.rantLevel or 0) >= 3 then planRant(self, 'spin', C, now) end
    end
  else
    self._spinSince = nil
  end

  -- Saida do box: transito ou pista livre (+ custo medido da parada).
  if self._wasInPit and not S.inPit then
    self._pitStopRequested = false
    if ready(self, 'pitexit', 30, now) then
      api.started('auto_pitexit')
      if (nearby or 0) > 0 then
        api.say('strategy', 'expect_traffic_on_pit_exit', 'Tráfego na saída', {})
      else
        api.say('strategy', 'expect_clear_track_on_pit_exit', 'Saída livre', {})
      end
      if self._pitEnterT and now - self._pitEnterT > 5 then
        api.say('strategy', 'a_pitstop_costs_us_about', 'A parada custou', { noBeep = true })
        api.num(string.format('%.0f', now - self._pitEnterT))
        api.say('timings', 'seconds', 'segundos', { noBeep = true })
      end
      api.done()
    end
    self._pitEnterT = nil
  end
  if not self._wasInPit and S.inPit and S.started and not S.finished then
    self._pitEnterT = now
    if ready(self, 'pitenter', 60, now) then
      api.started('auto_pitenter')
      local pitWaitPending = S.penaltyType == 2
      if pitWaitPending then
        api.say('penalties', 'you_have_a_penalty', 'Aguarde nos boxes', {})
      else
        if self._pitStopRequested then
          api.say('mandatory_pit_stops', 'pit_crew_ready', 'Equipe pronta', {})
        else
          api.say('mandatory_pit_stops', 'box_in', 'No box', {})
        end
      end
      if G.need and G.need > 0.1 then
        api.say('mandatory_pit_stops', 'will_put_fuel_in', 'Vamos abastecer', { noBeep = true })
      end
      api.done()
    end
  end
  self._wasInPit = S.inPit

  -- Relogio da sessao (uma vez por marca).
  if S.timeLeftS and S.timeLeftS > 0 then
    local pos = S.pos or 99
    if S.timeLeftS <= 300 and S.timeLeftS > 120 and once(self, 't5') then
      api.started('auto_time')
      if pos == 1 then api.say('race_time', 'five_minutes_left_leading', '5 min, liderando', {})
      elseif pos == 2 or pos == 3 then api.say('race_time', 'five_minutes_left_podium', '5 min, pódio', {})
      else api.say('race_time', 'five_minutes_left', '5 minutos', {}) end
      api.done()
    end
    local marks = { { 1200, 't20', 'race_time', 'twenty_minutes_left', '20 minutos' },
      { 900, 't15', 'race_time', 'fifteen_minutes_left', '15 minutos' },
      { 600, 't10', 'race_time', 'ten_minutes_left', '10 minutos' },
      { 120, 't2', 'race_time', 'two_minutes_left', '2 minutos' },
      { 60, 't1', 'race_time', 'less_than_one_minute', 'Menos de 1 min' } }
    for _, m in ipairs(marks) do
      if S.timeLeftS <= m[1] and once(self, m[2]) then
        api.started('auto_time')
        api.say(m[3], m[4], m[5], {})
        api.done()
        break
      end
    end
  end

  -- Metade da prova + ultima volta + penultima.
  if G.remaining then
    if G.totalLaps and G.totalLaps > 1 and G.remaining == math.floor(G.totalLaps / 2)
        and once(self, 'half_race') then
      api.started('auto_half')
      api.say('race_time', 'half_way', 'Metade', {})
      api.done()
    end
    if G.totalLaps and G.totalLaps > 2 and G.remaining == 2 and once(self, 'twogo') then
      api.started('auto_twogo')
      api.say('race_time', 'one_more_lap_after_this_one', 'Duas voltas', {})
      api.done()
    end
    if G.remaining == 1 and not G.finished and once(self, 'onelap') then
      api.started('auto_lastlap')
      local pos = S.pos or 99
      if pos == 1 then api.say('lap_counter', 'last_lap_leading', 'Última, líder!', { priority = true })
      elseif pos == 2 or pos == 3 then api.say('race_time', 'last_lap_top_three', 'Última, pódio!', { priority = true })
      else api.say('race_time', 'last_lap', 'Última volta', { priority = true }) end
      api.done()
    end
    -- Meio tanque de prova com projecao de combustivel.
    if G.totalLaps and G.totalLaps > 1 and G.remaining == math.floor(G.totalLaps / 2)
        and G.margin ~= nil and once(self, 'halffuel') then
      api.started('auto_halffuel')
      if G.margin >= 0 then api.say('fuel', 'half_distance_good_fuel', 'Meio, ok', {})
      else api.say('fuel', 'half_distance_low_fuel', 'Meio, economize', {}) end
      api.done()
    end
  end

  -- Combustivel em voltas e em minutos (degraus, uma vez cada).
  if G.range and G.range > 0 and not G.finished then
    for _, lim in ipairs({ { 4, 'r4', 'fuel', 'four_laps_fuel', '4 voltas de combustível' },
        { 3, 'r3', 'fuel', 'three_laps_fuel', '3 voltas de combustível' },
        { 2, 'r2', 'fuel', 'two_laps_fuel', '2 voltas' },
        { 1, 'r1', 'fuel', 'one_lap_fuel', 'Última volta de combustível' } }) do
      if G.range <= lim[1] and once(self, lim[2]) then
        api.started('auto_fuelstep')
        api.say(lim[3], lim[4], lim[5], {})
        api.done()
        break
      end
    end
    if G.paceMs and G.paceMs > 0 then
      local rangeMin = G.range * G.paceMs / 60000
      if rangeMin <= 2 and once(self, 'fmin2') then
        api.started('auto_fuelmin')
        api.say('fuel', 'two_minutes_fuel', '2 minutos de combustível', {})
        api.done()
      elseif rangeMin <= 5 and once(self, 'fmin5') then
        api.started('auto_fuelmin')
        api.say('fuel', 'five_minutes_fuel', '5 minutos de combustível', {})
        api.done()
      elseif rangeMin <= 10 and once(self, 'fmin10') then
        api.started('auto_fuelmin')
        api.say('fuel', 'ten_minutes_fuel', '10 minutos de combustível', {})
        api.done()
      end
    end
  end

  -- Pressao dos pneus: escolhe apenas a roda com maior desvio por ciclo.
  if S.wheels[1] and S.wheels[1].psi then
    if not self._psiBase then
      self._psiBase = {}
      local complete = true
      for i = 1, 4 do
        local w = S.wheels[i]
        if w and w.psi then self._psiBase[i] = w.psi else complete = false end
      end
      if not complete then self._psiBase = nil end
    end
    if self._psiBase then
      local worst, worstDiff = nil, 0
      for i = 1, 4 do
        local w, base = S.wheels[i], self._psiBase[i]
        if w and w.psi and base then
          local diff = w.psi - base
          if math.abs(diff) >= 3 and math.abs(diff) > math.abs(worstDiff) then
            worst, worstDiff = i, diff
          end
        end
      end
      if worst then
        local high = worstDiff > 0
        local id = (high and 'phi' or 'plo') .. worst
        if tyreReady(self, id, 180, now, false) then
          api.started('auto_psi')
          api.say('tyre_monitor', PRESS_WHEEL[worst] .. (high and '_pressure_high' or '_pressure_low'),
            high and 'Pressão alta' or 'Pressão baixa', {})
          api.done()
        end
      end
    end
  end
  -- Camber: informa somente a maior diferenca interna x externa por ciclo.
  if S.wheels[1] and S.wheels[1].inner then
    local worst, worstDiff = nil, 0
    for i = 1, 4 do
      local w = S.wheels[i]
      if w and w.inner and w.outer then
        local diff = w.inner - w.outer
        if math.abs(diff) >= 5 and math.abs(diff) > math.abs(worstDiff) then
          worst, worstDiff = i, diff
        end
      end
    end
    if worst then
      local hotter = worstDiff > 0
      local id = (hotter and 'cain' or 'caout') .. worst
      if tyreReady(self, id, 240, now, false) then
        api.started('auto_camber')
        api.num(string.format('%.0f', math.abs(worstDiff)))
        api.say('tyre_monitor', hotter and 'celsius_hotter_than_outer' or 'celsius_colder_than_outer',
          hotter and 'mais quente dentro' or 'mais frio dentro', { noBeep = true })
        api.done()
      end
    end
  end
  -- Oponente direto entrando no box (pos-1 e pos+1, 1x por segundo).
  self._oppT = self._oppT or 0
  if S.sessType == 3 and S.pos and S.pos >= 1 and now - self._oppT >= 1 then
    self._oppT = now
    local sim
    pcall(function() if ac and ac.getSim then sim = ac.getSim() end end)
    if sim then
      local n = tonumber(sim.carsCount) or 1
      for _, d in ipairs({ { -1, 'ahead' }, { 1, 'behind' } }) do
        local found, inPit, rlap = false, false, nil
        for i = 0, n - 1 do
          local okC, c = false, nil
          if ac and ac.getCar then okC, c = pcall(ac.getCar, i) end
          if okC and c then
            local okP, pos = pcall(function() return c.racePosition end)
            if okP and pos == S.pos + d[1] then
              found = true
              local okPit, pit = pcall(function() return c.isInPitlane end)
              inPit = okPit and pit == true
              local okL, lap = pcall(function() return c.lapCount end)
              if okL and tonumber(lap) then rlap = math.floor(tonumber(lap)) end
              break
            end
          end
        end
        local key = 'opp' .. d[2]
        if found then
          if inPit and not (self._oppPit and self._oppPit[key]) then
            if ready(self, 'oppit', 60, now) then
              api.started('auto_oppit')
              api.say('opponents', d[2] == 'ahead' and 'ahead_is_pitting' or 'behind_is_pitting',
                d[2] == 'ahead' and 'Da frente no box' or 'De trás no box', {})
              api.done()
            end
          end
          self._oppPit = self._oppPit or {}
          self._oppPit[key] = inPit
          -- Volta(s) de vantagem/atraso contra o rival direto.
          if rlap and S.lap then
            local diff = d[2] == 'ahead' and (S.lap - rlap) or (rlap - S.lap)
            local state = diff >= 2 and 'multi' or (diff == 1 and 'one' or 'none')
            local lkey = 'lapdiff' .. d[2]
            if state ~= 'none' and self[lkey] ~= state and ready(self, lkey, 90, now) then
              api.started('auto_lapdiff')
              if state == 'one' then
                api.say('position', d[2] == 'ahead' and 'one_lap_ahead' or 'one_lap_down',
                  d[2] == 'ahead' and 'Volta de vantagem' or 'Volta atrás', {})
              else
                api.num(diff)
                api.say('position', d[2] == 'ahead' and 'laps_ahead' or 'laps_behind',
                  'voltas', { noBeep = true })
              end
              api.done()
            end
            self[lkey] = state
          end
        end
      end
    end
  end

  -- Pressionado por tras colado ha um tempo.
  if gaps.behind and gaps.behind < 0.6 and (S.speed or 0) > 80 then
    self._pressSince = self._pressSince or now
    if now - self._pressSince > 8 and ready(self, 'press', 150, now) then
      api.started('auto_press')
      api.say('timings', 'being_pressured', 'Pressionado', {})
      api.done()
    end
  else
    self._pressSince = nil
  end

  -- Carro lento ou parado a frente: avisa uma vez por encontro e rearma apenas
  -- depois de a diferenca de velocidade normalizar por alguns segundos.
  local ownSpeed = S.speed or 0
  local trackingAhead = gaps.aheadV ~= nil and not S.inPit and not S.finished
  local slowState
  if trackingAhead and ownSpeed > 60 then
    if gaps.aheadV < 12 then slowState = 'stopped'
    elseif gaps.aheadV < ownSpeed - 50 then slowState = 'slow' end
  end
  if slowState then
    self._slowCarClearSince = nil
    local escalated = slowState == 'stopped' and self._slowCarState == 'slow'
    if not self._slowCarState or escalated then
      self._slowCarState = slowState
      if slowState == 'stopped' then
        api.started('auto_stopped')
        api.say('flags', 'stopped_car_ahead', 'Carro parado!', { priority = true })
        api.done()
      elseif ready(self, 'slowcar', 30, now) then
        api.started('auto_slowcar')
        api.say('flags', 'slow_car_ahead', 'Carro lento', {})
        api.done()
      end
    end
  else
    local normalized = not trackingAhead
      or (gaps.aheadV >= 25 and gaps.aheadV >= ownSpeed - 25)
    if normalized then
      self._slowCarClearSince = self._slowCarClearSince or now
      if now - self._slowCarClearSince >= 3 then self._slowCarState = nil end
    else
      self._slowCarClearSince = nil
    end
  end

  if gaps.ahead and gaps.ahead < 1.2 and (S.speed or 0) > 80 then
    self._pushSince = self._pushSince or now
    if now - self._pushSince > 12 and ready(self, 'push', 120, now) then
      api.started('auto_push')
      api.say('push_now', 'push_to_improve', 'Ataca!', {})
      api.done()
    end
  else
    self._pushSince = nil
  end

  -- Entrada em batalha (gap na frente cruzou 1s para baixo).
  local inBattle = gaps.ahead and gaps.ahead < 1.0 and (S.speed or 0) > 80
  if inBattle and not self._wasBattle and ready(self, 'battle', 120, now) then
    api.started('auto_battle')
    api.say('push_now', 'push_to_improve', 'Batalha!', {})
    api.done()
  end
  self._wasBattle = inBattle and true or false

  -- Avaliacao de largada: posicao do grid contra +45s de corrida.
  if S.sessType == 3 and S.pos and S.pos >= 1 and not S.finished then
    if not self._t0 then self._t0 = now end
    if not self._gridPos then self._gridPos = math.floor(S.pos) end
    if now - self._t0 > 45 and once(self, 'starteval') then
      local delta = self._gridPos - math.floor(S.pos)
      api.started('auto_starteval')
      if delta >= 3 then api.say('position', 'good_start', 'Boa largada!', {})
      elseif delta <= -6 then api.say('position', 'terrible_start', 'Largada péssima', {})
      elseif delta <= -3 then api.say('position', 'bad_start', 'Largada ruim', {})
      else api.say('position', 'ok_start', 'Largada ok', {}) end
      api.done()
    end
  end

  -- Desabafo depois do incidente, apenas quando nao encobre radio importante.
  local rant = self._pendingRant
  if rant and (now - rant.at > 45 or (C.rantLevel or 0) <= 0) then
    self._pendingRant = nil
  elseif rant and calm and not overlap and not S.inPit and (S.speed or 0) > 35
      and api.idle() then
    self._pendingRant = nil
    api.started('auto_rant', 30)
    api.say('rants', 'general', 'Sally irritada',
      { takes = RANT_TAKES[rant.kind] or RANT_TAKES.loss })
    api.done()
  end

  local every = math.max(1, math.min(5, math.floor(tonumber(C.briefEvery) or 1)))
  -- Nos marcos de 5 voltas, usa o informe normal quando ele cair na mesma volta.
  if calm and C.warnSummary and not C.raceCommentary
      and G.paceN and G.paceN >= 4 and G.paceN % 5 == 0
      and G.paceN % every ~= 0 and once(self, 'pace' .. G.paceN) then
    api.started('auto_pace', 30)
    local trend = G.paceTrendMs or 0
    if trend < -150 then api.say('lap_times', { 'improving', 'pace_good' }, 'Ritmo melhorando', {})
    elseif trend > 150 then
      local change = math.abs(trend) / 1000
      if change >= 1 then
        if math.random() < 0.5 then api.say('lap_times', 'need_to_find_a_second', 'Achar 1s', {})
        else api.say('pearls_of_wisdom', 'must_do_better', 'Melhora!', {}) end
      elseif change >= 0.4 then api.say('lap_times', 'need_to_find_a_few_more_tenths', 'Décimos', {})
      else api.say('lap_times', 'need_to_find_one_more_tenth', 'Um décimo', {}) end
      api.num(string.format('%.1f', change))
      api.say('timings', 'seconds', 'segundos', { noBeep = true })
    else api.say('lap_times', { 'pace_ok', 'consistent' }, 'Ritmo estável', {}) end
    api.done()
  end

  -- Onde perde tempo: pior setor 1s+ acima do melhor (so em reta).
  if calm and G.secAvg[1] and G.secBest[1] then
    local worst, worstLoss = 0, 0
    for i = 1, 3 do
      if G.secAvg[i] and G.secBest[i] then
        local loss = G.secAvg[i] - G.secBest[i]
        if loss > worstLoss then worst, worstLoss = i, loss end
      end
    end
    if worstLoss > 1 and ready(self, 'secloss', 240, now) then
      api.started('auto_secloss', 30)
      api.say('lap_times', 'sector' .. worst .. '_a_second_off_pace', 'Setor ' .. worst, {})
      api.done()
    end
  end

  -- No treino: medias dos setores a cada 5 voltas + clima periodico.
  if S.sessType ~= 3 and calm and not S.inPit and not S.finished then
    if G.paceN and G.paceN >= 5 and G.paceN % 5 == 0 and once(self, 'secprac' .. G.paceN)
        and G.secAvg[1] and G.secAvg[2] and G.secAvg[3] then
      api.started('auto_secprac', 30)
      for i = 1, 3 do
        api.say('lap_times', 'sector' .. i .. '_is', 'Setor ' .. i, { noBeep = i > 1 })
        api.num(string.format('%.1f', G.secAvg[i]))
        api.say('timings', 'seconds', 's', { noBeep = true })
      end
      api.done()
    end
    if (S.airC or S.trackC) and ready(self, 'weatherprac', 240, now) then
      api.started('auto_weatherprac', 30)
      if S.airC then
        api.say('conditions', 'air_temp_is', 'Ar', {})
        api.num(string.format('%.0f', S.airC))
        api.say('conditions', 'celsius', 'graus', { noBeep = true })
      end
      if S.trackC then
        api.say('conditions', 'track_temp_is', 'Pista', { noBeep = true })
        api.num(string.format('%.0f', S.trackC))
        api.say('conditions', 'celsius', 'graus', { noBeep = true })
      end
      api.done()
    end
  end

  -- Chuva (Pure/weatherFX): faixas por intensidade, com estabilidade.
  -- Bandas: drizzle<=0.08, light<=0.22, mid<=0.40, heavy<=0.65, maximum+.
  self._rainT = self._rainT or 0
  if S.rain ~= nil and now - self._rainT >= 5 and not S.finished then
    self._rainT = now
    local r = S.rain
    local band = r <= 0 and 'none' or (r <= 0.08 and 'drizzle' or (r <= 0.22 and 'light'
      or (r <= 0.40 and 'mid' or (r <= 0.65 and 'heavy' or 'maximum'))))
    if band == self._rainCand then
      self._rainCandN = (self._rainCandN or 0) + 1
    else
      self._rainCand, self._rainCandN = band, 1
    end
    if self._rainCandN >= 2 and band ~= self._rainBand then
      local prev, up = self._rainBand, false
      local order = { none = 0, drizzle = 1, light = 2, mid = 3, heavy = 4, maximum = 5 }
      if prev then up = (order[band] or 0) > (order[prev] or 0) end
      self._rainBand = band
      if band == 'none' and prev and prev ~= 'none' then
        if ready(self, 'rainstop', 150, now) then
          api.started('auto_rainstop')
          api.say('conditions', 'stopped_raining', 'Parou de chover', {})
          api.done()
        end
      elseif band ~= 'none' and (not prev or prev == 'none') then
        if ready(self, 'rainstart', 150, now) then
          api.started('auto_rainstart')
          api.say('conditions', 'seeing_some_rain', 'Começou a chover!', { priority = true })
          api.done()
        end
      elseif band == 'maximum' then
        if ready(self, 'rainmax', 180, now) then
          api.started('auto_rainmax')
          api.say('conditions', 'maximum_rain', 'MUITA chuva!', { priority = true })
          api.done()
        end
      elseif band ~= 'none' and ready(self, 'rainband', 150, now) then
        api.started('auto_rainband')
        local clip = band .. '_rain_' .. (up and 'increasing' or 'decreasing')
        if band == 'drizzle' then clip = 'drizzle_' .. (up and 'increasing' or 'decreasing') end
        api.say('conditions', clip, 'Chuva', {})
        api.done()
      end
    end
  end

  -- Tendencia de temperatura do ar/pista (3+ graus em 5 min).
  self._tempT = self._tempT or 0
  if ((S.airC and S.trackC) and now - self._tempT >= 60) then
    self._tempT = now
    if not self._tempBase and S.airC and S.trackC then
      self._tempBase = { air = S.airC, track = S.trackC }
    elseif self._tempBase then
      local function trend(cur, base, cat, upClip, downClip, label)
        if cur and base then
          if cur - base >= 3 and once(self, 'tmp' .. cat .. 'up') then
            api.started('auto_temp')
            api.say('conditions', upClip, label .. ' subindo', {})
            api.num(string.format('%.0f', cur))
            api.say('conditions', 'celsius', 'graus', { noBeep = true })
            api.done()
            return true
          elseif base - cur >= 3 and once(self, 'tmp' .. cat .. 'down') then
            api.started('auto_temp')
            api.say('conditions', downClip, label .. ' caindo', {})
            api.num(string.format('%.0f', cur))
            api.say('conditions', 'celsius', 'graus', { noBeep = true })
            api.done()
            return true
          end
        end
        return false
      end
      trend(S.airC, self._tempBase.air, 'air', 'air_temp_increasing_its_now',
        'air_temp_decreasing_its_now', 'Ar')
      trend(S.trackC, self._tempBase.track, 'track', 'track_temp_increasing_its_now',
        'track_temp_decreasing_its_now', 'Pista')
    end
  end

  -- Informe curto apos voltas validas. Espera o radio e uma reta livres;
  -- se demorar demais, descarta para nao anunciar uma volta antiga.
  local sample = G.paceN or 0
  if sample > self._briefSeen then
    self._briefSeen = sample
    if C.warnSummary and not C.raceCommentary and not S.inPit and not S.finished
        and sample % every == 0 and G.lastMs and G.lastMs > 0 then
      self._pendingBrief = { sample = sample, lapMs = G.lastMs, at = now,
        allGood = G.lastAllGood == true }
    end
  end
  local brief = self._pendingBrief
  if brief and (now - brief.at > 35 or sample > brief.sample or S.finished) then
    self._pendingBrief = nil
  elseif brief and calm and not overlap and (S.speed or 0) > 40 and api.idle()
      and now - (self._lastBriefAt or -1e9) > 45 then
    self._pendingBrief = nil
    self._lastBriefAt = now
    api.started('auto_lap', 30)
    if G.bestMs and brief.lapMs <= G.bestMs + 50 then
      api.say('lap_times', 'personal_best', 'Melhor volta', {})
    else
      api.say('lap_times', 'time_intro', 'Última volta', {})
    end
    local total = brief.lapMs / 1000
    api.time(math.floor(total / 60), total % 60)
    if brief.allGood then
      api.say('lap_times', 'sector_all_fast', 'Bons tempos nos três setores', { noBeep = true })
    elseif brief.sample % 5 == 0 then
      local trend = G.paceTrendMs or 0
      if trend < -150 then
        api.say('lap_times', 'improving', 'Ritmo melhorando', { noBeep = true })
      elseif trend > 150 then
        api.say('lap_times', 'worsening', 'Ritmo piorando', { noBeep = true })
      else
        api.say('lap_times', 'consistent', 'Ritmo consistente', { noBeep = true })
      end
    elseif brief.sample % 3 == 0 and C.warnFuel and G.range and G.range > 0 then
      api.say('fuel', 'we_estimate', 'Autonomia', { noBeep = true })
      api.num(string.format('%.1f', G.range))
      api.say('fuel', 'laps_remaining', 'voltas de combustível', { noBeep = true })
    elseif brief.sample % 7 == 0 and S.pos and S.pos >= 1 and S.pos <= 3
        and gaps.ahead == nil and gaps.leader then
      -- Entre os 3 primeiros sem ninguem colado: gap para o lider.
      api.say('opponents', 'the_leader', 'O líder', { noBeep = true })
      api.say('timings', 'the_gap_to', 'gap', { noBeep = true })
      api.num(string.format('%.1f', gaps.leader))
      api.say('timings', 'seconds', 'segundos', { noBeep = true })
    elseif brief.sample % 2 == 0 and ((gaps.ahead and gaps.ahead < 20)
        or (gaps.behind and gaps.behind < 20)) then
      local ahead = gaps.ahead and gaps.ahead < 20
      local gap = ahead and gaps.ahead or gaps.behind
      api.say('timings', ahead and 'gap_in_front_is_now' or 'gap_behind_is_now',
        ahead and 'Gap à frente' or 'Gap atrás', { noBeep = true })
      api.num(string.format('%.1f', gap))
      api.say('timings', 'seconds', 'segundos', { noBeep = true })
    elseif S.sessType == 3 and S.pos and S.pos >= 1 then
      -- So em corrida: fora dela racePosition nao e ordem real.
      local position = math.floor(S.pos)
      if not api.say('position', 'p' .. position, 'P' .. position, { noBeep = true }) then
        api.num(position)
      end
    end
    api.done()
  end

  -- Informe de combustivel mesmo sem estimativa por volta (por exemplo,
  -- consumo desligado ou antes da primeira volta completa).
  if C.warnFuel and G.fuel ~= nil and not S.finished then
    self._nextFuelStatus = self._nextFuelStatus or (now + 45)
    if now >= self._nextFuelStatus and calm and not overlap and not S.inPit
        and (S.speed or 0) > 35 and api.idle() then
      local interval = math.max(60, math.min(300, tonumber(C.fuelStatusSeconds) or 90))
      self._nextFuelStatus = now + interval
      api.started('auto_fuelstatus', 30)
      api.say('fuel', 'we_estimate', 'Combustivel restante', {})
      api.num(string.format('%.1f', G.fuel))
      api.say('fuel', 'litres_remaining', 'litros', { noBeep = true })
      if G.range and G.range > 0 then
        api.num(string.format('%.1f', G.range))
        api.say('fuel', 'laps_remaining', 'voltas de autonomia', { noBeep = true })
      end
      if G.remaining and G.remaining > 1 then
        api.say('race_time', 'laps_remaining', 'faltam', { noBeep = true })
        api.num(string.format('%.0f', G.remaining))
      end
      if G.perLap and G.perLap > 0 then
        api.num(string.format('%.2f', G.perLap))
        api.say('fuel', 'litres_per_lap', 'por volta', { noBeep = true })
      end
      api.done()
    end
  end
end

return Warn
