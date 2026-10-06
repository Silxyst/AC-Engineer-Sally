-- Expressao 2D da Sally: arquivos locais e classificacao por categoria de audio.
local Avatar = {}

local ASSETS = {
  -- Full-body gesture test set; frame 1 is idle and frame 2 is speaking.
  neutral = { 'sally-neutral-gesture-test.png', 'sally-neutral-gesture-pair-test.png' },
  angry = { 'sally-angry-gesture-pair-test.png', 'sally-angry-gesture-test.png' },
  focused = { 'sally-focused-gesture-pair-test.png', 'sally-focused-gesture-test.png' },
  concerned = { 'sally-concerned-gesture-pair-test.png', 'sally-concerned-gesture-test.png' },
  happy = { 'sally-happy-gesture-pair-test.png', 'sally-approving-gesture-test.png' },
  furious = { 'sally-furious-gesture-pair-test.png', 'sally-furious-gesture-test.png' },
  sarcastic = { 'sally-sarcastic-gesture-pair-test.png', 'sally-sarcastic-gesture-test.png' },
  surprised = { 'sally-surprised-gesture-pair-test.png', 'sally-surprised-gesture-test.png' },
  relieved = { 'sally-relieved-gesture-pair-test.png', 'sally-relieved-gesture-test.png' },
  determined = { 'sally-determined-gesture-pair-test.png', 'sally-determined-gesture-test.png' },
  alert = { 'sally-alert-gesture-pair-test.png', 'sally-alert-gesture-test.png' },
  celebrating = { 'sally-celebrating-gesture-pair-test.png', 'sally-celebrating-gesture-test.png' },
  confused = { 'sally-confused-gesture-pair-test.png', 'sally-confused-gesture-test.png' },
  disappointed = { 'sally-disappointed-gesture-test.png', 'sally-disappointed-gesture-pair-test.png' },
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
      local idle = existing(root, files[1]) or neutralIdle
      frames[mood] = {
        idle = idle,
        talking = existing(root, files[2]) or idle or neutralTalking,
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
  local category, phrase = path:match('audio/sally/([^/]+)/([^/]+)/')
  if not category then return 'neutral' end

  if category == 'rants' then
    local mood = math.random(1, 3)
    if mood == 1 then return 'angry' end
    return mood == 2 and 'furious' or 'sarcastic'
  end
  if category == 'lap_counter' then
    if phrase == 'won_race' or phrase == 'podium_finish'
        or phrase == 'finished_race_good_finish' then return 'celebrating' end
    if phrase == 'finished_race_last' or phrase == 'finished_race' then return 'disappointed' end
    if phrase == 'last_lap_leading' or phrase == 'last_lap_top_three' then return 'celebrating' end
    if phrase == 'get_ready' then return 'determined' end
    return 'determined'
  end
  if category == 'lap_times' then
    if phrase == 'personal_best' or phrase == 'good_lap' or phrase == 'improving'
        or phrase == 'pace_good' or phrase == 'consistent'
        or contains(phrase, '_fast') then return 'happy' end
    if contains(phrase, 'pace_bad') then return 'disappointed' end
    if contains(phrase, 'off_pace') or contains(phrase, 'need_to_find') then return 'determined' end
    return 'focused'
  end
  if category == 'pearls_of_wisdom' then
    return phrase == 'keep_it_up' and 'happy' or 'determined'
  end

  if category == 'damage_reporting' then
    if phrase == 'no_damage' then return 'relieved' end
    if contains(phrase, 'are_you_ok') then return 'concerned' end
    if contains(phrase, 'severe') or contains(phrase, 'busted') then return 'concerned' end
    return 'focused'
  end
  if category == 'flags' then
    if phrase == 'local_yellow_clear' then return 'relieved' end
    if phrase == 'slow_car_ahead' or phrase == 'stopped_car_ahead'
        or phrase == 'blue_flag' then return 'alert' end
    if phrase == 'black_flag' or phrase == 'local_yellow_ahead' then return 'concerned' end
    return 'focused'
  end
  if category == 'spotter' then
    if contains(phrase, 'clear') then return 'relieved' end
    return 'alert'
  end
  if category == 'penalties' then
    if phrase == 'penalty_served' or phrase == 'you_dont_have_a_penalty' then return 'relieved' end
    if phrase == 'pit_now_stop_go' then return 'alert' end
    if phrase == 'drive_through_speeding_in_pit_lane' or phrase == 'lap_deleted'
        or phrase == 'stop_go_penalty_speeding_in_pit_lane' then return 'concerned' end
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
        or contains(phrase, 'tight') or contains(phrase, 'low_fuel')
        or contains(phrase, 'one_lap_fuel') then return 'concerned' end
    return 'focused'
  end
  if category == 'tyre_monitor' then
    if contains(phrase, 'puncture') or contains(phrase, 'blown') then return 'surprised' end
    if contains(phrase, 'cooking') or contains(phrase, 'knackered')
        or contains(phrase, 'hot_') or contains(phrase, 'overheat') then
      return 'concerned'
    end
    return 'determined'
  end
  if category == 'engine_monitor' then
    if contains(phrase, 'busted') then return 'surprised' end
    if contains(phrase, 'hot_') or contains(phrase, 'overheat') then return 'concerned' end
    return 'focused'
  end
  if category == 'acknowledge' then
    return phrase == 'no_data' and 'confused' or 'neutral'
  end

  if category == 'position' then
    if phrase == 'overtaking' or phrase == 'good_start' or phrase == 'pole' then return 'happy' end
    if phrase == 'being_overtaken' or phrase == 'bad_start' or phrase == 'terrible_start' then
      return 'determined'
    end
  end
  if category == 'conditions' and contains(phrase, 'rain') then return 'concerned' end
  if category == 'battery' then
    if contains(phrase, 'low') or contains(phrase, 'empty')
        or contains(phrase, 'critical') or contains(phrase, 'run_out') then return 'concerned' end
    return 'focused'
  end
  if category == 'push_now' then return 'determined' end
  if category == 'race_time' and (contains(phrase, 'last_lap')
      or contains(phrase, 'leading') or contains(phrase, 'podium')) then return 'determined' end

  if category == 'numbers' or category == 'radio_check' then return 'neutral' end
  if category == 'lap_times' or category == 'battery' or category == 'conditions'
      or category == 'corners' or category == 'engine_monitor'
      or category == 'mandatory_pit_stops' or category == 'opponents'
      or category == 'overtaking_aids' or category == 'position'
      or category == 'push_now' or category == 'race_time' or category == 'strategy'
      or category == 'timings' then return 'focused' end
  return 'neutral'
end

return Avatar
