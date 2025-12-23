-- lib/whisker/i18n/init.lua
-- Internationalization system for whisker-core
-- Stage 1: Architecture Foundation

local M = {}

-- Dependencies injected via container
M._dependencies = {"event_bus", "logger"}

-- Module version
M._VERSION = "1.0.0"

-- Lazy-loaded submodules
local _string_table
local _locale
local _interpolation
local _pluralization
local _bidi
local _formats

-- Helper to lazy-load submodules
local function requireLazy(name)
  local success, mod = pcall(require, "whisker.i18n." .. name)
  if success then
    return mod
  end
  return nil
end

-- I18n class
local I18n = {}
I18n.__index = I18n

--- Create a new I18n instance
-- @param deps table Dependencies from container (event_bus, logger)
-- @return I18n instance
function M.new(deps)
  deps = deps or {}

  local self = setmetatable({}, I18n)

  -- Store dependencies
  self.events = deps.event_bus
  self.log = deps.logger

  -- Configuration (set via init)
  self.config = {
    defaultLocale = "en",
    fallbackLocale = nil,
    loadPath = "locales/{locale}.yml",
    autoDetect = true,
    logMissing = true,
    strictMode = false,
    preload = {},
    onMissingTranslation = nil
  }

  -- Current locale
  self.currentLocale = nil

  -- String tables (hierarchical)
  self.stringTable = {}

  -- Flat index for fast lookup
  self.flatIndex = {}

  -- Track missing keys for reporting
  self.missingKeys = {}

  -- Interpolation cache
  self._interpCache = {}

  -- Initialization state
  self._initialized = false

  -- Submodule instances (lazy loaded)
  self._stringTable = nil
  self._locale = nil
  self._interpolation = nil
  self._pluralization = nil
  self._bidi = nil

  return self
end

--- Initialize the i18n system
-- @param config table Configuration options
-- @return I18n self for chaining
function I18n:init(config)
  config = config or {}

  -- Merge configuration (only for known keys)
  local validKeys = {
    defaultLocale = true,
    fallbackLocale = true,
    loadPath = true,
    autoDetect = true,
    logMissing = true,
    strictMode = true,
    preload = true,
    onMissingTranslation = true
  }
  for key, value in pairs(config) do
    if validKeys[key] then
      self.config[key] = value
    end
  end

  -- Set default locale as current if not auto-detecting
  if not self.config.autoDetect then
    self.currentLocale = self.config.defaultLocale
  else
    -- Try to detect locale from platform
    local detectedLocale = self:_detectLocale()
    self.currentLocale = detectedLocale or self.config.defaultLocale
  end

  -- Preload requested locales
  if self.config.preload and #self.config.preload > 0 then
    for _, locale in ipairs(self.config.preload) do
      local filepath = self:_resolveLoadPath(locale)
      pcall(function() self:load(locale, filepath) end)
    end
  end

  self._initialized = true

  -- Emit initialization event
  if self.events then
    self.events:emit("i18n:initialized", {
      locale = self.currentLocale,
      config = self.config
    })
  end

  return self
end

--- Check if the i18n system is initialized
-- @return boolean
function I18n:isInitialized()
  return self._initialized
end

--- Load translations from a file
-- @param locale string Locale code (e.g., "en", "en-US")
-- @param filepath string Path to translation file
-- @return boolean success
function I18n:load(locale, filepath)
  if not locale then
    error("I18n:load() requires locale parameter")
  end

  filepath = filepath or self:_resolveLoadPath(locale)

  -- Lazy load format handlers
  if not _formats then
    _formats = requireLazy("formats")
  end

  local data, err
  if _formats then
    data, err = _formats.loadFile(filepath)
  else
    -- Fallback: try to load as Lua table
    data, err = self:_loadLuaFile(filepath)
  end

  if not data then
    local errMsg = string.format("Failed to load translations for %s from %s: %s",
      locale, filepath, err or "unknown error")
    if self.log then
      self.log:error(errMsg)
    end
    if self.config.strictMode then
      error(errMsg)
    end
    return false
  end

  return self:loadData(locale, data)
end

