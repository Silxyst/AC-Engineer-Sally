-- Interface: radio, race hub and settings. Uses the standard CSP ui.* API.

local UI = {}
local catIdx, phraseIdx = 1, 1

local PALETTE = {
  text = rgbm(0.94, 0.96, 1, 1),
  muted = rgbm(0.58, 0.64, 0.71, 1),
  gold = rgbm(1.00, 0.80, 0.22, 1),
  cyan = rgbm(0.27, 0.76, 0.95, 1),
  green = rgbm(0.35, 0.86, 0.60, 1),
  red = rgbm(1.00, 0.34, 0.30, 1),
  amber = rgbm(1.00, 0.73, 0.25, 1),
}

local function fmt(v, pattern, fallback)
  v = tonumber(v)
  if v and v == v and v ~= math.huge and v ~= -math.huge then
    return string.format(pattern, v)
  end
  return fallback or '--'
end

local function lapTime(ms, L)
  ms = tonumber(ms)
  if not ms or ms <= 0 then return '--:--.---' end
  local total = math.floor(ms + 0.5)
  local pat = (L and L:t('unit.laptime')) or '%d:%02d.%03d'
  return string.format(pat, math.floor(total / 60000), math.floor(total / 1000) % 60, total % 1000)
end

local function section(title, L, detail)
  ui.dummy(vec2(0, 3))
  ui.textColored(title, PALETTE.gold)
  if detail then
    ui.sameLine()
    ui.textColored(detail, PALETTE.muted)
  end
  ui.separator()
end

local function card(id, label, value, detail, color, w, h)
  ui.pushStyleColor(ui.StyleColor.ChildBg, rgbm(0.055, 0.075, 0.10, 0.96))
  ui.pushStyleColor(ui.StyleColor.Border, rgbm(0.20, 0.25, 0.32, 0.85))
  ui.pushStyleVar(ui.StyleVar.ChildBorderSize, 1)
  ui.beginChild(id, vec2(w, h or 78), true)
  ui.dummy(vec2(0, 2))
  ui.textColored(label, PALETTE.muted)
  ui.pushFont(ui.Font.Title)
  ui.textColored(value, color or PALETTE.text)
  ui.popFont()
  if detail and detail ~= '' then ui.textColored(detail, PALETTE.muted) end
  ui.endChild()
  ui.popStyleVar()
  ui.popStyleColor(2)
end

local function pair(a, b)
  local w = math.max(140, (ui.availableSpace().x - 10) / 2)
  card(a[1], a[2], a[3], a[4], a[5], w, a[6])
  ui.sameLine()
  card(b[1], b[2], b[3], b[4], b[5], w, b[6])
end

local function controlRow(a, b)
  if a then
    if ui.checkbox(a.label, a.value) then a.change(not a.value) end
  end
  if b then
    if a then ui.sameLine() end
    if ui.checkbox(b.label, b.value) then b.change(not b.value) end
  end
end

local function sliderRow(id, value, min, max, label, changed)
  local nextValue = ui.slider(id, value, min, max, label)
  if nextValue ~= value then changed(nextValue) end
end

local function spotState(st, enabled, L)
  st = st or {}
  local text, color = L:t('spot.free'), PALETTE.green
  if not enabled then text, color = L:t('spot.off'), PALETTE.muted
  elseif not st.active then text, color = L:t('spot.wait'), PALETTE.muted
  elseif (st.left or 0) > 0 and (st.right or 0) > 0 then text, color = L:t('spot.both'), PALETTE.red
  elseif (st.left or 0) > 0 then text, color = L:t('spot.left'), PALETTE.amber
  elseif (st.right or 0) > 0 then text, color = L:t('spot.right'), PALETTE.amber end
  return text, color
end

local function penaltyState(kind, L)
  if kind == nil then return L:t('dash.penalty_na'), PALETTE.muted end
  if kind == 0 then return L:t('dash.penalty_none'), PALETTE.green end
  if kind == 1 then return L:t('dash.penalty_pits'), PALETTE.amber end
  if kind == 2 then return L:t('dash.penalty_return'), PALETTE.red end
  if kind == 3 then return L:t('dash.penalty_slow'), PALETTE.amber end
  if kind == 4 then return L:t('dash.penalty_black'), PALETTE.red end
  if kind == 5 then return L:t('dash.penalty_cleared'), PALETTE.green end
  return L:t('dash.penalty_unknown'), PALETTE.amber
