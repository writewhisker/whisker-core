-- lib/whisker/script/text_parser.lua
-- Text parser for Whisker Script with i18n support
-- Stage 7: Whisker Script i18n Integration

local M = {}

-- Module version
M._VERSION = "1.0.0"

-- Lazy load i18n tags parser
local _i18nTags

local function getI18nTags()
  if not _i18nTags then
    local ok, mod = pcall(require, "whisker.script.i18n_tags")
    if ok then
      _i18nTags = mod
    end
  end
  return _i18nTags
end

--- Parse text content (may include i18n tags)
-- @param text string Text to parse
-- @return table AST node
function M.parse(text)
  if not text or text == "" then
    return {
      type = "text_block",
      nodes = {}
    }
  end

  local nodes = {}
  local I18nTags = getI18nTags()

  -- Split text on @@t and @@p markers
  local parts = M.split(text)

  for _, part in ipairs(parts) do
    if part:match("^@@[tp]%s") then
      -- i18n tag
      if I18nTags then
        local node = I18nTags.parse(part)
        if node then
          table.insert(nodes, node)
        else
          error("Invalid i18n tag: " .. part)
        end
      else
        -- No i18n tags parser available, treat as text
        table.insert(nodes, {
          type = "text",
          value = part
        })
      end
    else
      -- Regular text
      if part ~= "" then
        table.insert(nodes, {
          type = "text",
          value = part
        })
      end
    end
  end

  return {
    type = "text_block",
    nodes = nodes
  }
end

--- Split text into parts (text and i18n tags)
-- @param text string Text to split
-- @return table Array of parts
function M.split(text)
  local parts = {}
  local current = ""
  local i = 1
  local len = #text

  while i <= len do
    -- Check for @@t or @@p followed by whitespace
    if i <= len - 2 then
      local next3 = text:sub(i, i + 2)
      if (next3 == "@@t" or next3 == "@@p") and (i + 3 > len or text:sub(i + 3, i + 3):match("%s")) then
        -- Save accumulated text
        if current ~= "" then
          table.insert(parts, current)
          current = ""
        end

        -- Extract i18n tag (until newline or end of text)
        local tagStart = i
        local tagEnd = tagStart

        -- Find end of tag (newline or end of text)
        while tagEnd <= len do
          local char = text:sub(tagEnd, tagEnd)
          if char == "\n" then
            break
          end
          tagEnd = tagEnd + 1
        end

        local tag = text:sub(tagStart, tagEnd - 1)
        -- Trim trailing whitespace from tag
        tag = tag:gsub("%s+$", "")

        table.insert(parts, tag)
        i = tagEnd
      else
        current = current .. text:sub(i, i)
        i = i + 1
      end
    else
      current = current .. text:sub(i, i)
      i = i + 1
    end
  end

  if current ~= "" then
    table.insert(parts, current)
  end

  return parts
end

--- Check if text contains i18n tags
-- @param text string Text to check
-- @return boolean
function M.hasI18nTags(text)
  if not text then
    return false
  end
  return text:match("@@[tp]%s") ~= nil
end

--- Count i18n tags in text
-- @param text string Text to analyze
-- @return number, number Count of @@t tags, count of @@p tags
function M.countI18nTags(text)
  if not text then
    return 0, 0
  end

  local tCount = 0
  local pCount = 0

  for tag in text:gmatch("@@([tp])%s") do
    if tag == "t" then
      tCount = tCount + 1
    else
      pCount = pCount + 1
    end
  end

  return tCount, pCount
end

--- Extract all translation keys from text
-- @param text string Text to analyze
-- @return table Array of keys
function M.extractKeys(text)
  local keys = {}
  local I18nTags = getI18nTags()

  if not I18nTags then
    return keys
  end

  local parts = M.split(text)

  for _, part in ipairs(parts) do
    if part:match("^@@[tp]%s") then
      local ok, node = pcall(I18nTags.parse, part)
      if ok and node then
        table.insert(keys, node.key)
      end
    end
  end

  return keys
end

return M
