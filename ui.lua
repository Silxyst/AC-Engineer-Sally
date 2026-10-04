-- Interface: caixa do radio, central de corrida e ajustes. So usa ui.* do CSP.

local UI = {}
local catIdx, phraseIdx = 1, 1

local function fmt(v, pattern, fallback)
  v = tonumber(v)
  if v and v == v and v ~= math.huge and v ~= -math.huge then return string.format(pattern, v) end
  return fallback or '--'
end

local function lapTime(ms, L)
  ms = tonumber(ms)
  if not ms or ms <= 0 then return '--:--.---' end
  local total = math.floor(ms + 0.5)
  local pat = (L and L:t('unit.laptime')) or '%d:%02d.%03d'
  return string.format(pat, math.floor(total / 60000), math.floor(total / 1000) % 60, total % 1000)
end

local function card(id, label, value, detail, color, w)
  ui.pushStyleColor(ui.StyleColor.ChildBg, rgbm(0.055, 0.075, 0.10, 0.95))
  ui.beginChild(id, vec2(w, 78), true)
  ui.textColored(label, rgbm(0.58, 0.64, 0.71, 1))
  ui.pushFont(ui.Font.Title)
  ui.textColored(value, color or rgbm(0.94, 0.96, 1, 1))
  ui.popFont()
  if detail then ui.textColored(detail, rgbm(0.58, 0.64, 0.71, 1)) end
  ui.endChild()
  ui.popStyleColor()
end

local function pair(a, b)
  local w = math.max(140, (ui.availableSpace().x - 10) / 2)
  card(a[1], a[2], a[3], a[4], a[5], w)
  ui.sameLine()
  card(b[1], b[2], b[3], b[4], b[5], w)
end

-- Caixa do radio (janela principal).
function UI.box(cap, C)
  local a = cap.alpha
  if a <= 0.01 then
    ui.pushFont(ui.Font.Small)
    ui.textColored('AC Engineer Sally', rgbm(0.7, 0.7, 0.7, 1))
    ui.popFont()
    return
  end
  local accent = rgbm(C.accR, C.accG, C.accB, a)
  local size = ui.windowSize()
  ui.pushStyleColor(ui.StyleColor.ChildBg, rgbm(0.04, 0.04, 0.05, 0.92 * a))
  ui.pushStyleColor(ui.StyleColor.Border, accent)
  ui.pushStyleVar(ui.StyleVar.ChildBorderSize, 2)
  ui.beginChild('sallyBox', vec2(size.x - 12, 0), true)
  ui.pushStyleColor(ui.StyleColor.ChildBg, accent)
  ui.beginChild('sallyHdr', vec2(0, 26), false)
  ui.dummy(vec2(6, 0))
  ui.sameLine()
  ui.pushFont(ui.Font.Title)
  ui.textColored(cap.speaker or 'SALLY', rgbm(1, 1, 1, a))
  ui.popFont()
  ui.endChild()
  ui.popStyleColor()
  ui.dummy(vec2(0, 4))
  ui.pushFont(ui.Font.Main)
  ui.pushStyleColor(ui.StyleColor.Text, rgbm(1, 1, 1, a))
  ui.textWrapped('"' .. (cap.text or '') .. '"')
  ui.popStyleColor()
  ui.popFont()
  ui.endChild()
  ui.popStyleVar()
  ui.popStyleColor(2)
end

function UI.spotLine(st, enabled, L)
  local text, color = L:t('spot.free'), rgbm(0.35, 0.86, 0.60, 1)
  if not enabled then text, color = L:t('spot.off'), rgbm(0.58, 0.64, 0.71, 1)
  elseif not st.active then text, color = L:t('spot.wait'), rgbm(0.58, 0.64, 0.71, 1)
  elseif st.left > 0 and st.right > 0 then text, color = L:t('spot.both'), rgbm(1, 0.34, 0.30, 1)
  elseif st.left > 0 then text, color = L:t('spot.left'), rgbm(1, 0.73, 0.25, 1)
  elseif st.right > 0 then text, color = L:t('spot.right'), rgbm(1, 0.73, 0.25, 1) end
  ui.textColored(text, color)
end

