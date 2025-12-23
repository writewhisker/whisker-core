-- lib/whisker/i18n/formats/init.lua
-- Format registry and auto-detection for translation files
-- Stage 3: Translation File Format Support

local M = {}

-- Module version
M._VERSION = "1.0.0"

-- Registered format handlers
local handlers = {}

-- Lazy-loaded format modules
local _yaml
local _json
local _lua

--- Register a format handler
-- @param extension string File extension (e.g., "yml")
-- @param handler table Handler with load() function
function M.register(extension, handler)
  handlers[extension] = handler
end

--- Detect format from filepath
-- @param filepath string Path to translation file
-- @return string|nil Format extension or nil
function M.detect(filepath)
  if type(filepath) ~= "string" then
    return nil
  end

  -- Try extensions in order of specificity
  local patterns = {
    { pattern = "%.yaml$", format = "yaml" },
    { pattern = "%.yml$", format = "yml" },
    { pattern = "%.json$", format = "json" },
    { pattern = "%.lua$", format = "lua" }
  }

  for _, p in ipairs(patterns) do
    if filepath:match(p.pattern) then
      return p.format
    end
  end

  return nil
end

--- Get format handler for extension
-- @param format string Format extension
-- @return table|nil Handler or nil
function M.getHandler(format)
  -- Normalize extension (yaml and yml both use yaml handler)
  local normalizedFormat = format
  if format == "yaml" then
    normalizedFormat = "yml"
  end

  -- Lazy load handlers on first use
  if not handlers[normalizedFormat] then
    if normalizedFormat == "yml" or normalizedFormat == "yaml" then
      if not _yaml then
        local ok, mod = pcall(require, "whisker.i18n.formats.yaml")
        if ok then
          _yaml = mod
          handlers["yml"] = _yaml
          handlers["yaml"] = _yaml
        end
      end
    elseif normalizedFormat == "json" then
      if not _json then
        local ok, mod = pcall(require, "whisker.i18n.formats.json")
        if ok then
          _json = mod
          handlers["json"] = _json
        end
      end
    elseif normalizedFormat == "lua" then
      if not _lua then
        local ok, mod = pcall(require, "whisker.i18n.formats.lua")
        if ok then
          _lua = mod
          handlers["lua"] = _lua
        end
      end
    end
  end

  return handlers[normalizedFormat]
end

--- Load translation file using appropriate handler
-- @param filepath string Path to file
-- @return table|nil, string Translation data and format (or nil and error)
function M.loadFile(filepath)
  local format = M.detect(filepath)

  if not format then
    return nil, "Cannot detect format for file: " .. filepath
  end

  local handler = M.getHandler(format)
  if not handler then
    return nil, "No handler registered for format: " .. format
  end

  local ok, data = pcall(handler.load, filepath)
  if not ok then
    return nil, data
  end

  return data, format
end

--- Load translation from string using specified format
-- @param content string File content
-- @param format string Format (yml, json, lua)
-- @return table|nil, string Translation data or nil and error
function M.loadString(content, format)
  local handler = M.getHandler(format)
  if not handler then
    return nil, "No handler registered for format: " .. format
  end

  if not handler.loadString then
    return nil, "Format " .. format .. " does not support loadString"
  end

  local ok, data = pcall(handler.loadString, content)
  if not ok then
    return nil, data
  end

  return data
end

--- Get list of supported formats
-- @return table List of format extensions
function M.getSupportedFormats()
  return { "yml", "yaml", "json", "lua" }
end

--- Check if format is supported
-- @param format string Format extension
-- @return boolean
function M.isSupported(format)
  local supported = { yml = true, yaml = true, json = true, lua = true }
  return supported[format] or false
end

return M
