-- Escolha local de falas de corrida a partir da telemetria da volta.
local Coach = {}

-- Cada intencao alterna entre frases existentes. A verificacao abaixo ignora
-- qualquer variante ausente do pacote sem alterar o contrato de Coach.select().
local VARIANTS = {
  personal_best = {
    { 'lap_times', 'personal_best' },
    { 'lap_times', 'good_lap' },
    { 'pearls_of_wisdom', 'keep_it_up' },
  },
  overtaking = {
    { 'position', 'overtaking' },
    { 'pearls_of_wisdom', 'keep_it_up' },
  },
  being_overtaken = {
    { 'position', 'being_overtaken' },
    { 'pearls_of_wisdom', 'must_do_better' },
  },
  improving = {
    { 'lap_times', 'improving' },
    { 'lap_times', 'pace_good' },
    { 'lap_times', 'good_lap' },
  },
  pace_good = {
    { 'lap_times', 'pace_good' },
    { 'lap_times', 'good_lap' },
    { 'lap_times', 'consistent' },
    { 'pearls_of_wisdom', 'keep_it_up' },
  },
  pace_ok = {
    { 'lap_times', 'pace_ok' },
    { 'lap_times', 'consistent' },
  },
  pace_bad = {
    { 'lap_times', 'pace_bad' },
    { 'lap_times', 'worsening' },
    { 'lap_times', 'need_to_find_a_second' },
    { 'pearls_of_wisdom', 'must_do_better' },
  },
}

local rotation = {}

local function available(sally, category, phrase)
  local transcript = sally:transcript(category, phrase)
  if transcript and sally:hasClip(category, phrase) then
    return { category = category, phrase = phrase, transcript = transcript }
  end
end

local function choose(sally, intent)
  local variants = VARIANTS[intent]
  if not variants then return nil end
  local start = (rotation[intent] or 0) + 1
  for offset = 0, #variants - 1 do
    local index = ((start + offset - 1) % #variants) + 1
    local variant = variants[index]
    local selected = available(sally, variant[1], variant[2])
    if selected then
      rotation[intent] = index
      return selected
    end
  end
end

function Coach.select(sally, S, previousLapMs, previousLapPosition, allSectorsGood, paceTrendMs)
  if not S or (S.sessType ~= 1 and S.sessType ~= 2 and S.sessType ~= 3)
      or S.lastValid ~= true or not S.lastMs or not S.bestMs then return nil end
  if allSectorsGood then return available(sally, 'lap_times', 'sector_all_fast') end
  local positionIntent
  if S.sessType == 3 and previousLapPosition and S.pos then
    if S.pos < previousLapPosition then
      positionIntent = 'overtaking'
    elseif S.pos > previousLapPosition then
      positionIntent = 'being_overtaken'
    end
  end
  -- Ignore the first clean lap as a baseline; it is often an out-lap in practice.
  if not previousLapMs and not positionIntent then return nil end
  local delta = (S.lastMs - S.bestMs) / 1000
  local intent
  if delta <= 0.01 then
    intent = 'personal_best'
  elseif positionIntent then
    intent = positionIntent
  elseif paceTrendMs and paceTrendMs > 300 then
    return available(sally, 'lap_times', 'worsening')
  elseif previousLapMs and S.lastMs < previousLapMs - 300 then
    intent = 'improving'
  elseif delta <= 1.5 then
    intent = 'pace_good'
  elseif delta <= 3.5 then
    intent = 'pace_ok'
  else
    intent = 'pace_bad'
  end
  return choose(sally, intent)
end

return Coach
