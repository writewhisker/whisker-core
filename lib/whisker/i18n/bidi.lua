-- lib/whisker/i18n/bidi.lua
-- Bidirectional text support for RTL languages
-- Stage 6: RTL Support

local M = {}

-- Module version
M._VERSION = "1.0.0"

-- RTL language codes
local RTL_LANGUAGES = {
  ar = true,   -- Arabic
  he = true,   -- Hebrew
  fa = true,   -- Persian/Farsi
  ur = true,   -- Urdu
  yi = true,   -- Yiddish
  iw = true,   -- Hebrew (old ISO code)
  ji = true,   -- Yiddish (old ISO code)
  ps = true,   -- Pashto
  sd = true,   -- Sindhi
  ug = true,   -- Uyghur
  dv = true,   -- Dhivehi
  ha = true,   -- Hausa (when written in Arabic script)
  ku = true,   -- Kurdish (when written in Arabic script)
  ckb = true   -- Central Kurdish
}

-- Unicode BiDi control characters
local BIDI_MARKS = {
  -- Directional marks
  LRM = "\xE2\x80\x8E",  -- U+200E Left-to-Right Mark
  RLM = "\xE2\x80\x8F",  -- U+200F Right-to-Left Mark

  -- Embedding (deprecated in favor of isolates)
  LRE = "\xE2\x80\xAA",  -- U+202A Left-to-Right Embedding
  RLE = "\xE2\x80\xAB",  -- U+202B Right-to-Left Embedding
  PDF = "\xE2\x80\xAC",  -- U+202C Pop Directional Formatting

  -- Overrides
  LRO = "\xE2\x80\xAD",  -- U+202D Left-to-Right Override
  RLO = "\xE2\x80\xAE",  -- U+202E Right-to-Left Override

  -- Isolates (recommended for modern use)
  LRI = "\xE2\x81\xA6",  -- U+2066 Left-to-Right Isolate
  RLI = "\xE2\x81\xA7",  -- U+2067 Right-to-Left Isolate
  FSI = "\xE2\x81\xA8",  -- U+2068 First Strong Isolate
  PDI = "\xE2\x81\xA9"   -- U+2069 Pop Directional Isolate
}

-- Export BIDI_MARKS for direct access
M.MARKS = BIDI_MARKS

--- Get text direction for locale
-- @param locale string Locale code (e.g., "ar", "ar-SA", "en-US")
-- @return string "rtl" or "ltr"
function M.getDirection(locale)
  if not locale or type(locale) ~= "string" then
    return "ltr"
  end

  -- Extract language code (before hyphen)
  local lang = locale:match("^([^-]+)")

  if lang and RTL_LANGUAGES[lang:lower()] then
    return "rtl"
  else
    return "ltr"
  end
end

--- Check if locale is RTL
-- @param locale string Locale code
-- @return boolean
function M.isRTL(locale)
  return M.getDirection(locale) == "rtl"
end

--- Check if locale is LTR
-- @param locale string Locale code
-- @return boolean
function M.isLTR(locale)
  return M.getDirection(locale) == "ltr"
end

--- Wrap text with directional embedding markers
-- @param text string Text to wrap
-- @param direction string "rtl", "ltr", or locale code
-- @return string Wrapped text
function M.wrap(text, direction)
  if not text or text == "" then
    return text or ""
  end

  -- If direction is locale code, get actual direction
  if direction ~= "rtl" and direction ~= "ltr" then
    direction = M.getDirection(direction)
  end

  if direction == "rtl" then
    return BIDI_MARKS.RLE .. text .. BIDI_MARKS.PDF
  else
    return BIDI_MARKS.LRE .. text .. BIDI_MARKS.PDF
  end
end

--- Wrap text with isolation markers (recommended for modern use)
-- @param text string Text to isolate
-- @param direction string "rtl", "ltr", "auto", or locale code
-- @return string Isolated text
function M.isolate(text, direction)
  if not text or text == "" then
    return text or ""
  end

  local startMark

  -- Determine the start marker
  if direction == "rtl" then
    startMark = BIDI_MARKS.RLI
  elseif direction == "ltr" then
    startMark = BIDI_MARKS.LRI
  elseif direction == "auto" then
    startMark = BIDI_MARKS.FSI
  else
    -- Assume it's a locale code
    local dir = M.getDirection(direction)
    startMark = (dir == "rtl") and BIDI_MARKS.RLI or BIDI_MARKS.LRI
  end

  return startMark .. text .. BIDI_MARKS.PDI
end

--- Add directional mark before text (for inline use)
-- @param text string Text to mark
-- @param direction string "rtl" or "ltr"
-- @return string Marked text
function M.mark(text, direction)
  if not text then
    return ""
  end

  if direction == "rtl" then
    return BIDI_MARKS.RLM .. text
  else
    return BIDI_MARKS.LRM .. text
  end
end

