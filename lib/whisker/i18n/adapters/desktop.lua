-- lib/whisker/i18n/adapters/desktop.lua
-- Desktop OS locale detection adapter
-- Stage 4: Locale Detection

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Detect locale from OS
-- @return string|nil OS locale or nil
function M.detect()
  -- Try environment variables first (most reliable)
  local locale = M.detectFromEnvironment()
  if locale then
    return locale
  end

  -- Try platform-specific detection
  if M.isWindows() then
    return M.detectWindows()
  else
    return M.detectUnix()
  end
end

--- Check if running on Windows
-- @return boolean
function M.isWindows()
  -- Check path separator
  return package.config:sub(1, 1) == "\\"
end

--- Detect locale from environment variables
-- @return string|nil Locale or nil
function M.detectFromEnvironment()
  local envVars = { "LANG", "LC_ALL", "LC_MESSAGES", "LANGUAGE" }

  for _, var in ipairs(envVars) do
    local value = os.getenv(var)
    if value and value ~= "" and value ~= "C" and value ~= "POSIX" then
      -- Extract locale code (e.g., "en_US.UTF-8" → "en-US")
      local locale = value:match("^([^%.@]+)")
      if locale then
        locale = locale:gsub("_", "-")
        return locale
      end
    end
  end

  return nil
end

--- Detect locale on Windows
-- @return string|nil Locale or nil
function M.detectWindows()
  -- Try to get locale from PowerShell
  local handle = io.popen('powershell -Command "(Get-Culture).Name" 2>nul')
  if handle then
    local output = handle:read("*l")
    handle:close()

    if output and output ~= "" then
      return output
    end
  end

  -- Fallback: try systeminfo
  local handle2 = io.popen("wmic os get locale 2>nul")
  if handle2 then
    local output = handle2:read("*all")
    handle2:close()

    local localeId = output:match("(%x+)")
    if localeId then
      return M.windowsLocaleIdToBCP47(localeId)
    end
  end

  return nil
end

--- Detect locale on Unix-like systems
-- @return string|nil Locale or nil
function M.detectUnix()
  -- Try locale command
  local handle = io.popen("locale 2>/dev/null | grep LANG=")
  if handle then
    local output = handle:read("*all")
    handle:close()

    local locale = output:match('LANG="?([^"\n]+)')
    if locale and locale ~= "" and locale ~= "C" and locale ~= "POSIX" then
      locale = locale:match("^([^%.@]+)")
      if locale then
        locale = locale:gsub("_", "-")
        return locale
      end
    end
  end

  -- Try defaults read on macOS
  local handle2 = io.popen("defaults read -g AppleLocale 2>/dev/null")
  if handle2 then
    local output = handle2:read("*l")
    handle2:close()

    if output and output ~= "" then
      output = output:gsub("_", "-")
      return output
    end
  end

  return nil
end

--- Convert Windows locale ID to BCP 47
-- @param localeId string Hex locale ID
-- @return string BCP 47 code
function M.windowsLocaleIdToBCP47(localeId)
  -- Mapping of common Windows locale IDs
  local mapping = {
    ["0409"] = "en-US",
    ["0809"] = "en-GB",
    ["0c09"] = "en-AU",
    ["1009"] = "en-CA",
    ["040a"] = "es-ES",
    ["080a"] = "es-MX",
    ["0c0a"] = "es-ES",  -- Modern sort
    ["040c"] = "fr-FR",
    ["0c0c"] = "fr-CA",
    ["0407"] = "de-DE",
    ["0807"] = "de-CH",
    ["0c07"] = "de-AT",
    ["0410"] = "it-IT",
    ["0411"] = "ja-JP",
    ["0412"] = "ko-KR",
    ["0804"] = "zh-CN",
    ["0404"] = "zh-TW",
    ["0c04"] = "zh-HK",
    ["0416"] = "pt-BR",
    ["0816"] = "pt-PT",
    ["0419"] = "ru-RU",
    ["041f"] = "tr-TR",
    ["0401"] = "ar-SA",
    ["0413"] = "nl-NL",
    ["0813"] = "nl-BE",
    ["0415"] = "pl-PL",
    ["0405"] = "cs-CZ",
    ["040e"] = "hu-HU",
    ["0418"] = "ro-RO",
    ["0408"] = "el-GR",
    ["040d"] = "he-IL",
    ["0422"] = "uk-UA",
    ["041e"] = "th-TH",
    ["042a"] = "vi-VN",
    ["0421"] = "id-ID",
    ["041d"] = "sv-SE",
    ["0414"] = "nb-NO",
    ["0406"] = "da-DK",
    ["040b"] = "fi-FI"
  }

  localeId = localeId:lower()
  return mapping[localeId] or "en-US"
end

return M