--- Load translations from a data table
-- @param locale string Locale code
-- @param data table Translation data (hierarchical)
-- @return boolean success
function I18n:loadData(locale, data)
  if not locale then
    error("I18n:loadData() requires locale parameter")
  end
  if type(data) ~= "table" then
    error("I18n:loadData() requires data to be a table")
  end

  -- Store hierarchical data
  self.stringTable[locale] = data

  -- Create flattened index for fast lookup
  self.flatIndex[locale] = self:_flatten(data)

  -- Clear interpolation cache for this locale
  self:_clearCache(locale)

  -- Initialize missing keys tracking
  self.missingKeys[locale] = self.missingKeys[locale] or {}

  -- Emit event
  if self.events then
    self.events:emit("i18n:loaded", {
      locale = locale,
      keyCount = self:_countKeys(self.flatIndex[locale])
    })
  end

  return true
end

--- Load all translations from a directory
-- @param dirPath string Directory path containing translation files
-- @return table List of loaded locales
function I18n:loadAll(dirPath)
  -- This requires filesystem access - implementation depends on platform
  -- For now, return empty and log warning
  if self.log then
    self.log:warn("I18n:loadAll() requires platform-specific filesystem access")
  end
  return {}
end

--- Unload a locale to free memory
-- @param locale string Locale code to unload
function I18n:unload(locale)
  if locale == self.config.defaultLocale then
    if self.log then
      self.log:warn("Cannot unload default locale: %s", locale)
    end
    return false
  end

  self.stringTable[locale] = nil
  self.flatIndex[locale] = nil
  self.missingKeys[locale] = nil
  self:_clearCache(locale)

  -- Emit event
  if self.events then
    self.events:emit("i18n:unloaded", { locale = locale })
  end

  return true
end

--- Set the current locale
-- @param locale string Locale code
-- @return boolean success
function I18n:setLocale(locale)
  if not locale then
    error("I18n:setLocale() requires locale parameter")
  end

  local previousLocale = self.currentLocale
  self.currentLocale = locale

  -- Clear interpolation cache
  self._interpCache = {}

  -- Emit event
  if self.events then
    self.events:emit("i18n:localeChanged", {
      from = previousLocale,
      to = locale
    })
  end

  return true
end

--- Get the current locale
-- @return string Current locale code
function I18n:getLocale()
  return self.currentLocale
end

--- Get list of available (loaded) locales
-- @return table List of locale codes
function I18n:getAvailableLocales()
  local locales = {}
  for locale, _ in pairs(self.stringTable) do
    table.insert(locales, locale)
  end
  table.sort(locales)
  return locales
end

--- Check if a locale is available (loaded)
-- @param locale string Locale code
-- @return boolean
function I18n:hasLocale(locale)
  return self.stringTable[locale] ~= nil
end

--- Set a custom fallback chain
-- @param chain table List of locale codes to try in order
function I18n:setFallbackChain(chain)
  self._customFallbackChain = chain
end

--- Translate a key
-- @param key string Translation key (dot notation)
-- @param vars table|nil Variables for interpolation
-- @param locale string|nil Override locale (optional)
-- @return string Translated text
function I18n:t(key, vars, locale)
  if not key then
    return ""
  end

  locale = locale or self.currentLocale or self.config.defaultLocale
  vars = vars or {}

  -- Try lookup with fallback chain
  local text = self:_lookup(locale, key)

  if text then
    return self:_interpolate(text, vars)
  end

  -- Handle missing translation
  return self:_handleMissing(locale, key, vars)
end

--- Translate with pluralization
-- @param key string Translation key (expects .one, .other, etc. subkeys)
-- @param count number Count for plural selection
-- @param vars table|nil Additional variables
-- @param locale string|nil Override locale (optional)
-- @return string Translated and pluralized text
function I18n:p(key, count, vars, locale)
  if not key then
    return ""
  end

  locale = locale or self.currentLocale or self.config.defaultLocale
  vars = vars or {}
  vars.count = count

  -- Lazy load pluralization module
  if not _pluralization then
    _pluralization = requireLazy("pluralization")
  end

  -- Get plural category
  local category = "other"
  if _pluralization then
    category = _pluralization.getCategory(locale, count)
  else
    -- Simple fallback: English rules
    if count == 1 then
      category = "one"
    end
  end

  -- Build full key with plural category
  local pluralKey = key .. "." .. category
  local text = self:_lookup(locale, pluralKey)

  -- Fallback to 'other' if specific category not found
  if not text and category ~= "other" then
    pluralKey = key .. ".other"
    text = self:_lookup(locale, pluralKey)
  end

  if text then
    return self:_interpolate(text, vars)
  end

  -- Handle missing translation
  return self:_handleMissing(locale, key, vars)
