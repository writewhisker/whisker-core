-- lib/whisker/i18n/tools/extract.lua
-- String extraction tool for i18n
-- Stage 8: Translation Workflow

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Extract translation keys from Whisker Script source string
-- @param content string Whisker Script source
-- @param filename string Source filename (for reporting)
-- @return table Extracted keys with metadata
function M.fromString(content, filename)
  if not content then
    return {}
  end

  filename = filename or "<string>"
  local keys = {}
  local lineNum = 1

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    -- Find @@t and @@p tags
    local pos = 1
    while true do
      local tagStart, tagEnd, tag, key = line:find("@@([tp])%s+([%w%.]+)", pos)
      if not tagStart then
        break
      end

      local entry = {
        key = key,
        type = tag == "t" and "translate" or "plural",
        line = lineNum,
        column = tagStart,
        file = filename,
        context = line:sub(1, 80)  -- First 80 chars for context
      }

      -- Extract the rest of the tag (arguments)
      local argsStart = tagEnd + 1
      local argsText = line:sub(argsStart):match("^%s*(.-)%s*$")

      -- Extract variables from arguments
      entry.variables = {}
      if argsText and argsText ~= "" then
        for varName in argsText:gmatch("(%w+)=") do
          table.insert(entry.variables, varName)
        end
      end

      table.insert(keys, entry)
      pos = tagEnd + 1
    end

    lineNum = lineNum + 1
  end

  return keys
end