end

-- Compact radio window: idle state remains recognizable; active calls lead.
function UI.box(cap, C, st, L)
  local alpha = cap.alpha or 0
  local size = ui.windowSize()
  local active = alpha > 0.01
  local showAvatar = active and C.showAvatar and cap.speaker == 'SALLY' and cap.avatarIdle
  local accent = active and rgbm(C.accR, C.accG, C.accB, alpha) or PALETTE.gold
  local spotText, spotColor = spotState(st, C.spotOn, L)

  ui.pushStyleColor(ui.StyleColor.ChildBg, rgbm(0.035, 0.045, 0.065, active and 0.96 or 0.90))
  ui.pushStyleColor(ui.StyleColor.Border, active and accent or rgbm(0.20, 0.25, 0.32, 0.9))
  ui.pushStyleVar(ui.StyleVar.ChildBorderSize, active and 2 or 1)
  ui.beginChild('sallyRadioCard', vec2(size.x - 12, 0), true)

  if showAvatar then
    local speakingFrame = cap.talking and math.floor((cap.animationTime or 0) * 6) % 2 == 0
    ui.image(speakingFrame and cap.avatarTalking or cap.avatarIdle,
      vec2(96, 96), rgbm(1, 1, 1, alpha))
    ui.sameLine()
    ui.beginChild('sallyRadioText', vec2(0, 0), false)
  end

  ui.textColored(active and (cap.speaker or 'SALLY') or 'AC ENGINEER SALLY', active and PALETTE.text or PALETTE.gold)
  ui.sameLine()
  if C.radioOn then ui.textColored('● LIVE', PALETTE.green)
  else ui.textColored(L and L:t('radio.paused_short') or 'PAUSED', PALETTE.muted) end

  if active then
    ui.dummy(vec2(0, 3))
    ui.pushStyleColor(ui.StyleColor.Text, rgbm(1, 1, 1, alpha))
    ui.pushFont(ui.Font.Main)
    ui.textWrapped('“' .. (cap.text or '') .. '”')
    ui.popFont()
    ui.popStyleColor()
  else
    ui.separator()
    ui.textColored(spotText, spotColor)
  end

  if showAvatar then ui.endChild() end
  ui.endChild()
  ui.popStyleVar()
  ui.popStyleColor(2)
end

