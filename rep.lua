-- Relatorios sob demanda: composicoes Sally com numeros da telemetria.
-- Todas as frases verificadas nas transcrições (subtitles.csv).

local Rep = {}

local WHEEL_CLIP = { 'left_front', 'right_front', 'left_rear', 'right_rear' }
local WHEEL_HOT = { 'cooking_left_front_tyre', 'cooking_right_front_tyre',
  'cooking_left_rear_tyre', 'cooking_right_rear_tyre' }

function Rep.new(voice, sally, C, beepAbs)
  local self = { voice = voice, sally = sally, C = C, beepAbs = beepAbs,
    serial = 0, group = nil, beeped = false, aborted = false, prio = 50 }
  local api = {}

  function api.started(id, prio)
    self.serial = self.serial + 1
    self.group = tostring(id) .. ':' .. self.serial
    api.group = self.group
    self.beeped = false
    self.aborted = false
    self.prio = tonumber(prio) or self.manualPrio or 50
  end
  function api.done() self.group = nil; api.group = nil; self.manualPrio = nil; self.aborted = false end
  function api.idle() return not voice:isBusy() end
  -- Pedido manual: prioridade 60 passa na frente de aviso comum (50/30),
  -- mas nunca corta o spotter (100).
  function api.manual() self.manualPrio = 60 end

  function api.say(cat, phrase, cap, o)
    if self.aborted then return false end
    o = o or {}
    if o.priority == true then self.prio = math.max(self.prio, 90) end
    if type(phrase) == 'table' then phrase = phrase[math.random(1, #phrase)] end
    local path
    if o.takes then path = sally:clipTake(cat, phrase, o.takes)
    else path = sally:clip(cat, phrase) end
    if not path then
      -- A report must not continue after a missing clip, otherwise the driver
      -- hears an incomplete sentence assembled from later queue entries.
      voice:cancel(self.group, false)
      self.aborted = true
      return false
    end
    local vol = C.engVol * C.master
    if C.playBeep and not o.noBeep and not self.beeped and beepAbs then
      voice:enqueue(beepAbs, nil, nil, { beep = true, vol = vol, group = self.group,
        ttl = 30, priorityValue = self.prio })
    end
    self.beeped = true
    voice:enqueue(path, cap or phrase:gsub('_', ' '), 'SALLY', { vol = vol, group = self.group,
      ttl = 30, priorityValue = self.prio, key = self.group })
    return true
  end

  function api.num(v)
    if self.aborted then return false end
    local paths = sally:numberClips(v)
    if #paths == 0 then
      voice:cancel(self.group, false)
      self.aborted = true
      return false
    end
    local vol = C.engVol * C.master
    for _, path in ipairs(paths) do
      voice:enqueue(path, tostring(v), 'SALLY', { vol = vol, group = self.group,
        ttl = 30, priorityValue = self.prio, key = self.group })
    end
    return true
  end

  function api.time(m, s)
    m = math.floor(tonumber(m) or 0)
    s = tonumber(s) or 0
    local label = m > 0 and string.format('%d:%04.1f', m, s) or string.format('%.1f s', s)
    if m > 0 then api.num(m) end
    api.num(string.format('%.1f', s))
    api.say('timings', 'seconds', label, { noBeep = true })
  end

  self.api = api
  return self
end

function Rep:fuel(S, G)
  local api = self.api
  api.started('fuel')
  if G.fuel then
    api.say('fuel', 'we_estimate', 'Estimamos', {})
    api.num(string.format('%.1f', G.fuel))
    api.say('fuel', 'litres_remaining', string.format('%.1f litros', G.fuel), { noBeep = true })
    if G.range then
      api.num(string.format('%.1f', G.range))
      api.say('fuel', 'laps_remaining', 'voltas de autonomia', { noBeep = true })
    end
  else
    api.say('acknowledge', 'no_data', 'Sem dados', {})
  end
  api.done()
  if not G.fuel then return 'Sally: sem telemetria' end
  local msg = string.format('Sally: %.1f L', G.fuel)
  if G.range then msg = msg .. string.format(' (%.1f voltas)', G.range) end
  if G.need and G.need > 0.1 then msg = msg .. string.format(' — faltam %.1f L', G.need) end
  return msg
end

function Rep:gap(direction, seconds, meters)
  local api = self.api
  api.started('gap')
  if not seconds then
    api.say('acknowledge', 'no_data', 'Sem intervalo', {})
  else
    local t = string.format('%.1f', seconds)
    if direction == 'leader' then
      api.say('opponents', 'the_leader', 'O líder', {})
      api.say('timings', 'the_gap_to', 'gap', { noBeep = true })
    else
      api.say('timings', direction == 'behind' and 'gap_behind_is_now' or 'gap_in_front_is_now',
        direction == 'behind' and 'Atrás' or 'À frente', {})
    end
    api.num(t)
    api.say('timings', 'seconds', t .. ' s', { noBeep = true })
    if meters and meters > 0 then
      api.num(string.format('%.0f', meters))
      api.say('mandatory_pit_stops', 'metres', string.format('%.0f metros', meters), { noBeep = true })
    end
  end
  api.done()
  local msg = seconds and ('Sally: gap ' .. string.format('%.1f s', seconds)) or 'Sally: sem intervalo'
  if seconds and meters and meters > 0 then msg = msg .. string.format(' (%.0f m)', meters) end
  return msg
end

-- Disputa: posicao + gap frente + gap atras (tudo com metros).
function Rep:battle(S, ga, ma, gb, mb)
  local api = self.api
  api.started('battle')
  local p = S and math.floor(tonumber(S.pos) or 0) or 0
  local played = false
  if p >= 1 then
    if p == 1 then api.say('position', 'leading', 'P1', {})
    elseif not api.say('position', 'p' .. p, 'P' .. p, {}) then api.num(p) end
    played = true
  end
  if ga then
    api.say('timings', 'gap_in_front_is_now', 'À frente', { noBeep = played })
    api.num(string.format('%.1f', ga))
    api.say('timings', 'seconds', 's', { noBeep = true })
    if ma and ma > 0 then
      api.num(string.format('%.0f', ma))
      api.say('mandatory_pit_stops', 'metres', 'metros', { noBeep = true })
    end
    played = true
  end
  if gb then
    api.say('timings', 'gap_behind_is_now', 'Atrás', { noBeep = played })
    api.num(string.format('%.1f', gb))
    api.say('timings', 'seconds', 's', { noBeep = true })
    if mb and mb > 0 then
      api.num(string.format('%.0f', mb))
      api.say('mandatory_pit_stops', 'metres', 'metros', { noBeep = true })
    end
    played = true
  end
  if not played then api.say('acknowledge', 'no_data', 'Sem disputa', {}) end
  api.done()
  return 'Sally: disputa'
end

function Rep:pos(S)
  local api = self.api
  api.started('pos')
  local p = S and math.floor(tonumber(S.pos) or 0) or 0
  if p < 1 then
    api.say('acknowledge', 'no_data', 'Sem posição', {})
  elseif S and S.carsCount and S.carsCount > 1 and p >= S.carsCount then
    api.say('position', 'last', 'Último', {})
  elseif p == 1 and (not S or S.sessType ~= 3) then
    api.say('position', 'pole', 'Pole!', {})
  elseif p == 1 then
    api.say('position', 'leading', 'P1, líder', {})
  elseif not api.say('position', 'p' .. p, 'P' .. p, {}) then
    api.num(p)
  end
  api.done()
  return p >= 1 and ('Sally: P' .. p) or 'Sally: sem posição'
end

function Rep:lap(kind, S, G)
  local api = self.api
  api.started('lap')
  local ms = kind == 'best' and (G.bestMs or (S and S.bestMs)) or (G.lastMs or (S and S.lastMs))
  if not ms or ms <= 0 then
    api.say('acknowledge', 'no_data', 'Sem volta', {})
  else
    local total = ms / 1000
    if kind == 'best' then
      api.say('lap_times', 'personal_best', 'Melhor volta', {})
    elseif G.bestMs and ms <= G.bestMs + 50 then
      api.say('lap_times', 'personal_best', 'Melhor volta!', {})
    elseif G.paceMs and ms < G.paceMs then
      api.say('lap_times', 'good_lap', 'Boa volta', {})
    else
      api.say('lap_times', 'time_intro', 'Última volta', {})
    end
    api.time(math.floor(total / 60), total % 60)
  end
  api.done()
  return 'Sally: volta ' .. (ms and ('(' .. string.format('%d:%04.1f', math.floor(ms / 60000), (ms % 60000) / 1000) .. ')') or '')
end

function Rep:sectors(G)
  local api = self.api
  api.started('sectors')
  if G.secAvg[1] and G.secAvg[2] and G.secAvg[3] then
    for i = 1, 3 do
      local best = (G.secBest and G.secBest[i]) or G.secAvg[i]
      local loss = math.max(0, G.secAvg[i] - best)
      if loss < 0.05 then
        api.say('lap_times', 'sector' .. i .. '_fast', 'Setor ' .. i .. ' rápido', { noBeep = i > 1 })
      elseif loss <= 0.25 then
        api.say('lap_times', 'sector' .. i .. '_a_tenth_off_pace', 'Setor ' .. i, { noBeep = i > 1 })
      elseif loss <= 1.2 then
        api.say('lap_times', 'sector' .. i .. '_is', 'Setor ' .. i, { noBeep = i > 1 })
        api.num(string.format('%.1f', loss))
        api.say('timings', 'seconds', 's', { noBeep = true })
      else
        api.say('lap_times', 'sector' .. i .. '_a_second_off_pace', 'Setor ' .. i, { noBeep = i > 1 })
      end
    end
  else
    api.say('acknowledge', 'no_data', 'Sem setores', {})
  end
  api.done()
  return 'Sally: setores'
end

function Rep:pace(G)
  local api = self.api
  api.started('pace')
  local trend = G.paceTrendMs or 0
  if not G.paceMs then
    api.say('acknowledge', 'no_data', 'Sem ritmo', {})
  elseif trend < -150 then
    api.say('lap_times', { 'improving', 'pace_good' }, 'Melhorando', {})
  elseif trend > 150 then
    local change = math.abs(trend) / 1000
    if change >= 1 then
      if math.random() < 0.5 then api.say('lap_times', 'need_to_find_a_second', 'Achar 1s', {})
      else api.say('pearls_of_wisdom', 'must_do_better', 'Melhora!', {}) end
    elseif change >= 0.4 then api.say('lap_times', 'need_to_find_a_few_more_tenths', 'Décimos', {})
    else api.say('lap_times', 'need_to_find_one_more_tenth', 'Um décimo', {}) end
    api.num(string.format('%.1f', change))
    api.say('timings', 'seconds', 'segundos', { noBeep = true })
  else
    api.say('lap_times', { 'pace_ok', 'consistent' }, 'Estável', {})
  end
  api.done()
  return 'Sally: ritmo'
end

function Rep:tyres(S, G)
  local api = self.api
  api.started('tyres')
  local hot, hotT = 1, -1e9
  for i = 1, 4 do
    local w = S and S.wheels[i]
    if w and w.temp > hotT then hot, hotT = i, w.temp end
  end
  local w = S and S.wheels[hot]
  if not w then
    api.say('acknowledge', 'no_data', 'Sem pneus', {})
  else
    if S and S.compound then
      api.say('tyre_monitor', S.compound, S.compound, {})
    end
    -- Todas as 4 rodas com temperatura; pressao da mais quente.
    for i = 1, 4 do
      local wi = S.wheels[i]
      if wi then
        api.say('tyre_monitor', WHEEL_CLIP[i], 'Pneu ' .. i, { noBeep = true })
        api.num(string.format('%.0f', wi.temp))
        api.say('conditions', 'celsius', 'graus', { noBeep = true })
      end
    end
    if w.psi then
      api.say('tyre_monitor', WHEEL_CLIP[hot], 'Pressão', { noBeep = true })
      api.num(string.format('%.1f', w.psi))
      api.say('tyre_monitor', 'psi', 'psi', { noBeep = true })
    end
    local worstW = 0
    for i = 1, 4 do
      local wi = S.wheels[i]
      if wi and wi.wear and wi.wear > worstW then worstW = wi.wear end
    end
    if worstW > 0.05 then
      api.num(string.format('%.0f', worstW * 100))
      api.say('battery', 'percent', 'por cento de desgaste', { noBeep = true })
    end
    local stint = G and tonumber(G.stintLaps) or 0
    if stint and stint >= 2 then
      api.say('tyre_monitor', 'laps_on_current_tyres_intro', 'Estimamos', { noBeep = true })
      api.num(stint)
      api.say('tyre_monitor', 'laps_on_current_tyres_outro', 'voltas com estes pneus', { noBeep = true })
    end
  end
  api.done()
  return 'Sally: pneus'
end

function Rep:damage(S)
  local api = self.api
  api.started('damage')
  local total = (S and S.dmgTotal) or 0
  if total <= 0 then api.say('damage_reporting', 'no_damage', 'Sem dano', {})
  elseif total >= 60 then api.say('damage_reporting', 'severe_aero_damage', 'Dano grave', {})
  else api.say('damage_reporting', 'minor_aero_damage', 'Dano leve', {}) end
  api.done()
  local total = (S and S.dmgTotal) or 0
  return 'Sally: dano total ' .. tostring(math.floor(total))
end

function Rep:engine(S)
  local api = self.api
  api.started('engine')
  if S and S.engLife and S.engLife <= 0 then
    api.say('damage_reporting', 'busted_engine', 'Motor quebrou', {})
  else
    api.say('engine_monitor', 'all_clear', 'Motor ok', {})
    if S and S.oilC then
      api.say('engine_monitor', 'oil_temp_intro', 'Óleo', { noBeep = true })
      api.num(string.format('%.0f', S.oilC))
      api.say('conditions', 'celsius', 'graus', { noBeep = true })
    end
    if S and S.waterC then
      api.say('engine_monitor', 'water_temp_intro', 'Água', { noBeep = true })
      api.num(string.format('%.0f', S.waterC))
      api.say('conditions', 'celsius', 'graus', { noBeep = true })
    end
  end
  api.done()
  if S and S.engLife and S.engLife <= 0 then return 'Sally: MOTOR QUEBROU' end
  return 'Sally: motor ok' .. (S and S.rpm and (' (' .. math.floor(S.rpm) .. ' rpm)') or '')
end

function Rep:weather(S)
  local api = self.api
  api.started('weather')
  if S and S.rain and S.rain > 0 then
    api.say('conditions', 'seeing_some_rain', 'Chovendo', {})
  end
  if S and (S.airC or S.trackC) then
    if S.airC then
      api.say('conditions', { 'air_temp_is', 'air_temp_is_now' }, 'Ar', {})
      api.num(string.format('%.0f', S.airC))
      api.say('conditions', 'celsius', 'graus', { noBeep = true })
    end
    if S.trackC then
      api.say('conditions', { 'track_temp_is', 'track_temp_is_now' }, 'Pista', {})
      api.num(string.format('%.0f', S.trackC))
      api.say('conditions', 'celsius', 'graus', { noBeep = true })
    end
  else
    api.say('acknowledge', 'no_data', 'Sem clima', {})
  end
  api.done()
  local t = 'Sally:'
  if S and S.rain and S.rain > 0 then t = t .. ' CHOVENDO' end
  if S and S.airC then t = t .. string.format(' ar %.0f C', S.airC) end
  if S and S.trackC then t = t .. string.format(' pista %.0f C', S.trackC) end
  if S and S.wind then t = t .. string.format(' vento %.0f km/h', S.wind) end
  return t == 'Sally:' and 'Sally: sem clima' or t
end

function Rep:pit(S, G)
  local api = self.api
  api.started('pit')
  if G.need and G.need > 0.1 then
    api.say('mandatory_pit_stops', 'box_now', 'Box agora', {})
    api.num(string.format('%.1f', G.need))
    api.say('fuel', 'litres_to_get_to_the_end', 'litros', { noBeep = true })
  elseif G.remaining and G.fuel then
    api.say('fuel', 'fuel_should_be_ok', 'Combustível ok', {})
  else
    api.say('acknowledge', 'stand_by', 'Aguarde', {})
  end
  api.done()
  if G.need and G.need > 0.1 then return string.format('Sally: parar! Faltam %.1f L', G.need) end
  if G.remaining and G.fuel then return 'Sally: dá para terminar' end
  return 'Sally: box?'
end

function Rep:remaining(G, S)
  local api = self.api
  api.started('remaining')
  if G.remaining and G.remaining <= 1 then
    api.say('race_time', 'last_lap', 'Última volta', {})
  elseif G.remaining then
    api.say('race_time', 'laps_remaining', 'Faltam', {})
    api.num(string.format('%.0f', G.remaining))
    if S and S.timeLeftS and S.timeLeftS > 0 then
      api.num(string.format('%.0f', S.timeLeftS / 60))
      api.say('mandatory_pit_stops', 'minutes', 'minutos', { noBeep = true })
    end
  else
    api.say('acknowledge', 'no_data', 'Sem dados', {})
  end
  api.done()
  if not G.remaining then return 'Sally: sem dados' end
  if G.remaining <= 1 then return 'Sally: ÚLTIMA VOLTA' end
  local msg = string.format('Sally: faltam %.0f voltas', G.remaining)
  if S and S.timeLeftS and S.timeLeftS > 0 then
    msg = msg .. string.format(' (%.0f min)', S.timeLeftS / 60)
  end
  return msg
end

function Rep:cons(G)
  local api = self.api
  api.started('cons')
  if G.perLap then
    api.num(string.format('%.2f', G.perLap))
    api.say('fuel', 'litres_per_lap', 'litros por volta', { noBeep = true })
  else
    api.say('acknowledge', 'no_data', 'Sem consumo', {})
  end
  api.done()
  return G.perLap and string.format('Sally: %.2f L/volta', G.perLap) or 'Sally: sem consumo'
end

function Rep:push(S, gaps)
  local api = self.api
  api.started('push')
  gaps = gaps or {}
  local pos = S and tonumber(S.pos) or nil
  if pos == 2 and gaps.ahead and gaps.ahead < 3 then
    api.say('push_now', 'push_to_get_win', 'Pela vitória!', {})
  elseif pos == 3 and gaps.ahead and gaps.ahead < 3 then
    api.say('push_now', 'push_to_get_second', 'Pelo P2!', {})
  elseif pos == 1 and gaps.behind and gaps.behind < 3 then
    api.say('push_now', 'push_to_hold_position', 'Segura!', {})
  else
    api.say('push_now', 'push_to_improve', 'Ataca!', {})
  end
  api.done()
  return 'Sally: push'
end

function Rep:ers(S)
  local api = self.api
  api.started('ers')
  if not (S and S.kersMax) then
    api.say('acknowledge', 'no_data', 'Sem ERS', {})
  else
    if S.kersPct then
      api.num(string.format('%.0f', S.kersPct))
      api.say('battery', 'percent', 'por cento de bateria', {})
    end
    if S.p2p and S.p2p > 0 then
      if S.p2p == 1 then
        api.say('overtaking_aids', 'one_activation_remaining', 'Última ativação', { noBeep = true })
      else
        api.num(S.p2p)
      end
    end
  end
  api.done()
  if not (S and S.kersMax) then return 'Sally: sem ERS' end
  return 'Sally: bateria ' .. (S.kersPct and string.format('%.0f%%', S.kersPct) or '?')
end

function Rep:radiocheck()
  local api = self.api
  api.started('radiocheck')
  api.say('radio_check', 'test', 'Radio check', {})
  api.done()
  return 'Sally: radio check'
end

function Rep:penalty(S)
  local api = self.api
  api.started('penalty')
  local kind = S and S.penaltyType
  local param = S and S.penaltyParameter
  if kind == 2 then
    api.say('penalties', 'you_have_a_penalty', 'Aguarde nos boxes', {})
    if param and param > 0 then
      api.num(param)
      api.say('timings', 'seconds', 'segundos', { noBeep = true })
    end
  elseif S and S.returnToPits and (kind == nil or kind == 0 or kind == 5) then
    api.say('penalties', 'you_have_a_penalty', 'Retorne aos boxes para cumprir a penalidade', {})
  elseif kind == nil then
    api.say('acknowledge', 'no_data', 'Sem dado de penalidade', {})
  elseif kind == 0 then
    api.say('penalties', 'you_dont_have_a_penalty', 'Sem penalidade', {})
  elseif kind == 5 then
    api.say('penalties', 'penalty_served', 'Penalidade liberada', {})
  elseif kind == 3 then
    api.say('penalties', 'new_penalty_slowdown', 'Reduza para cumprir a penalidade', {})
    if param and param > 0 then
      api.num(param)
      api.say('timings', 'seconds', 'segundos', { noBeep = true })
    end
  elseif kind == 4 then
    api.say('penalties', 'new_penalty_black_flag', 'Bandeira preta', {})
  elseif kind == 1 then
    api.say('penalties', 'you_have_a_penalty', 'Parada obrigatória', {})
    if param and param > 0 then
      api.num(param)
      api.say('race_time', 'laps_remaining', 'voltas', { noBeep = true })
    end
  else
    api.say('penalties', 'you_have_a_penalty', 'Há uma penalidade', {})
  end
  api.done()
  return kind == nil and 'Sally: penalidade indisponível'
    or ('Sally: penalidade ' .. tostring(kind))
end

function Rep:rant()
  local api = self.api
  api.started('manual_rant', 50)
  api.say('rants', 'general', 'Sally irritada',
    { takes = { '9', '17', '18', '19', '22', '24', '26', '27', '28', '29' } })
  api.done()
  return 'Sally: desabafo'
end

function Rep:hotTyre(wheel)
  local api = self.api
  api.started('hottyre')
  api.say('tyre_monitor', WHEEL_HOT[wheel] or 'cooking_tyres_all_round', 'Pneu quente', { priority = true })
  api.done()
end

return Rep