-- Central de corrida (janela dashboard).
function UI.dash(S, G, st, C, A, history, message, L)
  S, G = S or {}, G or {}
  ui.pushFont(ui.Font.Title)
  ui.textColored(L:t('dash.title'), rgbm(0.94, 0.96, 1, 1))
  ui.popFont()
  local lapShow = (tonumber(S.lap) or 0) + 1
  local lapsTotal = G.totalLaps and G.totalLaps > 0 and ('/' .. G.totalLaps) or ''
  ui.textColored(string.format(L:t('dash.poslap'), tostring(S.pos or '--'), lapShow, lapsTotal),
    rgbm(0.58, 0.64, 0.71, 1))
  if S.timeLeftS and S.timeLeftS > 0 then
    local mm = math.floor(S.timeLeftS / 60)
    local ss = math.floor(S.timeLeftS % 60)
    ui.textColored(string.format(L:t('dash.clock'), mm, ss), rgbm(0.58, 0.64, 0.71, 1))
  end
  UI.spotLine(st, C.spotOn, L)
  ui.separator()
  if ui.button(A.paused() and L:t('radio.on') or L:t('radio.off')) then A.toggleRadio() end
  ui.separator()
  local cyan = rgbm(0.27, 0.76, 0.95, 1)
  local muted = rgbm(0.58, 0.64, 0.71, 1)
  local consDetail = G.perLap and string.format(L:t('unit.cons'), G.perLap, G.samples or 0)
    or L:t('unit.cons_wait')
  pair({ 'f1', L:t('card.fuel'), fmt(G.fuel, L:t('unit.fuel_l')), consDetail, cyan },
    { 'f2', L:t('card.range'), fmt(G.range, L:t('unit.laps1')), G.need and G.need > 0.1
      and string.format(L:t('card.short'), G.need) or L:t('card.margin_ok'),
      (G.need or 0) > 0.1 and rgbm(1, 0.34, 0.30, 1) or rgbm(0.94, 0.96, 1, 1) })
  pair({ 'f3', L:t('card.remaining'), fmt(G.remaining, L:t('unit.laps0')), G.timed and L:t('card.timed') or L:t('card.bylaps'),
      rgbm(0.94, 0.96, 1, 1) },
    { 'f4', L:t('card.lastbest'), lapTime(G.lastMs, L), L:t('card.best') .. lapTime(G.bestMs, L),
      rgbm(0.35, 0.86, 0.60, 1) })
  ui.dummy(vec2(0, 4))
  ui.textColored(L:t('tyres.title'), cyan)
  ui.separator()
  local labels = { L:t('tyre.fl'), L:t('tyre.fr'), L:t('tyre.rl'), L:t('tyre.rr') }
  local w = math.max(70, (ui.availableSpace().x - 30) / 4)
  for i = 1, 4 do
    local t = S.wheels and S.wheels[i]
    local temp = t and t.temp or nil
    local color = rgbm(0.94, 0.96, 1, 1)
    if temp then
      if temp > 95 then color = rgbm(1, 0.34, 0.30, 1)
      elseif temp < 70 then color = cyan
      else color = rgbm(0.35, 0.86, 0.60, 1) end
    end
    if i > 1 then ui.sameLine() end
    local detail = t and t.psi and string.format(L:t('unit.psi'), t.psi) or '--'
    if t and t.wear and t.wear > 0.02 then
      detail = detail .. string.format(' · %.0f%%', t.wear * 100)
    end
    card('tyre' .. i, labels[i], fmt(temp, L:t('unit.temp')), detail, color, w)
  end
  if S.compoundName then ui.textColored(L:t('tyres.compound') .. tostring(S.compoundName), muted) end
  if S.kersMax then ui.textColored(L:t('tyres.ers') .. string.format('%.0f%%', S.kersPct or 0), muted) end
  ui.separator()
  ui.textColored(L:t('history.title'), cyan)
  ui.separator()
  if not history or #history == 0 then
    ui.textColored(L:t('history.empty'), muted)
  else
    for i = #history, math.max(1, #history - 15), -1 do
      local h = history[i]
      ui.textColored(tostring(h.speaker or 'SALLY'), cyan)
      ui.textWrapped(h.text or '')
    end
  end
  if message then
    ui.separator()
    ui.textWrapped(message)
  end
end

