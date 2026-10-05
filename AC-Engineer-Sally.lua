-- AC Engineer Sally: engenheira + spotter 100% voz Sally (clips gravados).
-- Voz Sally gravada e comentarios escolhidos por regras locais de telemetria.
-- Alertas e comentarios funcionam sem internet e sem servicos externos.

local Sally = require 'sally'
local Voice = require 'voice'
local Tele = require 'tele'
local Spot = require 'spot'
local Strat = require 'strat'
local Warn = require 'warn'
local Rep = require 'rep'
local UI = require 'ui'
local Lang = require 'lang'
local Avatar = require 'avatar'
local Coach = require 'coach'

local root = ac.getFolder(ac.FolderID.ScriptOrigin)
local avatarFrames = Avatar.load(root)

------------------------------------------------------------
-- Config
------------------------------------------------------------
local cfg
do
  local ok, c = pcall(function()
    if ac.INIConfig and ac.INIConfig.load then return ac.INIConfig.load(root .. '/config.ini') end
    if ac.INIConfig then return ac.INIConfig(root .. '/config.ini') end
    return nil
  end)
  cfg = (ok and c) or { get = function() return nil end }
  if not cfg.get then cfg = { get = function() return nil end } end
end

local function getStr(s, k, d)
  local ok, v = pcall(function() return cfg:get(s, k, d) end)
  if not ok or v == nil then return d end
  return tostring(v)
end
local function getNum(s, k, d)
  return tonumber(getStr(s, k, tostring(d))) or d
end
local function getBool(s, k, d)
  local v = tostring(getStr(s, k, d and '1' or '0')):lower()
  return v == '1' or v == 'true'
end

local C = {
  engVol = 22.5, spotVol = 15, playBeep = true, bgVol = 0.5,
  speed = 1.0, pitch = 1.0, master = 1.0,
  spotOn = true, minSpeed = 36,
  warnFlags = true, warnFuel = true, warnTyres = true, warnDamage = true,
  warnSummary = true, briefEvery = 1, fuelStatusSeconds = 90, rantLevel = 0,
  tyCold = 0, tyHot = 0, reserve = 1.0,
  voiceOn = true, radioOn = true, showAvatar = true, raceCommentary = true,
  accR = 0.86, accG = 0.12, accB = 0.12,
  language = 'pt-BR',
}
C.engVol = getNum('AUDIO', 'ENGINEER_VOLUME', C.engVol)
C.spotVol = getNum('AUDIO', 'SPOTTER_VOLUME', C.spotVol)
C.playBeep = getBool('AUDIO', 'PLAY_BEEP', C.playBeep)
C.bgVol = getNum('AUDIO', 'BG_VOLUME', C.bgVol)
C.speed = getNum('AUDIO', 'SPEED', C.speed)
C.pitch = getNum('AUDIO', 'PITCH', C.pitch)
C.spotOn = getBool('SPOTTER', 'ENABLED', C.spotOn)
C.minSpeed = getNum('SPOTTER', 'MIN_SPEED', C.minSpeed)
C.warnFlags = getBool('WARN', 'FLAGS', C.warnFlags)
C.warnFuel = getBool('WARN', 'FUEL', C.warnFuel)
C.warnTyres = getBool('WARN', 'TYRES', C.warnTyres)
C.warnDamage = getBool('WARN', 'DAMAGE', C.warnDamage)
C.warnSummary = getBool('WARN', 'SUMMARY', C.warnSummary)
C.briefEvery = math.max(1, math.min(5, math.floor(getNum('WARN', 'BRIEF_EVERY', C.briefEvery))))
C.fuelStatusSeconds = math.max(60, math.min(300,
  math.floor(getNum('WARN', 'FUEL_STATUS_SECONDS', C.fuelStatusSeconds))))