-- Race hub: high-priority status, glanceable metrics, tyres and recent radio.
function UI.dash(S, G, st, C, A, history, message, L, diag)
  S, G, st = S or {}, G or {}, st or {}
  local pos = S.pos and ('P' .. tostring(S.pos)) or 'P--'
  local lapShow = (tonumber(S.lap) or 0) + 1
  local lapsTotal = G.totalLaps and G.totalLaps > 0 and ('/' .. G.totalLaps) or ''

  ui.pushFont(ui.Font.Title)
  ui.textColored(L:t('dash.title'), PALETTE.text)
  ui.popFont()
  ui.textColored(L:t('dash.subtitle'), PALETTE.muted)

  ui.pushStyleColor(ui.StyleColor.ChildBg, rgbm(0.055, 0.075, 0.10, 0.96))
  ui.pushStyleColor(ui.StyleColor.Border, rgbm(0.20, 0.25, 0.32, 0.85))
  ui.pushStyleVar(ui.StyleVar.ChildBorderSize, 1)
  ui.beginChild('raceStatus', vec2(ui.availableSpace().x, 88), true)
  ui.pushFont(ui.Font.Title)
  ui.textColored(pos, PALETTE.gold)
  ui.popFont()
  ui.sameLine()
  ui.textColored(string.format(L:t('dash.lap'), lapShow, lapsTotal), PALETTE.text)
  if S.replay then
    ui.textColored(L:t('dash.replay'), PALETTE.amber)
  elseif S.paused then
    ui.textColored(L:t('dash.paused'), PALETTE.amber)
  elseif S.timeLeftS and S.timeLeftS > 0 then
    local mm, ss = math.floor(S.timeLeftS / 60), math.floor(S.timeLeftS % 60)
    ui.textColored(string.format(L:t('dash.clock'), mm, ss), PALETTE.muted)
  elseif S.finished then
    ui.textColored(L:t('dash.finished'), PALETTE.green)
  elseif S.started then
    ui.textColored(L:t('dash.live'), PALETTE.muted)
  else
    ui.textColored(L:t('dash.waiting'), PALETTE.muted)
  end
  local spotText, spotColor = spotState(st, C.spotOn, L)
  ui.sameLine()
  ui.textColored('● ' .. spotText, spotColor)
  ui.endChild()
  ui.popStyleVar()
  ui.popStyleColor(2)

  ui.dummy(vec2(0, 3))
  local buttonLabel = A.paused() and L:t('radio.on') or L:t('radio.off')
  if ui.button(buttonLabel) then A.toggleRadio() end
  ui.sameLine()
  ui.textColored(A.paused() and L:t('dash.radio_paused') or L:t('dash.radio_live'),
    A.paused() and PALETTE.muted or PALETTE.green)

  section(L:t('dash.strategy'), L)
  local fuelShort = (G.need or 0) > 0.1
  local fuelColor = fuelShort and PALETTE.red or PALETTE.cyan
  local consDetail = G.perLap and string.format(L:t('unit.cons'), G.perLap, G.samples or 0)
    or L:t('unit.cons_wait')
  local rangeDetail = (G.need or 0) > 0.1
    and string.format(L:t('card.short'), G.need)
    or string.format(L:t('card.margin'), G.margin or 0)
  pair(
    { 'fuel', L:t('card.fuel'), fmt(G.fuel, L:t('unit.fuel_l')), consDetail, fuelColor },
    { 'range', L:t('card.range'), fmt(G.range, L:t('unit.laps1')), rangeDetail,
      fuelShort and PALETTE.red or PALETTE.green }
  )
  pair(
    { 'remaining', L:t('card.remaining'), fmt(G.remaining, L:t('unit.laps0')),
      G.timed and L:t('card.timed') or L:t('card.bylaps'), PALETTE.text },
    { 'lapTimes', L:t('card.lastbest'), lapTime(G.lastMs, L),
      L:t('card.best') .. lapTime(G.bestMs, L), PALETTE.green }
  )

  section(L:t('tyres.title'), L, S.compoundName)
  local labels = { L:t('tyre.fl'), L:t('tyre.fr'), L:t('tyre.rl'), L:t('tyre.rr') }
  local width = math.max(70, (ui.availableSpace().x - 24) / 4)
  for i = 1, 4 do
    local wheel = S.wheels and S.wheels[i]
    local temp = wheel and wheel.temp or nil
    local color = PALETTE.text
    if temp then
      if temp > 95 then color = PALETTE.red
      elseif temp < 70 then color = PALETTE.cyan
      else color = PALETTE.green end
    end
    if i > 1 then ui.sameLine() end
    local detail = wheel and wheel.psi and string.format(L:t('unit.psi'), wheel.psi) or '--'
    card('wheel' .. i, labels[i], fmt(temp, L:t('unit.temp')), detail, color, width, 72)
  end
  local stint = G.stintLaps and string.format(L:t('unit.laps0'), G.stintLaps) or '--'
  ui.textColored(L:t('dash.stint') .. stint, PALETTE.muted)
  if S.kersMax then
    ui.sameLine()
    ui.textColored(L:t('tyres.ers') .. string.format('%.0f%%', S.kersPct or 0), PALETTE.cyan)
  end

  section(L:t('dash.vehicle'), L)
  local penalty, penaltyColor = penaltyState(S.penaltyType, L)
  local hitDetail = L:t('dash.hit_none')
  if diag and diag.hit and diag.hit.data and (diag.now or 0) - diag.hit.at < 120 then
    local hit = diag.hit.data
    hitDetail = string.format(L:t('dash.hit'), hit.damageDelta or 0, hit.speedDrop or 0)
  end
  pair(
    { 'damage', L:t('dash.damage'), fmt(S.dmgTotal, '%.1f'), hitDetail,
      (S.dmgTotal or 0) >= 30 and PALETTE.red or ((S.dmgTotal or 0) > 0 and PALETTE.amber or PALETTE.green) },
    { 'penalty', L:t('dash.penalty'), penalty, L:t('dash.penalty_detail'), penaltyColor }
  )

  section(L:t('history.title'), L)
  if not history or #history == 0 then
    ui.textColored(L:t('history.empty'), PALETTE.muted)
  else
    local first = math.max(1, #history - 2)
    for i = #history, first, -1 do
      local entry = history[i]
      ui.textColored(tostring(entry.speaker or 'SALLY'), entry.speaker == 'SPOTTER' and PALETTE.gold or PALETTE.cyan)
      ui.sameLine()
      ui.textWrapped(entry.text or '')
    end
  end
  if message then
    ui.separator()
    ui.textColored(message, PALETTE.gold)
  end
end

-- Settings grouped by task: language/audio, tests, alerts and phrase catalog.
function UI.settings(C, A, sally, V, st, counts, diag, L, avatarFrames)
  ui.pushFont(ui.Font.Title)
  ui.textColored(L:t('app.name'), PALETTE.gold)
  ui.popFont()
  ui.textColored(sally:available() and L:t('set.voice_ready') or L:t('set.voice_missing'),
    sally:available() and PALETTE.green or PALETTE.red)

  section(L:t('set.section_radio'), L)
  ui.text(L:t('set.lang'))
  ui.sameLine()
  if ui.button('Português' .. (C.language == 'pt-BR' and ' ✓' or '')) and C.language ~= 'pt-BR' then
    C.language = 'pt-BR'; L:set('pt-BR'); A.save()
  end
  ui.sameLine()
  if ui.button('English' .. (C.language == 'en-US' and ' ✓' or '')) and C.language ~= 'en-US' then
    C.language = 'en-US'; L:set('en-US'); A.save()
  end

  sliderRow('##eng', C.engVol / 50 * 100, 0, 100, L:t('set.eng'), function(value)
    C.engVol = value / 100 * 50; A.applyVolumes()
  end)
  sliderRow('##spot', C.spotVol / 50 * 100, 0, 100, L:t('set.spot'), function(value)
    C.spotVol = value / 100 * 50; A.applyVolumes()
  end)
  sliderRow('##bg', C.bgVol, 0, 8, L:t('set.bg'), function(value)
    C.bgVol = value; A.applyVolumes()
  end)
  sliderRow('##spd', C.speed, 0.75, 1.75, L:t('set.speed'), function(value)
    C.speed = value; A.applyVolumes()
  end)
  sliderRow('##pit', C.pitch, 0.75, 1.25, L:t('set.pitch'), function(value)
    C.pitch = value; A.applyVolumes()
  end)
  controlRow(
    { label = L:t('set.beep'), value = C.playBeep, change = function(v) C.playBeep = v; A.save() end },
    { label = L:t('set.spoton'), value = C.spotOn, change = function(v) C.spotOn = v; A.save() end }
  )
  if ui.checkbox(L:t('set.avatar'), C.showAvatar) then
    C.showAvatar = not C.showAvatar
    A.save()
  end
  if avatarFrames then
    ui.textColored(L:t('set.avatar_preview'), PALETTE.muted)
    local previews = {
      { 'neutral', 'avatar.neutral' },
      { 'angry', 'avatar.angry' },
      { 'focused', 'avatar.focused' },
      { 'concerned', 'avatar.concerned' },
      { 'happy', 'avatar.happy' },
      { 'furious', 'avatar.furious' },
      { 'sarcastic', 'avatar.sarcastic' },
      { 'surprised', 'avatar.surprised' },
      { 'relieved', 'avatar.relieved' },
      { 'determined', 'avatar.determined' },
    }
    for i, preview in ipairs(previews) do
      local frame = avatarFrames[preview[1]]
      if frame and frame.idle then
        ui.beginChild('sallyAvatarPreview' .. preview[1], vec2(70, 86), false)
        ui.textColored(L:t(preview[2]), PALETTE.text)
        ui.image(frame.idle, vec2(64, 64), rgbm(1, 1, 1, 1))
        ui.endChild()
        if i < #previews and i % 5 ~= 0 then ui.sameLine() end
      end
    end
  end

  section(L:t('set.commentary_section'), L, L:t('set.commentary_note'))
  if ui.checkbox(L:t('set.commentary_enabled'), C.raceCommentary) then
    C.raceCommentary = not C.raceCommentary
    A.save()
  end

  section(L:t('set.tests'), L, L:t('set.tests_note'))
  if ui.button(L:t('set.t_radio')) then A.tRadio() end
  ui.sameLine()
  if ui.button(L:t('set.t_left')) then A.spotTest('car_left') end
  ui.sameLine()
  if ui.button(L:t('set.t_clear')) then A.spotTest('all_clear') end
  if ui.button(L:t('set.t_seq')) then A.spotSeq() end
  ui.sameLine()
  if ui.button(L:t('set.t_clearq')) then A.clearQueue() end

  local spotText, spotColor = spotState(st, C.spotOn, L)
  ui.textColored(L:t('set.spotst') .. spotText .. '  L:' .. (st.left or 0) .. '  R:' .. (st.right or 0), spotColor)
  if st.lastCall and st.lastCall ~= '' then ui.textColored(L:t('set.last') .. st.lastCall, PALETTE.muted) end
  if diag and diag.S then
    local S, G = diag.S, diag.G or {}
    ui.textColored(L:t('set.telemetry'), PALETTE.muted)
    ui.text(L:t('set.t_fuel') .. fmt(S.fuel, L:t('unit.fuel_l')) .. L:t('set.t_cons')
      .. fmt(G.perLap, L:t('unit.cons_short')))
    ui.text(L:t('set.t_dmg') .. fmt(S.dmgTotal, '%.1f') .. L:t('set.t_pen')
      .. (S.penaltyType == nil and L:t('set.t_na') or tostring(S.penaltyType)))
    if diag.hit and diag.hit.data and (diag.now or 0) - diag.hit.at < 120 then
      local hit = diag.hit.data
      ui.textColored(string.format(L:t('set.t_hit'), hit.damageDelta or 0, hit.speedDrop or 0), PALETTE.amber)
    end
  end

  section(L:t('set.section_alerts'), L)
  controlRow(
    { label = L:t('set.wflags'), value = C.warnFlags, change = function(v) C.warnFlags = v; A.save() end },
    { label = L:t('set.wfuel'), value = C.warnFuel, change = function(v) C.warnFuel = v; A.save() end }
  )
  controlRow(
    { label = L:t('set.wtyres'), value = C.warnTyres, change = function(v) C.warnTyres = v; A.save() end },
    { label = L:t('set.wdamage'), value = C.warnDamage, change = function(v) C.warnDamage = v; A.save() end }
  )
  if ui.checkbox(L:t('set.wsummary'), C.warnSummary) then
    C.warnSummary = not C.warnSummary; A.save()
  end
  if C.warnSummary then
    sliderRow('##briefEvery', C.briefEvery, 1, 5, L:t('set.every'), function(value)
      C.briefEvery = math.floor(value + 0.5); A.save()
    end)
  end
  if C.warnFuel then
    sliderRow('##fuelStatus', C.fuelStatusSeconds, 60, 300, L:t('set.fuelsec'), function(value)
      C.fuelStatusSeconds = math.floor(value + 0.5); A.save()
    end)
  end
  sliderRow('##res', C.reserve, 0.25, 3, L:t('set.reserve'), function(value)
    C.reserve = value; A.save()
  end)
  sliderRow('##rants', C.rantLevel, 0, 3, L:t('set.rants'), function(value)
    C.rantLevel = math.floor(value + 0.5); A.save()
  end)

  section(L:t('set.catalog'), L, counts and (tostring(counts.phrases) .. L:t('set.clips2')) or nil)
  local cats = sally:categories()
  if #cats == 0 then
    ui.textColored(L:t('set.nocat'), PALETTE.muted)
  else
    catIdx = math.max(1, math.min(#cats, catIdx))
    if ui.button(L:t('set.folder') .. cats[catIdx] .. '  (' .. catIdx .. '/' .. #cats .. ')') then
      catIdx = catIdx % #cats + 1
      phraseIdx = 1
    end
    local phrases = sally:phrases(cats[catIdx])
    if #phrases > 0 then
      phraseIdx = math.max(1, math.min(#phrases, phraseIdx))
      if ui.button(L:t('set.phrase') .. phrases[phraseIdx]) then
        phraseIdx = phraseIdx % #phrases + 1
      end
      ui.sameLine()
      if ui.button(L:t('set.play')) then A.catalog(cats[catIdx], phrases[phraseIdx]) end
      ui.sameLine()
      if ui.button(L:t('set.random')) then
        phraseIdx = math.random(1, #phrases)
        A.catalog(cats[catIdx], phrases[phraseIdx])
      end
      local transcript = sally:transcript(cats[catIdx], phrases[phraseIdx])
      if transcript then
        ui.pushStyleColor(ui.StyleColor.ChildBg, rgbm(0.055, 0.075, 0.10, 0.96))
        ui.beginChild('catalogTranscript', vec2(ui.availableSpace().x, 48), true)
        ui.textColored('“' .. transcript .. '”', PALETTE.text)
        ui.endChild()
        ui.popStyleColor()
      end
    end
  end
end

return UI
