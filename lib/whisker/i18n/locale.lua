-- lib/whisker/i18n/locale.lua
-- Locale detection and management for whisker-core i18n
-- Stage 4: Locale Detection

local M = {}

-- Module version
M._VERSION = "1.0.0"

-- Dependencies
M._dependencies = {"logger"}

-- Registered platform adapters
local adapters = {}

-- Locale class
local Locale = {}
Locale.__index = Locale

--- Normalize locale tag to BCP 47
-- @param tag string Locale tag (e.g., "en_US.UTF-8")
-- @return string Normalized tag (e.g., "en-US")
local function normalizeLocaleTag(tag)
  if not tag or type(tag) ~= "string" then
    return nil
  end

  -- Remove encoding suffix (en_US.UTF-8 → en_US)
  tag = tag:match("^([^%.]+)") or tag

  -- Convert underscores to hyphens
  tag = tag:gsub("_", "-")

  -- Normalize case:
  -- - Language: lowercase (en)
  -- - Script: title case (Latn)
  -- - Region: uppercase (US)
  local parts = {}
  local i = 1
  for part in tag:gmatch("[^-]+") do
    if i == 1 then
      -- Language: lowercase
      table.insert(parts, part:lower())
    elseif #part == 4 then
      -- Script: title case
      table.insert(parts, part:sub(1,1):upper() .. part:sub(2):lower())
    else
      -- Region or variant: uppercase
      table.insert(parts, part:upper())
    end
    i = i + 1
  end

  return table.concat(parts, "-")
end

--- Build priority list for locale matching
-- @param locale string Locale tag (e.g., "zh-Hant-TW")
-- @return table Priority list {"zh-Hant-TW", "zh-Hant", "zh"}
local function buildPriorityList(locale)
  local list = { locale }
  local parts = {}

  for part in locale:gmatch("[^-]+") do
    table.insert(parts, part)
  end

  -- Build progressively shorter tags
  for i = #parts - 1, 1, -1 do
    local tag = table.concat(parts, "-", 1, i)
    table.insert(list, tag)
  end

  return list
end

--- Create a new Locale manager
-- @param deps table|nil Dependencies (logger)
-- @return Locale instance
function M.new(deps)
  deps = deps or {}

  local self = setmetatable({}, Locale)

  self.log = deps.logger
  self.config = {
    defaultLocale = "en",
    autoDetect = true,
    storage = nil,
    onLocaleChange = nil
  }
  self.currentLocale = nil
  self.availableLocales = {}
  self._adapters = {}
  self._initialized = false

  return self
end

--- Initialize locale system
-- @param config table Configuration
--   - defaultLocale: string
--   - autoDetect: boolean
--   - storage: table Storage adapter for persistence
--   - onLocaleChange: function Callback on locale change
function Locale:init(config)
  config = config or {}

  -- Merge configuration
  for key, value in pairs(config) do
    self.config[key] = value
  end

  -- Auto-detect if configured
  if self.config.autoDetect ~= false then
    self.currentLocale = self:detect()
  else
    self.currentLocale = self.config.defaultLocale or "en"
  end

  self._initialized = true
end

--- Detect locale from platform
-- @return string Detected locale code
function Locale:detect()
  -- Priority order:
  -- 1. Saved user preference
  -- 2. Platform detection
  -- 3. Default locale

  -- Try saved preference
  local saved = self:loadPreference()
  if saved then
    return saved
  end

  -- Try platform detection
  local detected = self:detectPlatform()
  if detected then
    return normalizeLocaleTag(detected)
  end

  -- Fall back to default
  return self.config.defaultLocale or "en"
end

--- Detect locale from platform adapters
-- @return string|nil Platform locale or nil
function Locale:detectPlatform()
  -- Try registered adapters first
  for _, adapter in ipairs(self._adapters) do
    if adapter.detect then
      local ok, locale = pcall(adapter.detect)
      if ok and locale then
        return locale
      end
    end
  end

  -- Try global adapters
  for _, adapter in ipairs(adapters) do
    if adapter.detect then
      local ok, locale = pcall(adapter.detect)
      if ok and locale then
        return locale
      end
    end
  end

  -- Try environment variables as fallback
  local envLocale = self:detectFromEnvironment()
  if envLocale then
    return envLocale
  end

  return nil