C.rantLevel = math.max(0, math.min(3, math.floor(getNum('WARN', 'RANTS', C.rantLevel))))
C.tyCold = getNum('WARN', 'COLD', 0)
C.tyHot = getNum('WARN', 'HOT', 0)
C.reserve = getNum('STRATEGY', 'RESERVE', C.reserve)
C.language = getStr('LANG', 'LANGUAGE', C.language)
if C.language ~= 'en-US' and C.language ~= 'pt-BR' then C.language = 'pt-BR' end
local L = Lang.new(C.language)

-- Ajustes do usuario (sobrescrevem o config.ini).
local settingsPath = root .. '/user_settings.ini'
do
  local ok, file = pcall(io.open, settingsPath, 'r')
  if ok and file then
    local section
    for line in file:lines() do
      local s = line:match('^%s*%[(.-)%]%s*$')
      if s then section = s end
      local k, v = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
      if k and section == 'SALLY' then
        if k == 'ENGINEER_VOLUME' then C.engVol = tonumber(v) or C.engVol
        elseif k == 'SPOTTER_VOLUME' then C.spotVol = tonumber(v) or C.spotVol
        elseif k == 'BG_VOLUME' then C.bgVol = tonumber(v) or C.bgVol
        elseif k == 'SPEED' then C.speed = tonumber(v) or C.speed
        elseif k == 'PITCH' then C.pitch = tonumber(v) or C.pitch
        elseif k == 'RESERVE' then C.reserve = tonumber(v) or C.reserve
        elseif k == 'SPOTTER' then C.spotOn = v == '1'
        elseif k == 'BEEP' then C.playBeep = v == '1'
        elseif k == 'FLAGS' then C.warnFlags = v == '1'
        elseif k == 'FUEL' then C.warnFuel = v == '1'
        elseif k == 'TYRES' then C.warnTyres = v == '1'
        elseif k == 'DAMAGE' then C.warnDamage = v == '1'
        elseif k == 'SUMMARY' then C.warnSummary = v == '1'
        elseif k == 'BRIEF_EVERY' then
          C.briefEvery = math.max(1, math.min(5, math.floor(tonumber(v) or C.briefEvery)))
        elseif k == 'FUEL_STATUS_SECONDS' then
          C.fuelStatusSeconds = math.max(60, math.min(300,
            math.floor(tonumber(v) or C.fuelStatusSeconds)))
        elseif k == 'RANTS' then
          C.rantLevel = math.max(0, math.min(3, math.floor(tonumber(v) or C.rantLevel)))
        elseif k == 'SHOW_AVATAR' then C.showAvatar = v == '1'
        elseif k == 'RACE_COMMENTARY' then C.raceCommentary = v == '1'
        elseif k == 'LANGUAGE' then
          if v == 'en-US' or v == 'pt-BR' then C.language = v end
        end
      end
    end
    file:close()
  end
end
L:set(C.language)

local clock = 0
local rpCutWarnings, rpWarningVersion = nil, 0
local rpChatSubscription
if ac and type(ac.onChatMessage) == 'function' then
  local ok, subscription = pcall(ac.onChatMessage, function(message, senderCarIndex)
    if senderCarIndex == 0 then
      local count, total = tostring(message or ''):lower():match(
        '^%s*rp:cutting warnings:%s*(%d+)%s*/%s*(%d+)%s*$')
      count, total = tonumber(count), tonumber(total)
      if count and total and count >= 1 and total >= 1 and count <= total and total <= 20 then
        rpWarningVersion = rpWarningVersion + 1
        rpCutWarnings = { count = count, total = total, version = rpWarningVersion }
      end
    end
    return false
  end)
  if ok then
    rpChatSubscription = subscription
    script.rpChatSubscription = subscription
  end
end
local lastCoachAt, lastCoachPhrase, coachLapPosition, coachPreviousLapMs = -1e9, nil, nil, nil
local pendingCoach, sessionStartedAt = nil, 0
local lastNoncriticalAt, lastSpotterAt, budgetGroup = -1e9, -1e9, nil
local diagnosticsInitialized = false

