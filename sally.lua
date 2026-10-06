-- Leitor do voice pack Sally (audio/sally/<categoria>/<frase>/*.wav).
-- Sem dependencias: so usa io.* do CSP.

local Sally = {}
Sally.__index = Sally

function Sally.new(root)
  return setmetatable({ root = root or '', cache = {}, catCache = nil, phraseCache = nil }, Sally)
end

function Sally:available()
  if not self.root or self.root == '' then return false end
  local ok, exists = pcall(function() return io.dirExists and io.dirExists(self.root) end)
  return ok and exists == true
end

local function listWav(dir)
  local out = {}
  local ok, files = pcall(function()
    if not io.dirExists or not io.dirExists(dir) then return nil end
    return io.scanDir(dir, '*.wav')
  end)
  if ok and type(files) == 'table' then
    for _, name in ipairs(files) do
      if tostring(name):lower():sub(-4) == '.wav' then out[#out + 1] = dir .. '/' .. name end
    end
  end
  table.sort(out)
  return out
end

function Sally:hasClip(category, phrase)
  category, phrase = tostring(category or ''), tostring(phrase or '')
  if category == '' or phrase == '' then return false end
  if category:find('%.%.', 1, true) or phrase:find('%.%.', 1, true) then return false end
  local key = category .. '/' .. phrase
  local cached = self.cache[key]
  if cached == false then return false end
  if type(cached) ~= 'table' then
    cached = listWav(self.root .. '/' .. key)
    if #cached == 0 then self.cache[key] = false; return false end
    self.cache[key] = cached
  end
  return #cached > 0
end

-- Um clip aleatorio da frase (as tomadas variam a cada chamada).
function Sally:clip(category, phrase)
  if not self:hasClip(category, phrase) then return nil end
  local cached = self.cache[tostring(category) .. '/' .. tostring(phrase)]
  return cached[math.random(1, #cached)]
end

-- Seleciona apenas tomadas curtas e adequadas ao contexto (prefixo do arquivo).
function Sally:clipTake(category, phrase, takes)
  if type(takes) ~= 'table' then return self:clip(category, phrase) end
  local key = tostring(category) .. '/' .. tostring(phrase)
  if self.cache[key] == nil then self:clip(category, phrase) end
  local clips = self.cache[key]
  if type(clips) ~= 'table' then return nil end
  local allowed, choices = {}, {}
  for _, take in ipairs(takes) do allowed[tostring(take)] = true end
  for _, path in ipairs(clips) do
    local name = path:match('([^/]+)$')
    local take = name and name:match('^(.-)%-[abc]%.wav$')
    if take and allowed[take] then choices[#choices + 1] = path end
  end
  if #choices == 0 then return nil end
  return choices[math.random(1, #choices)]
end

-- 12.5 -> "12point5" | 12.0 -> "12" | 12.34 -> "12.3" (1 casa).
function Sally:numberName(value)
  local s = tostring(value or ''):gsub(',', '.'):gsub('%.0+$', '')
  local intPart, decPart = s:match('^%-?(%d+)%.?(%d*)$')
  if not intPart then return nil end
  decPart = (decPart or ''):gsub('0+$', '')
  if #decPart > 1 then
    local n = tonumber(intPart .. '.' .. decPart)
    if not n then return nil end
    s = string.format('%.1f', n):gsub('%.0$', '')
    intPart, decPart = s:match('^(%d+)%.?(%d*)$')
    decPart = decPart or ''
  end
  if decPart == '' then return intPart end
  return intPart .. 'point' .. decPart
end

-- Um clip natural (numbers/12point5) ou nil se nao existir.
function Sally:numberClip(value)
  if tostring(value or ''):match('^%-') then return nil end
  local name = self:numberName(value)
  if not name then return nil end
  return self:clip('numbers', name)
end

-- Numero natural quando existe; monta centenas, milhares e decimais com
-- os clips basicos do pack quando nao ha uma tomada pronta.
function Sally:numberClips(value)
  local direct = self:numberClip(value)
  if direct then return { direct } end
  local s = tostring(value or ''):gsub(',', '.')
  local n = tonumber(s)
  if not n or n ~= n or n == math.huge or n == -math.huge then return {} end
  local tenths = math.floor(math.abs(n) * 10 + 0.5)
  local whole, decimal = math.floor(tenths / 10), tenths % 10
  local out = {}
  local function add(name)
    local path = self:clip('numbers', tostring(name))
    if not path then return false end
    out[#out + 1] = path
    return true
  end
  local function integer(v)
    if v < 100 then return add(v) end
    if v < 1000 then
      if not add(math.floor(v / 100)) or not add('hundred') then return false end
      return v % 100 == 0 or integer(v % 100)
    end
    if v < 1000000 then
      if not integer(math.floor(v / 1000)) or not add('thousand') then return false end
      return v % 1000 == 0 or integer(v % 1000)
    end
    return false
  end
  if n < 0 and tenths > 0 and not add('minus') then return {} end
  if not integer(whole) then return {} end
  if decimal > 0 and (not add('point') or not add(decimal)) then return {} end
  return out
end

-- Transcrição original (subtitles.csv) para exibir no catalogo.
function Sally:transcript(category, phrase)
  local path = self.root .. '/' .. tostring(category) .. '/' .. tostring(phrase) .. '/subtitles.csv'
  local ok, file = pcall(io.open, path, 'r')
  if not ok or not file then return nil end
  local readOk, line = pcall(function() return file:read('*l') end)
  pcall(function() file:close() end)
  if not readOk then return nil end
  if not line then return nil end
  local text = line:match('^[^,]+,(.+)$') or ''
  text = text:gsub('^%s*"', ''):gsub('"%s*$', '')
  if text == '' then return nil end
  return text
end

function Sally:categories()
  if self.catCache then return self.catCache end
  local out = {}
  local ok, names = pcall(function()
    if not io.dirExists or not io.dirExists(self.root) then return nil end
    return io.scanDir(self.root, '*')
  end)
  if ok and type(names) == 'table' then
    for _, name in ipairs(names) do
      if not tostring(name):find('%.', 1, true) then
        local full = self.root .. '/' .. name
        local ok2, isDir = pcall(function() return io.dirExists and io.dirExists(full) end)
        if ok2 and isDir then out[#out + 1] = name end
      end
    end
  end
  table.sort(out)
  self.catCache = out
  return out
end

function Sally:phrases(category)
  category = tostring(category or '')
  if category == '' or category:find('%.%.', 1, true) then return {} end
  self.phraseCache = self.phraseCache or {}
  if self.phraseCache[category] then return self.phraseCache[category] end
  local out = {}
  local dir = self.root .. '/' .. category
  local ok, names = pcall(function()
    if not io.dirExists or not io.dirExists(dir) then return nil end
    return io.scanDir(dir, '*')
  end)
  if ok and type(names) == 'table' then
    for _, name in ipairs(names) do
      if not tostring(name):find('%.', 1, true) then
        local full = dir .. '/' .. name
        local ok2, isDir = pcall(function() return io.dirExists and io.dirExists(full) end)
        if ok2 and isDir then out[#out + 1] = name end
      end
    end
  end
  table.sort(out)
  self.phraseCache[category] = out
  return out
end

return Sally
