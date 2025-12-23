-- lib/whisker/i18n/string_table.lua
-- String Table Module for whisker-core i18n
-- Stage 2: Core data structure for translation storage and lookup

local M = {}

-- Dependencies injected via container
M._dependencies = {"logger"}

-- Module version
M._VERSION = "1.0.0"

-- String interning pool for memory optimization
local stringPool = {}

--- Intern a string to reduce memory duplication
-- @param str string String to intern
-- @return string Interned string
local function intern(str)
  if type(str) ~= "string" then
    return str
  end

  if not stringPool[str] then
    stringPool[str] = str
  end

  return stringPool[str]
end

-- StringTable class
local StringTable = {}
StringTable.__index = StringTable

--- Create a new string table
-- @param config table Configuration options
--   - defaultLocale: string (required) - fallback locale
--   - fallbackLocale: string - explicit fallback locale
--   - strictMode: boolean - throw error on missing key
--   - logMissing: boolean - log missing translations
-- @return StringTable instance
function M.new(config)
  config = config or {}

  local self = setmetatable({}, StringTable)

  -- Configuration
  self.config = {
    defaultLocale = config.defaultLocale or "en",
    fallbackLocale = config.fallbackLocale,
    strictMode = config.strictMode or false,
    logMissing = config.logMissing or false
  }

  -- Store logger dependency
  self.log = config.logger

  -- Hierarchical storage (as loaded from files)
  self.data = {}

  -- Flattened index for fast lookup
  self.index = {}

  -- Missing key tracking
  self.missing = {}

  -- Metadata
  self.metadata = {}

  return self
end

--- Validate translation data structure
-- @param data table Data to validate
-- @param seen table Table to track visited nodes for circular ref detection
-- @return boolean, string Success, error message
function StringTable:validateData(data, seen)
  seen = seen or {}

  if type(data) ~= "table" then
    return true  -- Non-table values are valid leaf nodes
  end

  -- Check for circular reference
  if seen[data] then
    return false, "Circular reference detected"
  end
  seen[data] = true

  for key, value in pairs(data) do
    if type(key) ~= "string" and type(key) ~= "number" then
      return false, "Non-string/number key: " .. tostring(key)
    end

    if type(value) == "table" then
      local ok, err = self:validateData(value, seen)
      if not ok then
        return false, err
      end
    end
  end

  return true
end

--- Check if table has circular references
-- @param tbl table Table to check
-- @param seen table Already visited tables
-- @return boolean Has circular reference
function StringTable:hasCircularRef(tbl, seen)
  seen = seen or {}

  if type(tbl) ~= "table" then
    return false
  end

  if seen[tbl] then
    return true
  end

  seen[tbl] = true

  for _, value in pairs(tbl) do
    if type(value) == "table" then
      if self:hasCircularRef(value, seen) then
        return true
      end
    end
  end

  return false
end

--- Apply string interning to data recursively
-- @param data any Translation data
-- @return any Interned data
function StringTable:internStrings(data)
  if type(data) ~= "table" then
    return intern(tostring(data))
  end

  local result = {}
  for key, value in pairs(data) do
    result[intern(tostring(key))] = self:internStrings(value)
  end

  return result
end

--- Load translation data for a locale
-- @param locale string Locale code (e.g., "en", "es-MX")
-- @param data table Hierarchical translation data
-- @param options table|nil Options {lazy: boolean}
function StringTable:load(locale, data, options)
  options = options or {}

  -- Validate data
  local ok, err = self:validateData(data)
  if not ok then
    error("Invalid translation data for " .. locale .. ": " .. err)
  end

  -- Intern strings for memory optimization
  data = self:internStrings(data)

  -- Store hierarchical data
  self.data[locale] = data

  if options.lazy then
    -- Mark as needing index build
    self.metadata[locale] = {
      needsIndex = true,
      loadTime = os.time()
    }
  else
    -- Build flattened index immediately
    self.index[locale] = self:flatten(data)

    -- Store metadata
    self.metadata[locale] = {
      loadTime = os.time(),
      keyCount = self:countKeys(self.index[locale]),
      needsIndex = false
    }
  end

  -- Initialize missing tracking
  self.missing[locale] = self.missing[locale] or {}
end

--- Ensure index exists for locale (for lazy loading)
-- @param locale string Locale code
function StringTable:ensureIndex(locale)
  local meta = self.metadata[locale]

  if meta and meta.needsIndex then
    self.index[locale] = self:flatten(self.data[locale])
    meta.needsIndex = false
    meta.keyCount = self:countKeys(self.index[locale])
  end
