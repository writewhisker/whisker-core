-- lib/whisker/i18n/pluralization.lua
-- Pluralization engine for whisker-core i18n
-- Stage 5: Pluralization Rules

local M = {}

-- Module version
M._VERSION = "1.0.0"

-- Dependencies
M._dependencies = {}

-- Plural rule functions indexed by language code
local pluralRules = nil

-- Pluralization class
local Pluralization = {}
Pluralization.__index = Pluralization

--- Create a new Pluralization instance
-- @return Pluralization instance
function M.new(deps)
  deps = deps or {}
  local self = setmetatable({}, Pluralization)
  self._initialized = false
  return self
end

--- Initialize pluralization system
-- @param config table|nil Configuration
function Pluralization:init(config)
  self.config = config or {}

  -- Load plural rules
  self:loadRules()

  self._initialized = true
end

--- Load plural rules from data file
function Pluralization:loadRules()
  if not pluralRules then
    local ok, rules = pcall(require, "whisker.i18n.data.plural_rules")
    if ok then
      pluralRules = rules
    else
      -- Fallback: minimal rules
      pluralRules = {
        en = function(n)
          return (math.floor(n) == 1 and n == math.floor(n)) and "one" or "other"
        end
      }
    end
  end
end

--- Get plural category for count in locale
-- @param locale string Locale code (e.g., "en", "ru-RU")
-- @param count number Count value
-- @return string Plural category (zero, one, two, few, many, other)
function Pluralization:getCategory(locale, count)
  -- Ensure rules are loaded
  if not pluralRules then
    self:loadRules()
  end

  -- Handle nil or invalid count
  if type(count) ~= "number" then
    count = tonumber(count) or 0
  end

  -- Extract language from locale (en-US → en)
  local lang = locale:match("^([^-]+)")

  -- Get rule function for language
  local ruleFn = pluralRules[lang]

  if not ruleFn then
    -- Unknown language: default to "other"
    return "other"
  end

  -- Apply rule
  return ruleFn(count)
end

--- Pluralize a translation key
-- @param key string Base translation key (e.g., "items.count")
-- @param count number Count value
-- @param locale string Target locale
-- @param stringTable table StringTable instance
-- @return string|nil Pluralized translation or nil
function Pluralization:pluralize(key, count, locale, stringTable)
  -- Get plural category
  local category = self:getCategory(locale, count)

  -- Try to find translation for category
  local categoryKey = key .. "." .. category
  local text = stringTable:lookup(locale, categoryKey)

  if text then
    return text
  end

  -- Fallback to "other" category if different
  if category ~= "other" then
    local otherKey = key .. ".other"
    text = stringTable:lookup(locale, otherKey)
    if text then
      return text
    end
  end

  -- Not found
  return nil
end

--- Get supported languages
-- @return table Array of language codes
function Pluralization:getSupportedLanguages()
  if not pluralRules then
    self:loadRules()
  end

  local langs = {}
  for lang, _ in pairs(pluralRules) do
    table.insert(langs, lang)
  end
  table.sort(langs)
  return langs
end

--- Check if language is supported
-- @param lang string Language code
-- @return boolean
function Pluralization:isLanguageSupported(lang)
  if not pluralRules then
    self:loadRules()
  end

  -- Extract base language
  lang = lang:match("^([^-]+)")
  return pluralRules[lang] ~= nil
end

--- Get plural categories available for a language
-- @param locale string Locale code
-- @return table Array of category names
function Pluralization:getCategoriesForLanguage(locale)
  -- Map of languages to their plural categories
  local categoryMap = {
    -- 1 form: other only
    ja = { "other" },
    zh = { "other" },
    ko = { "other" },
    vi = { "other" },
    th = { "other" },
    id = { "other" },
    ms = { "other" },

    -- 2 forms: one, other
    en = { "one", "other" },
    de = { "one", "other" },
    es = { "one", "other" },
    it = { "one", "other" },
    nl = { "one", "other" },
    sv = { "one", "other" },
    da = { "one", "other" },
    fi = { "one", "other" },
    el = { "one", "other" },
    hu = { "one", "other" },
    tr = { "one", "other" },
    pt = { "one", "other" },
    fr = { "one", "other" },
    hi = { "one", "other" },
    fa = { "one", "other" },
    ur = { "one", "other" },

    -- 3 forms
    ru = { "one", "few", "many" },
    uk = { "one", "few", "many" },
    pl = { "one", "few", "many" },
    cs = { "one", "few", "many" },
    sk = { "one", "few", "many" },
    lt = { "one", "few", "other" },
    lv = { "zero", "one", "other" },
    ro = { "one", "few", "other" },

    -- 4 forms
    sl = { "one", "two", "few", "other" },
    he = { "one", "two", "many", "other" },
    mt = { "one", "few", "many", "other" },

    -- 5 forms
    ga = { "one", "two", "few", "many", "other" },

    -- 6 forms
    ar = { "zero", "one", "two", "few", "many", "other" },
    cy = { "zero", "one", "two", "few", "many", "other" }
  }

  local lang = locale:match("^([^-]+)")
  return categoryMap[lang] or { "one", "other" }  -- Default to 2 forms
end

--- Get the number of plural forms for a language
-- @param locale string Locale code
-- @return number Number of forms
function Pluralization:getFormCount(locale)
  local categories = self:getCategoriesForLanguage(locale)
  return #categories
end

-- Module-level function for quick access
function M.getCategory(locale, count)
  if not pluralRules then
    local ok, rules = pcall(require, "whisker.i18n.data.plural_rules")
    if ok then
      pluralRules = rules
    else
      return "other"
    end
  end

  if type(count) ~= "number" then
    count = tonumber(count) or 0
  end

  local lang = locale:match("^([^-]+)")
  local ruleFn = pluralRules[lang]

  if not ruleFn then
    return "other"
  end

  return ruleFn(count)
end

return M