local function coachLog(event, phrase, reason, lap, telemetry)
  local function field(value)
    local s = tostring(value or ''):gsub('[\r\n]', ' '):gsub('"', '""')
    return '"' .. s .. '"'
  end
  local ok, file = pcall(io.open, root .. '/sally_diagnostics.csv', 'a')
  if not ok or not file then return end
  if not diagnosticsInitialized then
    local readOK, exists = pcall(io.open, root .. '/sally_diagnostics.csv', 'r')
    local hasData = false
    if readOK and exists then
      local size = exists:seek('end')
      hasData = size ~= nil and size > 0
      exists:close()
    end
    if not hasData then
      pcall(function()
        file:write('sim_time,event,lap,phrase,reason,last_ms,best_ms,previous_ms,position,previous_position\n')
      end)
    end
    diagnosticsInitialized = true
  end
  telemetry = telemetry or {}
  pcall(function()
    file:write(string.format('%.2f,%s,%s,%s,%s,%s,%s,%s,%s,%s\n', clock,
      field(event), field(lap), field(phrase), field(reason), field(telemetry.lastMs),
      field(telemetry.bestMs), field(telemetry.previousMs), field(telemetry.position),
      field(telemetry.previousPosition)))
    file:close()
  end)
end

local dirty, dirtyTimer = false, 0
local function save()
  local ok, file = pcall(io.open, settingsPath, 'w')
  if not ok or not file then return end
  file:write('[SALLY]\n')
  file:write('ENGINEER_VOLUME = ' .. tostring(C.engVol) .. '\n')
  file:write('SPOTTER_VOLUME = ' .. tostring(C.spotVol) .. '\n')
  file:write('BG_VOLUME = ' .. tostring(C.bgVol) .. '\n')
  file:write('SPEED = ' .. tostring(C.speed) .. '\n')
  file:write('PITCH = ' .. tostring(C.pitch) .. '\n')
  file:write('RESERVE = ' .. tostring(C.reserve) .. '\n')
  file:write('SPOTTER = ' .. (C.spotOn and '1' or '0') .. '\n')
  file:write('BEEP = ' .. (C.playBeep and '1' or '0') .. '\n')
  file:write('FLAGS = ' .. (C.warnFlags and '1' or '0') .. '\n')
  file:write('FUEL = ' .. (C.warnFuel and '1' or '0') .. '\n')
  file:write('TYRES = ' .. (C.warnTyres and '1' or '0') .. '\n')
  file:write('DAMAGE = ' .. (C.warnDamage and '1' or '0') .. '\n')
  file:write('SUMMARY = ' .. (C.warnSummary and '1' or '0') .. '\n')
  file:write('BRIEF_EVERY = ' .. tostring(C.briefEvery) .. '\n')
  file:write('FUEL_STATUS_SECONDS = ' .. tostring(C.fuelStatusSeconds) .. '\n')
  file:write('RANTS = ' .. tostring(C.rantLevel) .. '\n')
  file:write('SHOW_AVATAR = ' .. (C.showAvatar and '1' or '0') .. '\n')
  file:write('RACE_COMMENTARY = ' .. (C.raceCommentary and '1' or '0') .. '\n')
  file:write('LANGUAGE = ' .. tostring(C.language) .. '\n')
  file:close()
end
local function markDirty() dirty, dirtyTimer = true, 0 end

------------------------------------------------------------
-- Nucleo
------------------------------------------------------------
local sally = Sally.new(root .. '/audio/sally')
local V = Voice.new(root)
V:setVolume(C.engVol)
V:setSpeed(C.speed)
V:setPitch(C.pitch)
V:setBackgroundVolume(C.bgVol)
V:setBackground(root .. '/audio/sfx/radio_background.wav')
local beepAbs = root .. '/audio/sfx/beep.wav'
do
  local ok, f = pcall(io.open, beepAbs, 'rb')
  if ok and f then f:close() else beepAbs = nil end