end

--- Unload a locale to free memory
-- @param locale string Locale to unload
function StringTable:unload(locale)
  self.data[locale] = nil
  self.index[locale] = nil
  self.metadata[locale] = nil
  self.missing[locale] = nil
end

--- Flatten hierarchical table to dot-notation keys
-- @param data table Hierarchical data
-- @param prefix string|nil Current key prefix
-- @return table Flattened {["key.path"] = "value"}
function StringTable:flatten(data, prefix)
  local result = {}
  prefix = prefix or ""

  if type(data) ~= "table" then
    return result
  end

  for key, value in pairs(data) do
    -- Build full key path
    local keyStr = tostring(key)
    local fullKey = prefix == "" and keyStr or (prefix .. "." .. keyStr)

    if type(value) == "table" then
      -- Recurse into nested tables
      local nested = self:flatten(value, fullKey)
      for nestedKey, nestedValue in pairs(nested) do
        -- Check for key collision
        if result[nestedKey] then
          if self.log then
            self.log:warn("Key collision at: %s", nestedKey)
          end
        end
        result[nestedKey] = nestedValue
      end
    elseif value ~= nil then
      -- Leaf value: store in flattened index
      -- Convert to string for consistency
      result[fullKey] = tostring(value)
    end
  end

  return result
end

--- Split locale into parts (language-Script-Region)
-- @param locale string Locale code (e.g., "zh-Hant-TW")
-- @return table Array of parts
function StringTable:splitLocale(locale)
  local parts = {}
  for part in locale:gmatch("[^-]+") do
    table.insert(parts, part)
  end
  return parts
end

