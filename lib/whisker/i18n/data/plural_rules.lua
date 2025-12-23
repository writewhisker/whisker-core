-- lib/whisker/i18n/data/plural_rules.lua
-- CLDR plural rules for internationalization
-- Stage 5: Pluralization Rules
-- Based on Unicode CLDR data

local rules = {}

-- Helper function to calculate number of decimal digits
local function getDecimalDigits(n)
  if n == math.floor(n) then
    return 0
  end
  local str = tostring(n)
  local decimalPart = str:match("%.(%d+)")
  return decimalPart and #decimalPart or 0
end

-- ============================================================================
-- European/Western Languages (mostly 2 forms: one/other)
-- ============================================================================

-- English (en): 2 forms
-- one: i = 1 and v = 0 (exactly 1 with no decimal)
-- other: everything else
rules["en"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if i == 1 and v == 0 then
    return "one"
  end
  return "other"
end

-- German (de): same as English
rules["de"] = rules["en"]

-- Dutch (nl): same as English
rules["nl"] = rules["en"]

-- Italian (it): same as English
rules["it"] = rules["en"]

-- Spanish (es): same as English
rules["es"] = rules["en"]

-- Portuguese (pt): 2 forms
-- one: i = 0..1 (0 and 1 are singular in some variants)
rules["pt"] = function(n)
  local i = math.floor(math.abs(n))
  if i == 0 or i == 1 then
    return "one"
  end
  return "other"
end

-- Brazilian Portuguese: same as regular Portuguese
rules["pt-BR"] = rules["pt"]

-- French (fr): 2 forms
-- one: i = 0..1 (both 0 and 1 are singular)
-- other: everything else
rules["fr"] = function(n)
  local i = math.floor(math.abs(n))
  if i == 0 or i == 1 then
    return "one"
  end
  return "other"
end

-- Swedish (sv): same as English
rules["sv"] = rules["en"]

-- Norwegian (no, nb, nn): same as English
rules["no"] = rules["en"]
rules["nb"] = rules["en"]
rules["nn"] = rules["en"]

-- Danish (da): same as English
rules["da"] = rules["en"]

-- Finnish (fi): same as English
rules["fi"] = rules["en"]

-- Greek (el): same as English
rules["el"] = rules["en"]

-- Hungarian (hu): same as English
rules["hu"] = rules["en"]

-- Turkish (tr): same as English
rules["tr"] = rules["en"]

-- ============================================================================
-- Slavic Languages (3-4 forms: one/few/many/other)
-- ============================================================================

-- Russian (ru): 3 forms
-- one: v = 0 and i % 10 = 1 and i % 100 != 11
-- few: v = 0 and i % 10 = 2..4 and i % 100 != 12..14
-- many: v = 0 and (i % 10 = 0 or i % 10 = 5..9 or i % 100 = 11..14)
-- other: decimals
rules["ru"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if v ~= 0 then
    return "other"
  end

  local mod10 = i % 10
  local mod100 = i % 100

  if mod10 == 1 and mod100 ~= 11 then
    return "one"
  elseif mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14) then
    return "few"
  else
    return "many"
  end
end

-- Ukrainian (uk): same as Russian
rules["uk"] = rules["ru"]

-- Belarusian (be): same as Russian
rules["be"] = rules["ru"]

-- Polish (pl): 3 forms
-- one: i = 1 and v = 0
-- few: v = 0 and i % 10 = 2..4 and i % 100 != 12..14
-- many: v = 0 and (i != 1 and i % 10 = 0..1 or i % 10 = 5..9 or i % 100 = 12..14)
rules["pl"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if i == 1 and v == 0 then
    return "one"
  end

  if v ~= 0 then
    return "other"
  end

  local mod10 = i % 10
  local mod100 = i % 100

  if mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14) then
    return "few"
  end

  return "many"
end

-- Czech (cs): 3 forms
-- one: i = 1 and v = 0
-- few: i = 2..4 and v = 0
-- many: v != 0
-- other: everything else
rules["cs"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if i == 1 and v == 0 then
    return "one"
  end

  if v ~= 0 then
    return "many"
  end

  if i >= 2 and i <= 4 then
    return "few"
  end

  return "other"
end

-- Slovak (sk): same as Czech
rules["sk"] = rules["cs"]

-- Croatian (hr): similar to Russian
rules["hr"] = rules["ru"]

-- Serbian (sr): similar to Russian
rules["sr"] = rules["ru"]

-- Slovenian (sl): 4 forms
-- one: v = 0 and i % 100 = 1
-- two: v = 0 and i % 100 = 2
-- few: v = 0 and i % 100 = 3..4 or v != 0
-- other: everything else
rules["sl"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if v == 0 then
    local mod100 = i % 100
    if mod100 == 1 then
      return "one"
    elseif mod100 == 2 then
      return "two"
    elseif mod100 == 3 or mod100 == 4 then
      return "few"
    end
  else
    return "few"
  end

  return "other"
end

-- Romanian (ro): 3 forms
-- one: i = 1 and v = 0
-- few: v != 0 or n = 0 or n % 100 = 2..19
-- other: everything else
rules["ro"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if i == 1 and v == 0 then
    return "one"
  end

  local mod100 = n % 100
  if v ~= 0 or n == 0 or (mod100 >= 2 and mod100 <= 19) then
    return "few"
  end

  return "other"
end

-- ============================================================================
-- Semitic Languages (Arabic, Hebrew - complex forms)
-- ============================================================================

-- Arabic (ar): 6 forms
-- zero: n = 0
-- one: n = 1
-- two: n = 2
-- few: n % 100 = 3..10
-- many: n % 100 = 11..99
-- other: everything else (100, 1000, etc.)
rules["ar"] = function(n)
  if n == 0 then
    return "zero"
  elseif n == 1 then
    return "one"
  elseif n == 2 then
    return "two"
  end

  local i = math.floor(math.abs(n))
  local mod100 = i % 100

  if mod100 >= 3 and mod100 <= 10 then
    return "few"
  elseif mod100 >= 11 and mod100 <= 99 then
    return "many"
  else
    return "other"
  end
end

-- Hebrew (he): 4 forms
-- one: i = 1 and v = 0
-- two: i = 2 and v = 0
-- many: v = 0 and (n != 0..10) and n % 10 = 0
-- other: everything else
rules["he"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if i == 1 and v == 0 then
    return "one"
  elseif i == 2 and v == 0 then
    return "two"
  elseif v == 0 and n ~= 0 and n > 10 and i % 10 == 0 then
    return "many"
  else
    return "other"
  end
end

-- ============================================================================
-- Asian Languages (mostly 1 form: other)
-- ============================================================================

-- Japanese (ja): 1 form
-- other: always
rules["ja"] = function(n)
  return "other"
end

-- Chinese (zh): 1 form - no grammatical number
rules["zh"] = rules["ja"]

-- Korean (ko): 1 form
rules["ko"] = rules["ja"]

-- Vietnamese (vi): 1 form
rules["vi"] = rules["ja"]

-- Thai (th): 1 form
rules["th"] = rules["ja"]

-- Indonesian (id): 1 form
rules["id"] = rules["ja"]

-- Malay (ms): 1 form
rules["ms"] = rules["ja"]

-- ============================================================================
-- Indic Languages
-- ============================================================================

-- Hindi (hi): 2 forms
-- one: i = 0 or n = 1
-- other: everything else
rules["hi"] = function(n)
  local i = math.floor(math.abs(n))
  if i == 0 or n == 1 then
    return "one"
  end
  return "other"
end

-- Bengali (bn): same as Hindi
rules["bn"] = rules["hi"]

-- Marathi (mr): same as Hindi
rules["mr"] = rules["hi"]

-- Gujarati (gu): same as Hindi
rules["gu"] = rules["hi"]

-- Punjabi (pa): 2 forms
-- one: n = 0..1
rules["pa"] = function(n)
  if n >= 0 and n <= 1 then
    return "one"
  end
  return "other"
end

-- Tamil (ta): same as English
rules["ta"] = rules["en"]

-- Telugu (te): same as English
rules["te"] = rules["en"]

-- Malayalam (ml): same as English
rules["ml"] = rules["en"]

-- Kannada (kn): same as Hindi
rules["kn"] = rules["hi"]

-- ============================================================================
-- Celtic Languages (complex systems)
-- ============================================================================

-- Irish (ga): 5 forms
-- one: n = 1
-- two: n = 2
-- few: n = 3..6
-- many: n = 7..10
-- other: everything else
rules["ga"] = function(n)
  if n == 1 then
    return "one"
  elseif n == 2 then
    return "two"
  elseif n >= 3 and n <= 6 then
    return "few"
  elseif n >= 7 and n <= 10 then
    return "many"
  end
  return "other"
end

-- Welsh (cy): 6 forms
-- zero: n = 0
-- one: n = 1
-- two: n = 2
-- few: n = 3
-- many: n = 6
-- other: everything else
rules["cy"] = function(n)
  if n == 0 then
    return "zero"
  elseif n == 1 then
    return "one"
  elseif n == 2 then
    return "two"
  elseif n == 3 then
    return "few"
  elseif n == 6 then
    return "many"
  end
  return "other"
end

-- ============================================================================
-- Baltic Languages
-- ============================================================================

-- Latvian (lv): 3 forms
-- zero: n % 10 = 0 or n % 100 = 11..19 or v = 2 and f % 100 = 11..19
-- one: n % 10 = 1 and n % 100 != 11 or v = 2 and f % 10 = 1 and f % 100 != 11 or v != 2 and f % 10 = 1
-- other: everything else
rules["lv"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  local mod10 = i % 10
  local mod100 = i % 100

  if mod10 == 0 or (mod100 >= 11 and mod100 <= 19) then
    return "zero"
  elseif mod10 == 1 and mod100 ~= 11 then
    return "one"
  end

  return "other"
end

-- Lithuanian (lt): 3 forms
-- one: n % 10 = 1 and n % 100 != 11..19
-- few: n % 10 = 2..9 and n % 100 != 11..19
-- other: everything else
rules["lt"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if v ~= 0 then
    return "other"
  end

  local mod10 = i % 10
  local mod100 = i % 100

  if mod10 == 1 and (mod100 < 11 or mod100 > 19) then
    return "one"
  elseif mod10 >= 2 and mod10 <= 9 and (mod100 < 11 or mod100 > 19) then
    return "few"
  end

  return "other"
end

-- ============================================================================
-- Other Languages
-- ============================================================================

-- Persian/Farsi (fa): 2 forms
-- one: i = 0 or n = 1
rules["fa"] = function(n)
  local i = math.floor(math.abs(n))
  if i == 0 or n == 1 then
    return "one"
  end
  return "other"
end

-- Urdu (ur): same as Farsi
rules["ur"] = rules["fa"]

-- Filipino/Tagalog (fil, tl): 2 forms
-- one: v = 0 and (i = 1..3 or v = 0 and i % 10 != 4..6..9 or v != 0 and f % 10 != 4..6..9)
rules["fil"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  if v == 0 then
    if i == 1 or i == 2 or i == 3 then
      return "one"
    end
    local mod10 = i % 10
    if mod10 ~= 4 and mod10 ~= 6 and mod10 ~= 9 then
      return "one"
    end
  end

  return "other"
end
rules["tl"] = rules["fil"]

-- Swahili (sw): same as English
rules["sw"] = rules["en"]

-- Afrikaans (af): same as English
rules["af"] = rules["en"]

-- Catalan (ca): same as English
rules["ca"] = rules["en"]

-- Basque (eu): same as English
rules["eu"] = rules["en"]

-- Icelandic (is): 2 forms
-- one: t = 0 and i % 10 = 1 and i % 100 != 11 or t != 0
rules["is"] = function(n)
  local i = math.floor(math.abs(n))
  local v = getDecimalDigits(n)

  local mod10 = i % 10
  local mod100 = i % 100

  if (v == 0 and mod10 == 1 and mod100 ~= 11) or v ~= 0 then
    return "one"
  end

  return "other"
end

-- Maltese (mt): 4 forms
-- one: n = 1
-- few: n = 0 or n % 100 = 2..10
-- many: n % 100 = 11..19
-- other: everything else
rules["mt"] = function(n)
  local i = math.floor(math.abs(n))

  if n == 1 then
    return "one"
  end

  local mod100 = i % 100

  if n == 0 or (mod100 >= 2 and mod100 <= 10) then
    return "few"
  elseif mod100 >= 11 and mod100 <= 19 then
    return "many"
  end

  return "other"
end

return rules