--- Generate HTML dir attribute
-- @param locale string Locale code
-- @return string HTML attribute (e.g., 'dir="rtl"')
function M.htmlDir(locale)
  local direction = M.getDirection(locale)
  return string.format('dir="%s"', direction)
end

--- Generate HTML span element with direction
-- @param text string Text content
-- @param locale string Locale code
-- @return string HTML span element
function M.htmlSpan(text, locale)
  local direction = M.getDirection(locale)
  -- Escape HTML entities in text
  local escaped = text:gsub("&", "&amp;")
                      :gsub("<", "&lt;")
                      :gsub(">", "&gt;")
                      :gsub('"', "&quot;")
  return string.format('<span dir="%s">%s</span>', direction, escaped)
end

--- Generate HTML bdi element (bidirectional isolate)
-- @param text string Text content
-- @param locale string|nil Optional locale code
-- @return string HTML bdi element
function M.htmlBdi(text, locale)
  local escaped = text:gsub("&", "&amp;")
                      :gsub("<", "&lt;")
                      :gsub(">", "&gt;")
                      :gsub('"', "&quot;")

  if locale then
    local direction = M.getDirection(locale)
    return string.format('<bdi dir="%s">%s</bdi>', direction, escaped)
  else
    return string.format('<bdi>%s</bdi>', escaped)
  end
end

--- Get CSS direction property value
-- @param locale string Locale code
-- @return string CSS direction value
function M.cssDirection(locale)
  return M.getDirection(locale)
end

--- Get CSS text-align value for direction
-- @param locale string Locale code
-- @return string CSS text-align value
function M.cssTextAlign(locale)
  local direction = M.getDirection(locale)
  return direction == "rtl" and "right" or "left"
end

--- Detect direction from text content (first strong character)
-- @param text string Text to analyze
-- @return string "rtl", "ltr", or "neutral"
function M.detectFromText(text)
  if not text or text == "" then
    return "neutral"
  end

  -- Iterate through UTF-8 bytes
  local i = 1
  local len = #text

  while i <= len do
    local byte = text:byte(i)

    -- Determine UTF-8 character length
    local charLen
    if byte < 128 then
      charLen = 1
    elseif byte < 224 then
      charLen = 2
    elseif byte < 240 then
      charLen = 3
    else
      charLen = 4
    end

    -- For single-byte ASCII, check Latin letters
    if charLen == 1 then
      if (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) then
        return "ltr"
      end
    elseif charLen >= 2 then
      -- For multi-byte characters, check Unicode ranges
      -- Hebrew: U+0590-U+05FF
      -- Arabic: U+0600-U+06FF
      -- Arabic Supplement: U+0750-U+077F
      -- Arabic Extended-A: U+08A0-U+08FF
      -- Hebrew Presentation Forms: U+FB1D-U+FB4F
      -- Arabic Presentation Forms-A: U+FB50-U+FDFF
      -- Arabic Presentation Forms-B: U+FE70-U+FEFF

      if charLen == 2 then
        -- Check 2-byte sequences
        local b1, b2 = text:byte(i), text:byte(i + 1)
        if b1 == 0xD6 or b1 == 0xD7 then
          -- Hebrew range (U+0590-U+05FF)
          return "rtl"
        elseif b1 == 0xD8 or b1 == 0xD9 or b1 == 0xDA or b1 == 0xDB then
          -- Arabic ranges (U+0600-U+06FF, U+0750-U+077F)
          return "rtl"
        end
      elseif charLen == 3 then
        -- Check 3-byte sequences
        local b1, b2 = text:byte(i), text:byte(i + 1)
        if b1 == 0xE0 then
          if b2 >= 0xA0 and b2 <= 0xA3 then
            -- Arabic Extended-A
            return "rtl"
          end
        elseif b1 == 0xEF then
          -- Presentation forms
          if b2 >= 0xAC and b2 <= 0xBB then
            return "rtl"
          end
        end
      end
    end

    i = i + charLen
  end

  return "neutral"
end

--- Strip BiDi control characters from text
-- @param text string Text to clean
-- @return string Cleaned text
function M.stripMarks(text)
  if not text then
    return ""
  end

  -- Remove all BiDi control characters
  for _, mark in pairs(BIDI_MARKS) do
    text = text:gsub(mark, "")
  end

  return text
end

--- Check if text contains RTL characters
-- @param text string Text to check
-- @return boolean
function M.containsRTL(text)
  return M.detectFromText(text) == "rtl"
end

--- Get list of RTL language codes
-- @return table Array of RTL language codes
function M.getRTLLanguages()
  local langs = {}
  for lang, _ in pairs(RTL_LANGUAGES) do
    table.insert(langs, lang)
  end
  table.sort(langs)
  return langs
end

--- Check if a language code is RTL
-- @param lang string Language code (not full locale)
-- @return boolean
function M.isRTLLanguage(lang)
  if not lang then
    return false
  end
  return RTL_LANGUAGES[lang:lower()] or false
end

return M