--- Build fallback chain for locale
-- @param locale string Target locale (e.g., "zh-Hant-TW")
-- @return table Array of locales to try in order
function StringTable:buildFallbackChain(locale)
  local chain = {}
  local added = {}  -- Track added locales to avoid duplicates

  local function addIfNew(loc)
    if loc and not added[loc] then
      table.insert(chain, loc)
      added[loc] = true
    end
  end

  -- 1. Try base language (zh-Hant-TW → zh-Hant → zh)
  local parts = self:splitLocale(locale)
  if #parts > 1 then
    -- Remove region: zh-Hant-TW → zh-Hant
    addIfNew(table.concat(parts, "-", 1, #parts - 1))

    if #parts > 2 then
      -- Remove script: zh-Hant → zh
      addIfNew(parts[1])
    end
  end

  -- 2. Try explicit fallback locale
  if self.config.fallbackLocale and self.config.fallbackLocale ~= locale then
    addIfNew(self.config.fallbackLocale)
  end

  -- 3. Try default locale
  if self.config.defaultLocale and self.config.defaultLocale ~= locale then
    addIfNew(self.config.defaultLocale)
  end

  return chain
end

--- Look up a translation key with fallback chain
-- @param locale string Target locale (e.g., "en", "es-MX")
-- @param key string Dot-notation key (e.g., "items.sword")
-- @return string|nil Translation or nil if not found
function StringTable:lookup(locale, key)
  -- Ensure index is built for locale (for lazy loading)
  self:ensureIndex(locale)

  -- Fast path: exact match in index
  if self.index[locale] and self.index[locale][key] then
    return self.index[locale][key]
  end

  -- Fallback chain
  local chain = self:buildFallbackChain(locale)
  for _, fallbackLocale in ipairs(chain) do
    self:ensureIndex(fallbackLocale)
    if self.index[fallbackLocale] and self.index[fallbackLocale][key] then
      return self.index[fallbackLocale][key]
    end
  end

  -- Not found - track missing
  self:trackMissing(locale, key)
  return nil
end

--- Check if a key exists (with fallback chain)
-- @param locale string Target locale
-- @param key string Translation key
-- @return boolean
function StringTable:has(locale, key)
  return self:lookup(locale, key) ~= nil
end

--- Get all keys for a locale
-- @param locale string Target locale
-- @return table Array of key strings
function StringTable:getKeys(locale)
  self:ensureIndex(locale)

  if not self.index[locale] then
    return {}
  end

  local keys = {}
  for key, _ in pairs(self.index[locale]) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

--- Get loaded locales
-- @return table Array of locale strings
function StringTable:getLocales()
  local locales = {}
  for locale, _ in pairs(self.data) do
    table.insert(locales, locale)
  end
  table.sort(locales)
  return locales
end

--- Track missing translation key
-- @param locale string Locale where key was missing
-- @param key string Missing key
function StringTable:trackMissing(locale, key)
  -- Initialize locale entry
  if not self.missing[locale] then
    self.missing[locale] = {}
  end

  -- Avoid duplicates
  for _, missingKey in ipairs(self.missing[locale]) do
    if missingKey == key then
      return
    end
  end

  table.insert(self.missing[locale], key)

  -- Log if configured
  if self.config.logMissing and self.log then
    self.log:warn("Missing translation: locale=%s key=%s", locale, key)
  end
end

--- Get missing translations
-- @param locale string|nil Optional locale filter
-- @return table Missing keys (by locale if no filter, or array for specific locale)
function StringTable:getMissing(locale)
  if locale then
    return self.missing[locale] or {}
  end
  return self.missing
end

--- Clear missing key tracking
-- @param locale string|nil Optional locale to clear
function StringTable:clearMissing(locale)
  if locale then
    self.missing[locale] = {}
  else
    self.missing = {}
  end
end

--- Get metadata for a locale
-- @param locale string Target locale
-- @return table|nil Metadata (loadTime, keyCount, etc.)
function StringTable:getMetadata(locale)
  return self.metadata[locale]
end

--- Count keys in flattened index
-- @param index table Flattened index
-- @return number Key count
function StringTable:countKeys(index)
  if not index then return 0 end

  local count = 0
  for _ in pairs(index) do
    count = count + 1
  end
  return count
end

--- Get memory usage estimate
-- @param locale string|nil Optional locale to measure
-- @return number Bytes (approximate)
function StringTable:getMemoryUsage(locale)
  local function sizeOf(tbl, seen)
    seen = seen or {}

    if type(tbl) ~= "table" then
      if type(tbl) == "string" then
        return #tbl
      elseif type(tbl) == "number" then
        return 8  -- Approximate size of a number
      else
        return 0
      end
    end

    if seen[tbl] then
      return 0  -- Already counted
    end
    seen[tbl] = true

    local bytes = 0
    for k, v in pairs(tbl) do
      bytes = bytes + sizeOf(k, seen) + sizeOf(v, seen)
    end
    return bytes
  end

  if locale then
    local size = 0
    if self.data[locale] then
      size = size + sizeOf(self.data[locale])
    end
    if self.index[locale] then
      size = size + sizeOf(self.index[locale])
    end
    return size
  else
    return sizeOf(self.data) + sizeOf(self.index)
  end
end

--- Clone locale data
-- @param fromLocale string Source locale
-- @param toLocale string Destination locale
function StringTable:clone(fromLocale, toLocale)
  if not self.data[fromLocale] then
    error("Source locale not loaded: " .. fromLocale)
  end

  -- Deep copy
  local function deepCopy(tbl)
    if type(tbl) ~= "table" then
      return tbl
    end

    local copy = {}
    for k, v in pairs(tbl) do
      copy[k] = deepCopy(v)
    end
    return copy
  end

  self:load(toLocale, deepCopy(self.data[fromLocale]))
end

--- Merge additional data into an existing locale
-- @param locale string Target locale
-- @param data table Additional translation data
-- @param overwrite boolean Whether to overwrite existing keys (default: false)
function StringTable:merge(locale, data, overwrite)
  overwrite = overwrite or false

  if not self.data[locale] then
    -- No existing data, just load
    self:load(locale, data)
    return
  end

  -- Deep merge
  local function mergeTables(target, source)
    for key, value in pairs(source) do
      if type(value) == "table" and type(target[key]) == "table" then
        mergeTables(target[key], value)
      elseif overwrite or target[key] == nil then
        target[key] = value
      end
    end
  end

  mergeTables(self.data[locale], data)

  -- Rebuild index
  self.index[locale] = self:flatten(self.data[locale])
  self.metadata[locale].keyCount = self:countKeys(self.index[locale])
end

--- Get raw hierarchical data for a locale
-- @param locale string Target locale
-- @return table|nil Hierarchical data
function StringTable:getData(locale)
  return self.data[locale]
end

--- Get flattened index for a locale
-- @param locale string Target locale
-- @return table|nil Flattened index
function StringTable:getIndex(locale)
  self:ensureIndex(locale)
  return self.index[locale]
end

return M