end

local strat = Strat.new(C.reserve)
local warner = Warn.new()
local rep = Rep.new(V, sally, C, beepAbs)
local spotOpts = Spot.defaults()
local spotSt = Spot.newState()

local history = {}
local cap = { text = '', speaker = 'SALLY', alpha = 0, target = 0, fade = 0,
  expression = 'neutral', group = nil }
V.onCaption = function(text, speaker, entry)
  history[#history + 1] = { text = text, speaker = speaker }
  while #history > 30 do table.remove(history, 1) end
  cap.text, cap.speaker = L:cap(text) or '', speaker or 'SALLY'
  local expression = Avatar.expressionFor(entry)
  if entry and entry.group ~= nil then
    if cap.group ~= entry.group then
      cap.group, cap.expression = entry.group, expression
    elseif cap.expression == 'neutral' and expression ~= 'neutral' then
      cap.expression = expression
    end
  else
    cap.group, cap.expression = nil, expression
  end
  cap.target = 1
  cap.fade = 0
end
V.onIdle = function() cap.fade = 1.6 end

local dashMsg, dashUntil = nil, 0
local lastS, lastG = nil, nil
local lastToken, lastLap = nil, -1
local prevInPit, prevSpotOn = false, true
local mutedReplay = false
local gapTimer, gapCache = 0, {}
local hitPending, lastCollisionWith, lastHitInfo = nil, -1, nil
local function queueHit(withCar, previous)
  if hitPending then return end
  hitPending = { at = clock, withCar = withCar,
    preDamage = previous and previous.dmgTotal or nil,
    preSpeed = previous and previous.speed or nil,
    preEngineLife = previous and previous.engLife or nil }
end
-- O callback do CSP captura contatos que podem durar apenas poucos frames.
if ac.onCarCollision then
  local ok, subscription = pcall(ac.onCarCollision, 0, function()
    local car = ac.getCar and ac.getCar(0) or nil
    local withCar = -1
    if car then pcall(function() withCar = tonumber(car.collidedWith) or -1 end) end
    queueHit(withCar, lastS)
  end)
  if ok then script._sallyCollisionSubscription = subscription end
end
local spotSeq = { running = false, index = 1, timer = 0,
  lines = { 'car_left', 'still_there', 'clear_left', 'car_right',
    'still_there', 'clear_right', 'three_wide', 'all_clear' } }
local countsCache = nil

local function message(t)
  dashMsg, dashUntil = t, clock + 8
  -- Espelha na caixinha do radio quando ela esta livre.
  if not V:isBusy() then
    cap.text, cap.speaker = L:cap(tostring(t or '')), 'SALLY'
    cap.expression, cap.group = 'neutral', nil
    cap.target = 1
    cap.fade = 3
  end
end

V.gate = function(entry)
  if not C.voiceOn or not C.radioOn then return false end
  local priority = tonumber(entry.priorityValue) or 20
  if priority >= 70 then return true end
  if clock - sessionStartedAt < 25 or clock - lastSpotterAt < 2 then return false end
  if not lastS or not Tele.isCalm(lastS) then return false end
  if entry.group and entry.group == budgetGroup then return true end
  if clock - lastNoncriticalAt < 25 then return false end
  budgetGroup = entry.group
  return true
end
V.onEntryStart = function(entry)
  if (tonumber(entry.priorityValue) or 20) < 70 then lastNoncriticalAt = clock end
end

------------------------------------------------------------
-- Fala do spotter
------------------------------------------------------------
local SPOT_SALLY = {
  car_left = 'car_left', car_right = 'car_right', still_there = 'still_there',
  clear_left = 'clear_left', clear_right = 'clear_right',
  all_clear = 'clear_all_round', three_wide = { 'in_the_middle', 'hold_your_line' },
  three_wide_on_left = 'three_wide_on_left', three_wide_on_right = 'three_wide_on_right',
}
local SPOT_CAP = { car_left = 'Carro à esquerda', car_right = 'Carro à direita',
  still_there = 'Ainda ao lado', clear_left = 'Esquerda livre', clear_right = 'Direita livre',
  all_clear = 'Tudo livre', three_wide = 'Três lado a lado', three_wide_on_left = 'Três, você à esquerda',
  three_wide_on_right = 'Três, você à direita' }

local function spotSay(line, test)
  if mutedReplay or not C.voiceOn then return false end
  if not test and not C.radioOn then return false end
  local phrase = SPOT_SALLY[line] or line
  if type(phrase) == 'table' then phrase = phrase[math.random(1, #phrase)] end
  local path = sally:clip('spotter', phrase)
  if not path and phrase ~= line then path = sally:clip('spotter', line) end
  if not path then return false end
  local clear = line == 'clear_left' or line == 'clear_right' or line == 'all_clear'
  V:interruptWith(path, SPOT_CAP[line] or line, 'SPOTTER',
    C.spotVol * C.master, clear, { group = 'spotter', ttl = 2, key = line })
  lastSpotterAt = clock
  return true
end

------------------------------------------------------------
-- Acoes (controles restantes: tudo automatico, sem botoes manuais)
------------------------------------------------------------
local SPOT_LINES = { 'car_left', 'car_right', 'still_there', 'clear_left',
  'clear_right', 'all_clear', 'three_wide', 'three_wide_on_left', 'three_wide_on_right' }
local function validSpot(line)
  for _, l in ipairs(SPOT_LINES) do if l == line then return true end end
  return false
end

local A = {}
function A.paused() return not C.radioOn end
function A.toggleRadio()
  C.radioOn = not C.radioOn
  if not C.radioOn then V:clear() end
  message(C.radioOn and L:t('radio.now_on') or L:t('radio.now_off'))
end
function A.tRadio()
  -- Teste da settings: fura a pausa, entra na fila com prioridade.
  if mutedReplay or not C.voiceOn or not sally:available() then return false end
  rep.api.manual()
  rep.api.started('testradio')
  local path = sally:clip('radio_check', 'test')
  if path then
    local vol = C.engVol * C.master
    if C.playBeep and beepAbs then
      V:enqueue(beepAbs, nil, nil, { beep = true, vol = vol, group = rep.api.group,
        ttl = 18, priorityValue = 60 })
    end
    V:enqueue(path, 'Radio check', 'SALLY', { vol = vol, group = rep.api.group,
      ttl = 18, priorityValue = 60, key = rep.api.group })
    message(L:t('msg.testradio'))
  end
  rep.api.done()
  return true
end
function A.spotTest(line)
  if validSpot(line) and spotSay(line, true) then message(L:t('msg.spot') .. line) end
end
function A.spotSeq()
  spotSeq.running = not spotSeq.running
  spotSeq.index, spotSeq.timer = 1, 0
  if not spotSeq.running then V:clear() end
end
function A.clearQueue() V:clear() end
local function maybeCoachCommentary(S, previousLapMs, previousLapPosition, lapCompleted,
    allSectorsGood, paceTrendMs)
  local supportedSession = S.sessType == 1 or S.sessType == 2 or S.sessType == 3
  if lapCompleted and not pendingCoach and C.raceCommentary and C.radioOn and C.voiceOn
      and not mutedReplay and supportedSession and S.lastValid == true then
    local selected = Coach.select(sally, S, previousLapMs, previousLapPosition,
      allSectorsGood, paceTrendMs)
    if selected then
      pendingCoach = { selected = selected, lap = S.lap or 0,
        expiresAt = clock + 25, queued = false,
        telemetry = { lastMs = S.lastMs, bestMs = S.bestMs,
          previousMs = previousLapMs, position = S.pos,
          previousPosition = previousLapPosition } }
      coachLog('selected', selected.phrase, selected.category, S.lap, pendingCoach.telemetry)
    end
  end

  local pending = pendingCoach
  if not pending then return end
  if clock >= pending.expiresAt then
    coachLog('expired', pending.selected.phrase, 'retry_window', pending.lap, pending.telemetry)
    pendingCoach = nil
    return
  end
  if not C.raceCommentary or not C.radioOn or not C.voiceOn or mutedReplay
      or S.inPit or S.finished or not supportedSession then return end
  if pending.queued or clock - lastCoachAt < 20 or V:isBusy()
      or V:isBusyAtOrAbove(70) or clock - lastSpotterAt < 2
      or clock - sessionStartedAt < 25 or not Tele.isCalm(S) then return end

  local selected = pending.selected
  local path = sally:clip(selected.category, selected.phrase)
  if not path then
    coachLog('missing_clip', selected.phrase, selected.category, pending.lap, pending.telemetry)
    pendingCoach = nil
    return
  end
  local caption = L:cap(selected.transcript) or selected.transcript
  pending.queued = true
  local queued = V:enqueue(path, caption, 'SALLY', {
    vol = C.engVol * C.master, group = 'coach:' .. tostring(pending.lap),
    ttl = math.max(0.1, pending.expiresAt - clock), priorityValue = 30,
    key = selected.category .. '/' .. selected.phrase,
    onOutcome = function(state, reason)
      if state == 'started' then
        lastCoachAt, lastCoachPhrase = clock, selected.phrase
        coachLog('started', selected.phrase, selected.category, pending.lap, pending.telemetry)
        if pendingCoach == pending then pendingCoach = nil end
      elseif state == 'finished' then
        coachLog('finished', selected.phrase, selected.category, pending.lap, pending.telemetry)
      else
        coachLog(state, selected.phrase, reason, pending.lap, pending.telemetry)
        pending.queued = false
        if state == 'dropped' and reason == 'expired' and pendingCoach == pending then
          pendingCoach = nil
        end
      end
    end,
  })
  if queued then coachLog('queued', selected.phrase, selected.category, pending.lap, pending.telemetry)
  else pending.queued = false end
end
function A.catalog(cat, phrase)
  -- Teste: fura a pausa do radio (mas respeita replay e voz desligada).
  if mutedReplay or not C.voiceOn or not sally:available() then return end
  rep.api.manual()
  rep.api.started('catalog')
  local path = sally:clip(cat, phrase)
  if path then
    local vol = C.engVol * C.master
    if C.playBeep and beepAbs then
      V:enqueue(beepAbs, nil, nil, { beep = true, vol = vol, group = rep.api.group,
        ttl = 18, priorityValue = 50 })
    end
    V:enqueue(path, phrase:gsub('_', ' '), 'SALLY', { vol = vol,
      group = rep.api.group, ttl = 18, priorityValue = 50, key = rep.api.group })
    message(L:t('msg.playing') .. cat .. '/' .. phrase)
  end
  rep.api.done()
end
function A.applyVolumes()
  V:setVolume(C.engVol)
  V:setSpeed(C.speed)
  V:setPitch(C.pitch)
  V:setBackgroundVolume(C.bgVol * C.master)
  markDirty()
end
function A.save() markDirty() end

------------------------------------------------------------
-- Loop
------------------------------------------------------------
local function resetAll(reason)
  rpCutWarnings, rpWarningVersion = nil, 0
  strat:reset(C.reserve)
  warner:reset()
  spotSt = Spot.newState()
  history = {}
  V:clear()
  cap.text, cap.speaker = '', 'SALLY'
  cap.expression, cap.group = 'neutral', nil
  cap.alpha, cap.target, cap.fade = 0, 0, 0
  lastLap = -1
  prevInPit = false
  hitPending, lastCollisionWith, lastHitInfo = nil, -1, nil
  pendingCoach = nil
  lastCoachAt, lastCoachPhrase, coachLapPosition, coachPreviousLapMs = -1e9, nil, nil, nil
  sessionStartedAt, lastNoncriticalAt, lastSpotterAt, budgetGroup = clock, -1e9, -1e9, nil
end

function script.update(dt) updateApp(dt) end
function updateApp(dt)
  dt = math.max(0, tonumber(dt) or 0)
  clock = clock + dt
  local sim = ac.getSim and ac.getSim() or nil
  local replaying = false
  pcall(function() replaying = sim and sim.isReplayActive == true end)
  if replaying then
    if not mutedReplay then
      mutedReplay = true
      hitPending, lastCollisionWith = nil, -1
      V:clear()
      cap.text, cap.speaker = '', 'SALLY'
      cap.expression, cap.group = 'neutral', nil
      cap.alpha, cap.target, cap.fade = 0, 0, 0
      spotSt = Spot.newState()
    end
    if dirty then
      dirtyTimer = dirtyTimer + dt
      if dirtyTimer > 1 then dirty = false; save() end
    end
    return
  elseif mutedReplay then
    mutedReplay = false
    resetAll('replay end')
  end
  if sim and sim.isPaused then hitPending = nil; return end

  V:update(dt)
  local S = Tele.snap()
  local previousS = lastS
  lastS = S
  if not S then return end

  -- Fallback por transicao de collidedWith caso o callback nao seja emitido.
  local collidedWith = S.collidedWith or -1
  if collidedWith >= 0 and lastCollisionWith < 0 then
    queueHit(collidedWith, previousS)
  end
  lastCollisionWith = collidedWith
  if hitPending and clock - hitPending.at >= 0.12 then
    S.hit = { withCar = hitPending.withCar,
      damageDelta = math.max(0, (S.dmgTotal or 0) - (hitPending.preDamage or S.dmgTotal or 0)),
      speedDrop = math.max(0, (hitPending.preSpeed or S.speed or 0) - (S.speed or 0)),
      impactSpeed = hitPending.preSpeed or S.speed or 0,
      engineLost = hitPending.preEngineLife ~= nil and hitPending.preEngineLife > 0
        and S.engLife ~= nil and S.engLife <= 0 }
    lastHitInfo = { at = clock, data = S.hit }
    hitPending = nil
  end

  -- Troca de sessao: reset total. Volta para tras: reset leve.
  local token = Tele.token(S)
  if lastToken == nil then
    sessionStartedAt = clock
  elseif token ~= lastToken then
    resetAll('session')
    S.hit = nil
  elseif lastLap >= 0 and (S.lap or 0) < lastLap then
    resetAll('restart')
    S.hit = nil
  end
  lastToken = token
  S.rpCutWarnings = rpCutWarnings

  local lapCompleted = lastLap >= 0 and (S.lap or 0) > lastLap
  if coachLapPosition == nil then coachLapPosition = S.pos end
  local previousLapPosition, previousLapMs
  if lapCompleted then
    previousLapPosition, coachLapPosition = coachLapPosition, S.pos
    previousLapMs = coachPreviousLapMs
    if S.lastValid == true and S.lastMs then coachPreviousLapMs = S.lastMs end
  end

  -- Fecha volta antes de rastrear setores da nova.
  if lapCompleted then strat:closeLap(S) end
  if prevInPit and not S.inPit then strat:pitExit(S.lap or 0) end
  prevInPit = S.inPit
  lastLap = S.lap or 0
  strat:trackSectors(dt, S)
  local G = strat:update(S)
  lastG = G

  -- Gaps atualizados 4x por segundo (segundos, metros, vel. do rival).
  gapTimer = gapTimer + dt
  if gapTimer >= 0.25 then
    gapTimer = 0
    gapCache.ahead, gapCache.aheadM, gapCache.aheadV = Tele.gapAhead()
    gapCache.behind = Tele.gapBehind()
    gapCache.leader = Tele.gapTo(1)
  end

  -- Spotter.
  spotOpts.enabled = C.spotOn
  spotOpts.minSpeed = C.minSpeed
  Spot.update(spotSt, dt, Spot.frame(), spotOpts, spotSay)
  if C.spotOn ~= prevSpotOn then
    prevSpotOn = C.spotOn
    if sally:available() and C.voiceOn and not mutedReplay then
      rep.api.started('spottoggle')
      rep.api.say('acknowledge', C.spotOn and 'spotterEnabled' or 'spotterDisabled',
        C.spotOn and 'Spotter ligado' or 'Spotter desligado', {})
      rep.api.done()
    end
  end

  -- Avisos automaticos (secondary respeita o gate de curva via prioridade).
  if C.radioOn and C.voiceOn then
    warner:update(dt, S, G, rep.api, C, clock, gapCache, Tele.isCalm(S),
      spotSt.nearby or 0, (spotSt.left or 0) > 0 or (spotSt.right or 0) > 0)
  end
  maybeCoachCommentary(S, previousLapMs, previousLapPosition, lapCompleted,
    G.lastAllGood, G.paceTrendMs)

  -- Sequencia de teste do spotter.
  if spotSeq.running then
    spotSeq.timer = spotSeq.timer - dt
    if spotSeq.timer <= 0 then
      local line = spotSeq.lines[spotSeq.index]
      if not line then spotSeq.running, spotSeq.index = false, 1
      else spotSay(line); spotSeq.index = spotSeq.index + 1; spotSeq.timer = 2 end
    end
  end

  -- Legenda: some quando o radio esvazia.
  if cap.alpha < cap.target then cap.alpha = math.min(cap.target, cap.alpha + dt * 6)
  elseif cap.alpha > cap.target then cap.alpha = math.max(cap.target, cap.alpha - dt * 6) end
  if cap.alpha <= 0.01 and cap.target == 0 then cap.text = '' end
  if cap.target > 0 and not V:isBusy() then
    cap.fade = (cap.fade or 0) - dt
    if cap.fade <= 0 then cap.target = 0 end
  end

  if dirty then
    dirtyTimer = dirtyTimer + dt
    if dirtyTimer > 1 then dirty = false; save() end
  end
end

------------------------------------------------------------
-- Janelas
------------------------------------------------------------
function script.windowMain(dt) windowMain(dt) end
function windowMain(dt)
  local playing = V.playing and V.playing.entry
  local frames = avatarFrames and (avatarFrames[cap.expression] or avatarFrames.neutral)
  UI.box({ text = cap.text, speaker = cap.speaker, alpha = cap.alpha,
    talking = playing ~= nil and not playing.isBeep and playing.speaker == 'SALLY',
    animationTime = clock, avatarIdle = frames and frames.idle,
    avatarTalking = frames and frames.talking },
    C, spotSt, L)
end

function script.windowDashboard(dt) windowDashboard(dt) end
function windowDashboard(dt)
  local msg = clock < dashUntil and dashMsg or nil
  UI.dash(lastS or {}, lastG or strat.state, spotSt, C, A, history, msg, L,
    { hit = lastHitInfo, now = clock })
end

function script.windowMainSettings(dt) windowMainSettings(dt) end
function windowMainSettings(dt)
  if not countsCache then
    -- So conta pastas (rapido). Contar os 27 mil wavs travava a abertura.
    local phrases = 0
    for _, cat in ipairs(sally:categories()) do
      phrases = phrases + #sally:phrases(cat)
    end
    countsCache = { phrases = phrases }
  end
  UI.settings(C, A, sally, V, spotSt, countsCache,
    { S = lastS, G = lastG, hit = lastHitInfo, now = clock }, L, avatarFrames)
end