end

--- Check if a translation exists
-- @param key string Translation key
-- @param locale string|nil Locale to check (optional)
-- @return boolean
function I18n:has(key, locale)
  locale = locale or self.currentLocale or self.config.defaultLocale
  return self:_lookup(locale, key) ~= nil
end

--- Get text direction for a locale
-- @param locale string|nil Locale code (defaults to current)
-- @return string "ltr" or "rtl"
function I18n:getTextDirection(locale)
  locale = locale or self.currentLocale or self.config.defaultLocale

  -- Lazy load bidi module
  if not _bidi then
    _bidi = requireLazy("bidi")
  end

  if _bidi then
    return _bidi.getDirection(locale)
  end

  -- Fallback: check common RTL languages
  local rtlLanguages = {
    ar = true, he = true, fa = true, ur = true,
    yi = true, ps = true, sd = true, ug = true
  }

  local baseLang = locale:match("^(%a+)")
  return rtlLanguages[baseLang] and "rtl" or "ltr"
end

--- Wrap text with BiDi markers (only for RTL locales)
-- @param text string Text to wrap
-- @param locale string|nil Locale code
-- @return string Wrapped text (unchanged for LTR)
function I18n:wrapBidi(text, locale)
  locale = locale or self.currentLocale

  -- Lazy load bidi module
  if not _bidi then
    _bidi = requireLazy("bidi")
  end

  -- Only wrap if RTL
  local dir
  if _bidi then
    dir = _bidi.getDirection(locale)
  else
    dir = self:getTextDirection(locale)
  end

  if dir == "rtl" then
    if _bidi then
      return _bidi.wrap(text, "rtl")
    else
      -- Right-to-Left Embedding + text + Pop Directional Formatting
      return "\u{202B}" .. text .. "\u{202C}"
    end
  end

  return text
end

--- Get the native name of a locale
-- @param locale string Locale code
-- @return string Native name or locale code if not found
function I18n:getLocaleName(locale)
  -- Lazy load locale module
  if not _locale then
    _locale = requireLazy("locale")
  end

  if _locale and _locale.getNativeName then
    return _locale.getNativeName(locale)
  end

  -- Common locale names fallback
  local names = {
    en = "English",
    es = "Español",
    fr = "Français",
    de = "Deutsch",
    it = "Italiano",
    pt = "Português",
    ru = "Русский",
    zh = "中文",
    ja = "日本語",
    ko = "한국어",
    ar = "العربية",
    he = "עברית"
  }

  local baseLang = locale:match("^(%a+)")
  return names[baseLang] or locale
end

--- Get missing translations report
-- @return table Map of locale to list of missing keys
function I18n:getMissingTranslations()
  return self.missingKeys
end

--- Reload translations for a locale
-- @param locale string Locale code
-- @param filepath string|nil Path to translation file
-- @return boolean success
function I18n:reload(locale, filepath)
  -- Unload and reload
  self.stringTable[locale] = nil
  self.flatIndex[locale] = nil
  self:_clearCache(locale)

  return self:load(locale, filepath)
end

-- Private methods

--- Build fallback chain for a locale
-- @param locale string Starting locale
-- @return table Ordered list of locales to try
function I18n:_buildFallbackChain(locale)
  local chain = {}

  -- Use custom chain if set
  if self._customFallbackChain then
    return self._customFallbackChain
  end

  -- 1. Exact locale (e.g., "en-US")
  table.insert(chain, locale)

  -- 2. Base language (e.g., "en" from "en-US")
  local baseLang = locale:match("^(%a+)")
  if baseLang and baseLang ~= locale then
    table.insert(chain, baseLang)
  end

  -- 3. Fallback locale if different
  if self.config.fallbackLocale and
     self.config.fallbackLocale ~= locale and
     self.config.fallbackLocale ~= baseLang then
    table.insert(chain, self.config.fallbackLocale)
  end

  -- 4. Default locale if different
  if self.config.defaultLocale and
     self.config.defaultLocale ~= locale and
     self.config.defaultLocale ~= baseLang and
     self.config.defaultLocale ~= self.config.fallbackLocale then
    table.insert(chain, self.config.defaultLocale)
  end

  return chain
end