end

--- Detect locale from environment variables
-- @return string|nil Locale from environment or nil
function Locale:detectFromEnvironment()
  local envVars = { "LANG", "LC_ALL", "LC_MESSAGES", "LANGUAGE" }

  for _, var in ipairs(envVars) do
    local value = os.getenv(var)
    if value then
      return normalizeLocaleTag(value)
    end
  end

  return nil
end

--- Register a platform adapter
-- @param adapter table Adapter with detect() function
function Locale:registerAdapter(adapter)
  if adapter and type(adapter.detect) == "function" then
    table.insert(self._adapters, adapter)
  end
end

--- Set current locale
-- @param locale string Locale code to set
-- @param skipSave boolean|nil Skip saving preference (default: false)
-- @return boolean Success
function Locale:setLocale(locale, skipSave)
  if not locale then
    return false
  end

  -- Normalize the locale
  locale = normalizeLocaleTag(locale)

  -- Try to match to available locales
  local matched = self:matchLocale(locale, self.availableLocales)

  if not matched then
    -- If no available locales registered, accept the locale
    if #self.availableLocales == 0 then
      matched = locale
    else
      if self.log then
        self.log:warn("Locale not available: %s, using default", locale)
      end
      matched = self.config.defaultLocale
    end
  end

  local oldLocale = self.currentLocale
  self.currentLocale = matched

  -- Save preference
  if not skipSave then
    self:savePreference(matched)
  end

  -- Trigger callbacks
  if self.config.onLocaleChange and oldLocale ~= matched then
    self.config.onLocaleChange(matched, oldLocale)
  end

  return true
end

--- Get current locale
-- @return string Current locale code
function Locale:getLocale()
  return self.currentLocale or self.config.defaultLocale
end

--- Register available locale
-- @param locale string Locale code
function Locale:registerLocale(locale)
  locale = normalizeLocaleTag(locale)
  if not self:hasLocale(locale) then
    table.insert(self.availableLocales, locale)
  end
end

--- Unregister a locale
-- @param locale string Locale code
function Locale:unregisterLocale(locale)
  locale = normalizeLocaleTag(locale)
  for i, avail in ipairs(self.availableLocales) do
    if avail == locale then
      table.remove(self.availableLocales, i)
      return true
    end
  end
  return false
end

--- Check if locale is registered
-- @param locale string Locale code
-- @return boolean
function Locale:hasLocale(locale)
  locale = normalizeLocaleTag(locale)
  for _, available in ipairs(self.availableLocales) do
    if available == locale then
      return true
    end
  end
  return false
end

--- Get all available locales
-- @return table Array of locale codes
function Locale:getAvailableLocales()
  local copy = {}
  for _, loc in ipairs(self.availableLocales) do
    table.insert(copy, loc)
  end
  table.sort(copy)
  return copy
end

--- Match requested locale to available locales
-- Implements RFC 4647 "Lookup" algorithm
-- @param requested string Requested locale (e.g., "en-US")
-- @param available table Array of available locales
-- @return string|nil Best match or nil
function Locale:matchLocale(requested, available)
  if not requested or not available or #available == 0 then
    return nil
  end

  -- Normalize requested locale
  requested = normalizeLocaleTag(requested)

  -- Build priority list
  local priorityList = buildPriorityList(requested)

  -- Try each in priority order
  for _, candidate in ipairs(priorityList) do
    for _, locale in ipairs(available) do
      if locale == candidate then
        return locale
      end
    end
  end

  -- Try language-only matching for available locales
  local requestedLang = requested:match("^([^-]+)")
  if requestedLang then
    for _, locale in ipairs(available) do
      local availLang = locale:match("^([^-]+)")
      if availLang == requestedLang then
        return locale
      end
    end
  end

  return nil
end

--- Save locale preference
-- @param locale string Locale to save
function Locale:savePreference(locale)
  if self.config.storage then
    pcall(function()
      self.config.storage:set("whisker_locale", locale)
    end)
  end
end

--- Load saved locale preference
-- @return string|nil Saved locale or nil
function Locale:loadPreference()
  if self.config.storage then
    local ok, result = pcall(function()
      return self.config.storage:get("whisker_locale")
    end)
    if ok and result then
      return result
    end
  end
  return nil
end