--- Extract from file
-- @param filepath string Path to .whisker file
-- @return table Extracted keys with metadata
function M.fromFile(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Cannot open file: " .. filepath
  end

  local content = file:read("*all")
  file:close()

  return M.fromString(content, filepath)
end

--- Extract from directory (requires lfs)
-- @param dirpath string Directory to scan
-- @param pattern string File pattern (default: "%.whisker$")
-- @return table All extracted keys
function M.fromDirectory(dirpath, pattern)
  pattern = pattern or "%.whisker$"

  -- Try to load lfs (optional dependency)
  local lfsOk, lfs = pcall(require, "lfs")

  local allKeys = {}

  if lfsOk then
    local function scan(dir)
      for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." then
          local path = dir .. "/" .. entry
          local attr = lfs.attributes(path)

          if attr and attr.mode == "directory" then
            scan(path)  -- Recurse
          elseif path:match(pattern) then
            local keys, err = M.fromFile(path)
            if keys then
              for _, key in ipairs(keys) do
                table.insert(allKeys, key)
              end
            end
          end
        end
      end
    end

    scan(dirpath)
  else
    -- Fallback: use io.popen for directory listing (Unix-like)
    local handle = io.popen('find "' .. dirpath .. '" -name "*.whisker" 2>/dev/null')
    if handle then
      for filepath in handle:lines() do
        local keys, err = M.fromFile(filepath)
        if keys then
          for _, key in ipairs(keys) do
            table.insert(allKeys, key)
          end
        end
      end
      handle:close()
    end
  end

  return allKeys
end

--- Deduplicate keys by key name
-- @param keys table Extracted keys
-- @return table Deduplicated keys (first occurrence kept)
function M.deduplicate(keys)
  local seen = {}
  local result = {}

  for _, entry in ipairs(keys) do
    if not seen[entry.key] then
      seen[entry.key] = true
      table.insert(result, entry)
    end
  end

  return result
end

--- Build hierarchical structure from keys
-- @param keys table Extracted keys
-- @return table Hierarchical tree
function M.buildTree(keys)
  local tree = {}

  for _, entry in ipairs(keys) do
    local parts = {}
    for part in entry.key:gmatch("[^%.]+") do
      table.insert(parts, part)
    end

    local current = tree
    for i = 1, #parts - 1 do
      current[parts[i]] = current[parts[i]] or {}
      current = current[parts[i]]
    end

    local lastPart = parts[#parts]

    if entry.type == "plural" then
      -- Plural: create categories
      current[lastPart] = {
        one = "TODO: " .. entry.key .. " (singular)",
        other = "TODO: " .. entry.key .. " (plural)"
      }
    else
      -- Simple translation
      current[lastPart] = "TODO: " .. entry.key
    end
  end

  return tree
end

--- Generate YAML template from extracted keys
-- @param keys table Extracted keys
-- @return string YAML content
function M.toYAML(keys)
  local tree = M.buildTree(M.deduplicate(keys))
  return M.serializeYAML(tree)
end

--- Serialize tree to YAML
-- @param tree table Hierarchical data
-- @param indent number Current indentation level
-- @return string YAML content
function M.serializeYAML(tree, indent)
  indent = indent or 0
  local lines = {}
  local indentStr = string.rep("  ", indent)

  -- Sort keys for deterministic output
  local sortedKeys = {}
  for key in pairs(tree) do
    table.insert(sortedKeys, key)
  end
  table.sort(sortedKeys)

  for _, key in ipairs(sortedKeys) do
    local value = tree[key]
    if type(value) == "table" then
      table.insert(lines, indentStr .. key .. ":")
      table.insert(lines, M.serializeYAML(value, indent + 1))
    else
      -- Quote strings with special characters
      local quotedValue = value
      if value:match('[:#{}%[%]"\'%%@&*!|>]') or value:match("^%s") or value:match("%s$") then
        quotedValue = '"' .. value:gsub('"', '\\"') .. '"'
      end
      table.insert(lines, indentStr .. key .. ": " .. quotedValue)
    end
  end

  return table.concat(lines, "\n")
end

--- Generate JSON template from extracted keys
-- @param keys table Extracted keys
-- @return string JSON content
function M.toJSON(keys)
  local tree = M.buildTree(M.deduplicate(keys))
  return M.serializeJSON(tree, 0)
end

--- Serialize tree to JSON
-- @param value any Value to serialize
-- @param indent number Current indentation level
-- @return string JSON content
function M.serializeJSON(value, indent)
  indent = indent or 0
  local indentStr = string.rep("  ", indent)
  local nextIndent = string.rep("  ", indent + 1)

  if type(value) == "string" then
    -- Escape special characters
    local escaped = value
    escaped = escaped:gsub("\\", "\\\\")
    escaped = escaped:gsub('"', '\\"')
    escaped = escaped:gsub("\n", "\\n")
    escaped = escaped:gsub("\r", "\\r")
    escaped = escaped:gsub("\t", "\\t")
    return '"' .. escaped .. '"'
  elseif type(value) == "table" then
    local lines = {}
    table.insert(lines, "{")

    -- Sort keys
    local sortedKeys = {}
    for key in pairs(value) do
      table.insert(sortedKeys, key)
    end
    table.sort(sortedKeys)

    for i, key in ipairs(sortedKeys) do
      local comma = i < #sortedKeys and "," or ""
      local serialized = M.serializeJSON(value[key], indent + 1)
      table.insert(lines, nextIndent .. '"' .. key .. '": ' .. serialized .. comma)
    end

    table.insert(lines, indentStr .. "}")
    return table.concat(lines, "\n")
  else
    return tostring(value)
  end
end

--- Generate template from extracted keys
-- @param keys table Extracted keys
-- @param format string Output format ("yaml" or "json")
-- @return string Template content
function M.generateTemplate(keys, format)
  format = format or "yaml"

  if format == "json" then
    return M.toJSON(keys)
  else
    return M.toYAML(keys)
  end
end

--- Get summary of extracted keys
-- @param keys table Extracted keys
-- @return table Summary statistics
function M.getSummary(keys)
  local translateCount = 0
  local pluralCount = 0
  local uniqueKeys = {}
  local files = {}

  for _, entry in ipairs(keys) do
    if entry.type == "translate" then
      translateCount = translateCount + 1
    else
      pluralCount = pluralCount + 1
    end

    uniqueKeys[entry.key] = true
    files[entry.file] = (files[entry.file] or 0) + 1
  end

  local uniqueCount = 0
  for _ in pairs(uniqueKeys) do
    uniqueCount = uniqueCount + 1
  end

  local fileCount = 0
  for _ in pairs(files) do
    fileCount = fileCount + 1
  end

  return {
    total = #keys,
    translate = translateCount,
    plural = pluralCount,
    unique = uniqueCount,
    files = fileCount,
    byFile = files
  }
end

return M