-- Ajustes (janela settings).
function UI.settings(C, A, sally, V, st, counts, diag, L)
  ui.pushFont(ui.Font.Title)
  ui.text('AC ENGINEER SALLY')
  ui.popFont()
  ui.separator()
  ui.textWrapped(sally:available() and L:t('set.voice_ready') or L:t('set.voice_missing'))
  ui.text(L:t('set.lang'))
  ui.sameLine()
  if ui.button('Português') and C.language ~= 'pt-BR' then
    C.language = 'pt-BR'; L:set('pt-BR'); A.save()
  end
  ui.sameLine()
  if ui.button('English') and C.language ~= 'en-US' then
    C.language = 'en-US'; L:set('en-US'); A.save()
  end
  do
    ui.text(L:t('set.tests'))
    if ui.button(L:t('set.t_radio')) then A.tRadio() end
    ui.sameLine()
    if ui.button(L:t('set.t_left')) then A.spotTest('car_left') end
    ui.sameLine()
    if ui.button(L:t('set.t_clear')) then A.spotTest('all_clear') end
    if ui.button(L:t('set.t_seq')) then A.spotSeq() end
    ui.sameLine()
    if ui.button(L:t('set.t_clearq')) then A.clearQueue() end
    ui.separator()
    ui.text(L:t('set.spotst') .. (st.active and L:t('set.active') or L:t('set.standby'))
      .. ' | L:' .. (st.left or 0) .. ' R:' .. (st.right or 0))
    if st.lastCall ~= '' then ui.text(L:t('set.last') .. st.lastCall) end
    if diag and diag.S then
      local S, G = diag.S, diag.G or {}
      ui.separator()
      ui.text(L:t('set.telemetry'))
      ui.text(L:t('set.t_fuel') .. fmt(S.fuel, L:t('unit.fuel_l')) .. L:t('set.t_cons')
        .. fmt(G.perLap, '%.2f L/volta'))
      ui.text(L:t('set.t_dmg') .. fmt(S.dmgTotal, '%.1f') .. L:t('set.t_pen')
        .. (S.penaltyType == nil and L:t('set.t_na') or tostring(S.penaltyType)))
      if diag.hit and diag.hit.data and (diag.now or 0) - diag.hit.at < 120 then
        local hit = diag.hit.data
        ui.text(string.format(L:t('set.t_hit'),
          hit.damageDelta or 0, hit.speedDrop or 0))
      end
    end
  end
  do
    ui.text(L:t('set.catalog'))
    local cats = sally:categories()
    if #cats == 0 then
      ui.textWrapped(L:t('set.nocat'))
    else
      catIdx = math.max(1, math.min(#cats, catIdx))
      if ui.button(L:t('set.folder') .. cats[catIdx] .. ' (' .. catIdx .. '/' .. #cats .. ')') then
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
        if transcript then ui.textWrapped('"' .. transcript .. '"') end
      end
    end
    if counts then ui.text(L:t('set.clips') .. tostring(counts.phrases) .. L:t('set.clips2')) end
  end
  ui.separator()
  local eng = ui.slider('##eng', C.engVol / 50 * 100, 0, 100, L:t('set.eng'))
  local spot = ui.slider('##spot', C.spotVol / 50 * 100, 0, 100, L:t('set.spot'))
  local bg = ui.slider('##bg', C.bgVol, 0, 8, L:t('set.bg'))
  local newEng, newSpot = eng / 100 * 50, spot / 100 * 50
  if newEng ~= C.engVol or newSpot ~= C.spotVol or bg ~= C.bgVol then
    C.engVol, C.spotVol, C.bgVol = newEng, newSpot, bg
    A.applyVolumes()
  end
  local speed = ui.slider('##spd', C.speed, 0.75, 1.75, L:t('set.speed'))
  local pitch = ui.slider('##pit', C.pitch, 0.75, 1.25, L:t('set.pitch'))
  if speed ~= C.speed then C.speed = speed; A.applyVolumes() end
  if pitch ~= C.pitch then C.pitch = pitch; A.applyVolumes() end
  ui.separator()
  if ui.checkbox(L:t('set.spoton'), C.spotOn) then C.spotOn = not C.spotOn; A.save() end
  if ui.checkbox(L:t('set.beep'), C.playBeep) then C.playBeep = not C.playBeep; A.save() end
  if ui.checkbox(L:t('set.wflags'), C.warnFlags) then C.warnFlags = not C.warnFlags; A.save() end
  if ui.checkbox(L:t('set.wfuel'), C.warnFuel) then C.warnFuel = not C.warnFuel; A.save() end
  if ui.checkbox(L:t('set.wtyres'), C.warnTyres) then C.warnTyres = not C.warnTyres; A.save() end
  if ui.checkbox(L:t('set.wdamage'), C.warnDamage) then C.warnDamage = not C.warnDamage; A.save() end
  if ui.checkbox(L:t('set.wsummary'), C.warnSummary) then
    C.warnSummary = not C.warnSummary; A.save()
  end
  if C.warnSummary then
    local every = math.floor(ui.slider('##briefEvery', C.briefEvery, 1, 5,
      L:t('set.every')) + 0.5)
    if every ~= C.briefEvery then C.briefEvery = every; A.save() end
  end
  if C.warnFuel then
    local fuelSeconds = math.floor(ui.slider('##fuelStatus', C.fuelStatusSeconds, 60, 300,
      L:t('set.fuelsec')) + 0.5)
    if fuelSeconds ~= C.fuelStatusSeconds then C.fuelStatusSeconds = fuelSeconds; A.save() end
  end
  local rantLevel = math.floor(ui.slider('##rants', C.rantLevel, 0, 3,
    L:t('set.rants')) + 0.5)
  if rantLevel ~= C.rantLevel then C.rantLevel = rantLevel; A.save() end
  local reserve = ui.slider('##res', C.reserve, 0.25, 3, L:t('set.reserve'))
  if reserve ~= C.reserve then C.reserve = reserve; A.save() end
  ui.separator()
  ui.text('Spotter: ' .. (st.active and 'ATIVO' or 'espera') .. ' | L:' .. (st.left or 0) .. ' R:' .. (st.right or 0))
  if st.lastCall ~= '' then ui.text('Última: ' .. st.lastCall) end
end

return UI