--- Clear saved locale preference
function Locale:clearPreference()
  if self.config.storage then
    pcall(function()
      self.config.storage:set("whisker_locale", nil)
    end)
  end
end

--- Get the native name of a locale
-- @param locale string Locale code
-- @return string Native name or locale code
function Locale:getNativeName(locale)
  local names = {
    en = "English",
    ["en-US"] = "English (US)",
    ["en-GB"] = "English (UK)",
    ["en-AU"] = "English (Australia)",
    es = "Español",
    ["es-ES"] = "Español (España)",
    ["es-MX"] = "Español (México)",
    fr = "Français",
    ["fr-FR"] = "Français (France)",
    ["fr-CA"] = "Français (Canada)",
    de = "Deutsch",
    ["de-DE"] = "Deutsch (Deutschland)",
    it = "Italiano",
    pt = "Português",
    ["pt-BR"] = "Português (Brasil)",
    ["pt-PT"] = "Português (Portugal)",
    ru = "Русский",
    zh = "中文",
    ["zh-CN"] = "简体中文",
    ["zh-TW"] = "繁體中文",
    ["zh-Hans"] = "简体中文",
    ["zh-Hant"] = "繁體中文",
    ja = "日本語",
    ko = "한국어",
    ar = "العربية",
    he = "עברית",
    hi = "हिन्दी",
    th = "ไทย",
    vi = "Tiếng Việt",
    tr = "Türkçe",
    pl = "Polski",
    nl = "Nederlands",
    sv = "Svenska",
    no = "Norsk",
    da = "Dansk",
    fi = "Suomi",
    cs = "Čeština",
    hu = "Magyar",
    ro = "Română",
    uk = "Українська",
    el = "Ελληνικά",
    id = "Bahasa Indonesia",
    ms = "Bahasa Melayu",
    tl = "Tagalog"
  }

  locale = normalizeLocaleTag(locale)
  return names[locale] or names[locale:match("^([^-]+)")] or locale
end

--- Get text direction for locale
-- @param locale string|nil Locale code (defaults to current)
-- @return string "ltr" or "rtl"
function Locale:getTextDirection(locale)
  locale = locale or self.currentLocale or self.config.defaultLocale

  local rtlLanguages = {
    ar = true, he = true, fa = true, ur = true,
    yi = true, ps = true, sd = true, ug = true,
    dv = true, ha = true, ku = true, ckb = true
  }

  local baseLang = locale:match("^(%a+)")
  return rtlLanguages[baseLang] and "rtl" or "ltr"
end

--- Check if locale is right-to-left
-- @param locale string|nil Locale code
-- @return boolean
function Locale:isRTL(locale)
  return self:getTextDirection(locale) == "rtl"
end

--- Parse a locale string into components
-- @param locale string Locale tag
-- @return table Components {language, script, region, variants}
function Locale:parseLocale(locale)
  locale = normalizeLocaleTag(locale)
  local parts = {}
  for part in locale:gmatch("[^-]+") do
    table.insert(parts, part)
  end

  local result = {
    language = parts[1],
    script = nil,
    region = nil,
    variants = {}
  }

  for i = 2, #parts do
    local part = parts[i]
    if #part == 4 and not result.script then
      result.script = part
    elseif #part == 2 and not result.region then
      result.region = part
    else
      table.insert(result.variants, part)
    end
  end

  return result
end

--- Build a locale string from components
-- @param components table {language, script, region, variants}
-- @return string Locale tag
function Locale:buildLocale(components)
  local parts = { components.language }

  if components.script then
    table.insert(parts, components.script)
  end

  if components.region then
    table.insert(parts, components.region)
  end

  if components.variants then
    for _, variant in ipairs(components.variants) do
      table.insert(parts, variant)
    end
  end

  return table.concat(parts, "-")
end

-- Export helper functions for testing
M.normalizeLocaleTag = normalizeLocaleTag
M.buildPriorityList = buildPriorityList

--- Register a global adapter (for all Locale instances)
-- @param adapter table Adapter with detect() function
function M.registerGlobalAdapter(adapter)
  if adapter and type(adapter.detect) == "function" then
    table.insert(adapters, adapter)
  end
end

--- Clear all global adapters
function M.clearGlobalAdapters()
  adapters = {}
end

return M
