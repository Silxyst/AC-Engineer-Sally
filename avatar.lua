-- Expressao 2D da Sally: arquivos locais e classificacao por categoria de audio.
local Avatar = {}

local ASSETS = {
  neutral = { 'sally-idle.png', 'sally-talking.png' },
  angry = { 'sally-angry-idle.png', 'sally-angry-talking.png' },
  focused = { 'sally-focused-idle.png', 'sally-focused-talking.png' },
  concerned = { 'sally-concerned-idle.png', 'sally-concerned-talking.png' },
  happy = { 'sally-happy-idle.png', 'sally-happy-talking.png' },
  furious = { 'sally-furious-idle.png', 'sally-furious-talking.png' },
  sarcastic = { 'sally-sarcastic-idle.png', 'sally-sarcastic-talking.png' },
  surprised = { 'sally-surprised-idle.png', 'sally-surprised-talking.png' },
  relieved = { 'sally-relieved-idle.png', 'sally-relieved-talking.png' },
  determined = { 'sally-determined-idle.png', 'sally-determined-talking.png' },
}

local function existing(root, filename)
  local path = root .. '/assets/' .. filename
  local ok, file = pcall(io.open, path, 'rb')
  if not ok or not file then return nil end
  pcall(function() file:close() end)
  return path
end

function Avatar.load(root)
  local neutralIdle = existing(root, ASSETS.neutral[1])
  if not neutralIdle then return nil end
  local neutralTalking = existing(root, ASSETS.neutral[2]) or neutralIdle
  local frames = { neutral = { idle = neutralIdle, talking = neutralTalking } }
  for mood, files in pairs(ASSETS) do
    if mood ~= 'neutral' then
      frames[mood] = {
        idle = existing(root, files[1]) or neutralIdle,
        talking = existing(root, files[2]) or neutralTalking,
      }
    end
  end
  return frames
end

local function contains(value, part)
  return value:find(part, 1, true) ~= nil
end

function Avatar.expressionFor(entry)
  if type(entry) ~= 'table' or type(entry.path) ~= 'string' then return 'neutral' end
  local path = entry.path:gsub('\\', '/'):lower()
  local category, phrase = path:match('/audio/sally/([^/]+)/([^/]+)/')
  if not category then return 'neutral' end

  if category == 'rants' then
    local mood = math.random(1, 3)
    if mood == 1 then return 'angry' end
    return mood == 2 and 'furious' or 'sarcastic'
  end
  if category == 'lap_counter' then
    if phrase == 'won_race' or phrase == 'podium_finish'
        or phrase == 'finished_race_good_finish' then return 'happy' end
    if phrase == 'finished_race_last' then return 'concerned' end
    if phrase == 'last_lap_leading' or phrase == 'last_lap_top_three' then return 'happy' end
    if phrase == 'get_ready' then return 'surprised' end
    return 'determined'
  end
  if category == 'lap_times' then
    if phrase == 'personal_best' or phrase == 'good_lap' or phrase == 'improving'
        or phrase == 'pace_good' or phrase == 'consistent'
        or contains(phrase, '_fast') then return 'happy' end
    if contains(phrase, 'off_pace') or contains(phrase, 'pace_bad')
        or contains(phrase, 'need_to_find') then return 'determined' end
    return 'focused'
  end
  if category == 'pearls_of_wisdom' then
    return phrase == 'keep_it_up' and 'happy' or 'determined'
  end

  if category == 'damage_reporting' then
    if contains(phrase, 'are_you_ok') then return 'surprised' end
    if contains(phrase, 'severe') or contains(phrase, 'busted') then return 'concerned' end
    return 'focused'
  end
  if category == 'flags' then
    if phrase == 'local_yellow_clear' then return 'relieved' end
    if phrase == 'slow_car_ahead' then return 'sarcastic' end
    if phrase == 'stopped_car_ahead' then return 'surprised' end
    if phrase == 'blue_flag' then return 'sarcastic' end
    if phrase == 'black_flag' or phrase == 'local_yellow_ahead' then return 'concerned' end
    return 'focused'
  end
  if category == 'penalties' then
    if phrase == 'penalty_served' or phrase == 'you_dont_have_a_penalty' then return 'relieved' end
    if contains(phrase, 'false_start') or contains(phrase, 'cutting_track')
        or contains(phrase, 'ignored_blue') then return 'sarcastic' end
    if contains(phrase, 'new_') or contains(phrase, 'you_have')
        or contains(phrase, 'still') or contains(phrase, 'black_flag')
        or contains(phrase, 'meatball') or contains(phrase, 'cut_track') then
      return 'concerned'
    end
    return 'focused'
  end
  if category == 'fuel' then
    if phrase == 'fuel_should_be_ok' or phrase == 'half_distance_good_fuel' then return 'relieved' end
    if contains(phrase, 'run_out') or contains(phrase, 'need_to_pit')
        or contains(phrase, 'tight') or contains(phrase, 'low_fuel') then return 'concerned' end
    return 'focused'
  end
  if category == 'tyre_monitor' then
    if contains(phrase, 'puncture') or contains(phrase, 'blown') then return 'surprised' end
    if contains(phrase, 'cooking') or contains(phrase, 'knackered') then
      return 'concerned'
    end
    return 'determined'
  end
  if category == 'engine_monitor' then
    if contains(phrase, 'busted') then return 'surprised' end
    if contains(phrase, 'hot_') or contains(phrase, 'overheat') then return 'concerned' end
    return 'focused'
  end

  if category == 'position' then
    if phrase == 'overtaking' then return 'happy' end
    if phrase == 'being_overtaken' then return 'sarcastic' end
  end
  if category == 'conditions' and contains(phrase, 'rain') then return 'concerned' end
  if category == 'battery' then
    if contains(phrase, 'low') or contains(phrase, 'empty') then return 'concerned' end
    return 'focused'
  end

  if category == 'numbers' or category == 'spotter' or category == 'radio_check'
      or category == 'acknowledge' then return 'neutral' end
  if category == 'lap_times' or category == 'battery' or category == 'conditions'
      or category == 'corners' or category == 'engine_monitor'
      or category == 'mandatory_pit_stops' or category == 'opponents'
      or category == 'overtaking_aids' or category == 'position'
      or category == 'push_now' or category == 'race_time' or category == 'strategy'
      or category == 'timings' then return 'focused' end
  return 'neutral'
end

return Avatar