--- Lookup a key with fallback chain
-- @param locale string Starting locale
-- @param key string Translation key
-- @return string|nil Translation text or nil if not found
function I18n:_lookup(locale, key)
  local chain = self:_buildFallbackChain(locale)

  for _, loc in ipairs(chain) do
    if self.flatIndex[loc] and self.flatIndex[loc][key] then
      return self.flatIndex[loc][key]
    end
  end

  return nil
end

--- Flatten hierarchical data to dot notation
-- @param data table Hierarchical translation data
-- @param prefix string|nil Key prefix for recursion
-- @return table Flattened key-value map
function I18n:_flatten(data, prefix)
  local result = {}
  prefix = prefix or ""

  for key, value in pairs(data) do
    local fullKey = prefix == "" and key or (prefix .. "." .. key)

    if type(value) == "table" then
      local nested = self:_flatten(value, fullKey)
      for k, v in pairs(nested) do
        result[k] = v
      end
    else
      result[fullKey] = tostring(value)
    end
  end

  return result
end

--- Interpolate variables into text
-- @param text string Text with {var} placeholders
-- @param vars table Variable values
-- @return string Interpolated text
function I18n:_interpolate(text, vars)
  if not vars or not next(vars) then
    return text
  end

  -- Lazy load interpolation module
  if not _interpolation then
    _interpolation = requireLazy("interpolation")
  end

  if _interpolation then
    return _interpolation.interpolate(text, vars)
  end

  -- Simple fallback interpolation
  return (text:gsub("{(%w+)}", function(var)
    local value = vars[var]
    if value ~= nil then
      return tostring(value)
    end
    return "{" .. var .. "}"
  end))
end

--- Handle missing translation
-- @param locale string Locale that was requested
-- @param key string Key that was not found
-- @param vars table Variables that were passed
-- @return string Fallback text
function I18n:_handleMissing(locale, key, vars)
  -- Log warning
  if self.config.logMissing and self.log then
    self.log:warn("Missing translation: locale=%s key=%s", locale, key)
  end

  -- Track for reporting
  self.missingKeys[locale] = self.missingKeys[locale] or {}

  -- Avoid duplicates
  local found = false
  for _, k in ipairs(self.missingKeys[locale]) do
    if k == key then
      found = true
      break
    end
  end
  if not found then
    table.insert(self.missingKeys[locale], key)
  end

  -- Call custom handler
  if self.config.onMissingTranslation then
    return self.config.onMissingTranslation(locale, key, vars)
  end

  -- Strict mode throws error
  if self.config.strictMode then
    error(string.format("Missing translation: locale=%s key=%s", locale, key))
  end

  -- Default: return key name in brackets
  return "[MISSING: " .. key .. "]"
end

--- Detect locale from platform
-- @return string|nil Detected locale or nil
function I18n:_detectLocale()
  -- Lazy load locale module
  if not _locale then
    _locale = requireLazy("locale")
  end

  if _locale and _locale.detect then
    return _locale.detect()
  end

  -- Fallback: check environment variable
  local lang = os.getenv and os.getenv("LANG")
  if lang then
    -- Parse LANG format: en_US.UTF-8 → en-US
    local code = lang:match("^(%a+)_?(%a*)")
    if code then
      return code
    end
  end

  return nil
end

--- Resolve load path template
-- @param locale string Locale code
-- @return string Resolved file path
function I18n:_resolveLoadPath(locale)
  return (self.config.loadPath:gsub("{locale}", locale))
end

--- Load a Lua file
-- @param filepath string Path to .lua file
-- @return table|nil, string|nil Data and optional error
function I18n:_loadLuaFile(filepath)
  local func, err = loadfile(filepath)
  if not func then
    return nil, err
  end

  local ok, data = pcall(func)
  if not ok then
    return nil, data
  end

  return data
end

--- Clear interpolation cache
-- @param locale string|nil Specific locale or all if nil
function I18n:_clearCache(locale)
  if locale then
    -- Clear entries for specific locale
    local newCache = {}
    for key, value in pairs(self._interpCache) do
      if not key:match("^" .. locale .. ":") then
        newCache[key] = value
      end
    end
    self._interpCache = newCache
  else
    self._interpCache = {}
  end
end

--- Count keys in a table
-- @param tbl table Table to count
-- @return number Key count
function I18n:_countKeys(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

-- Event listener support
function I18n:on(event, callback)
  if self.events then
    self.events:on("i18n:" .. event, callback)
  end
end

function I18n:off(event, callback)
  if self.events then
    self.events:off("i18n:" .. event, callback)
  end
end

return M
