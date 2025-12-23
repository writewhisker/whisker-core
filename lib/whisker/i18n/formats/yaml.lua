-- lib/whisker/i18n/formats/yaml.lua
-- YAML format handler for translation files
-- Stage 3: Translation File Format Support
-- Note: This is a simplified YAML parser supporting common translation file features

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Strip UTF-8 BOM from content
-- @param content string Content to process
-- @return string Content without BOM
local function stripBOM(content)
  if content:sub(1, 3) == "\xEF\xBB\xBF" then
    return content:sub(4)
  end
  return content
end

--- Count leading spaces
-- @param line string Line to check
-- @return number Number of leading spaces
local function countIndent(line)
  local spaces = line:match("^( *)")
  return #spaces
end

--- Remove leading/trailing whitespace
-- @param str string String to trim
-- @return string Trimmed string
local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

--- Parse a YAML scalar value
-- @param value string Value to parse
-- @return any Parsed value
local function parseScalar(value)
  if value == nil or value == "" then
    return nil
  end

  value = trim(value)

  -- Handle quoted strings
  if value:match('^"') then
    -- Double-quoted string
    if value:match('^"(.-)"$') then
      local inner = value:match('^"(.-)"$')
      -- Process escape sequences
      inner = inner:gsub('\\n', '\n')
                   :gsub('\\r', '\r')
                   :gsub('\\t', '\t')
                   :gsub('\\"', '"')
                   :gsub('\\\\', '\\')
      return inner
    else
      -- Incomplete quote, return as-is
      return value
    end
  elseif value:match("^'") then
    -- Single-quoted string
    if value:match("^'(.-)'$") then
      local inner = value:match("^'(.-)'$")
      -- Single quotes only escape single quotes
      inner = inner:gsub("''", "'")
      return inner
    else
      return value
    end
  end

  -- Handle special values
  local lower = value:lower()
  if lower == "null" or lower == "~" or value == "" then
    return nil
  elseif lower == "true" or lower == "yes" or lower == "on" then
    return true
  elseif lower == "false" or lower == "no" or lower == "off" then
    return false
  end

  -- Handle numbers
  local num = tonumber(value)
  if num then
    return num
  end

  -- Return as string
  return value
end

--- Parse YAML content
-- @param content string YAML content
-- @return table Parsed data
function M.parse(content)
  content = stripBOM(content)

  -- Split into lines
  local lines = {}
  for line in content:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end

  -- Remove trailing empty line from gmatch
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end

  local result = {}
  local lineNum = 1

  local function parseBlock(baseIndent, targetTable)
    while lineNum <= #lines do
      local line = lines[lineNum]

      -- Skip empty lines and comments
      if line:match("^%s*$") or line:match("^%s*#") then
        lineNum = lineNum + 1
      else
        local indent = countIndent(line)

        -- If less indented, we're done with this block
        if indent < baseIndent then
          return
        end

        -- If same indent, we're at the same level
        if indent == baseIndent then
          local trimmedLine = trim(line)

          -- Check for key: value
          local key, value = line:match("^%s*([%w_%.%-]+)%s*:%s*(.*)$")

          if key then
            -- Remove inline comment from value
            if value and value ~= "" then
              -- Remove trailing comment (but preserve # in quoted strings)
              local inQuote = false
              local quoteChar = nil
              local cleanValue = ""
              for i = 1, #value do
                local c = value:sub(i, i)
                if not inQuote then
                  if c == '"' or c == "'" then
                    inQuote = true
                    quoteChar = c
                  elseif c == '#' then
                    -- Found comment, stop here
                    break
                  end
                else
                  if c == quoteChar and value:sub(i-1, i-1) ~= '\\' then
                    inQuote = false
                  end
                end
                cleanValue = cleanValue .. c
              end
              value = trim(cleanValue)
            end

            if value == "" then
              -- This is a parent key with children
              lineNum = lineNum + 1
              local childTable = {}

              -- Look at next non-empty, non-comment line
              local nextLineNum = lineNum
              while nextLineNum <= #lines do
                local nextLine = lines[nextLineNum]
                if not nextLine:match("^%s*$") and not nextLine:match("^%s*#") then
                  local nextIndent = countIndent(nextLine)
                  if nextIndent > indent then
                    parseBlock(nextIndent, childTable)
                  end
                  break
                end
                nextLineNum = nextLineNum + 1
              end

              if next(childTable) then
                targetTable[key] = childTable
              else
                targetTable[key] = nil
              end
            else
              -- Simple key: value
              targetTable[key] = parseScalar(value)
              lineNum = lineNum + 1
            end
          else
            -- Line doesn't match key: value pattern
            lineNum = lineNum + 1
          end
        elseif indent > baseIndent then
          -- Unexpected deeper indent without a key
          lineNum = lineNum + 1
        end
      end
    end
  end

  -- Start parsing from first non-empty, non-comment line
  while lineNum <= #lines do
    local line = lines[lineNum]
    if not line:match("^%s*$") and not line:match("^%s*#") and not line:match("^%-%-%-") then
      local indent = countIndent(line)
      parseBlock(indent, result)
      break
    end
    lineNum = lineNum + 1
  end

  return result
end

--- Validate YAML structure for translation files
-- @param data any Parsed YAML data
-- @param filepath string|nil Source file for error messages
function M.validate(data, filepath)
  filepath = filepath or "unknown"

  if type(data) ~= "table" then
    error(filepath .. ": Root element must be a mapping, got " .. type(data))
  end

  -- Recursively check for invalid structures
  local function check(tbl, path)
    for key, value in pairs(tbl) do
      if type(key) ~= "string" and type(key) ~= "number" then
        error(filepath .. ": Invalid key type at " .. path .. ": " .. type(key))
      end

      if type(value) == "table" then
        check(value, path .. "." .. tostring(key))
      elseif type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" and value ~= nil then
        error(filepath .. ": Invalid value type at " .. path .. "." .. tostring(key) .. ": " .. type(value))
      end
    end
  end

  check(data, "root")
end

--- Load YAML file
-- @param filepath string Path to YAML file
-- @return table Parsed data
function M.load(filepath)
  local file, err = io.open(filepath, "r")
  if not file then
    error("Cannot open file: " .. filepath .. " (" .. (err or "unknown error") .. ")")
  end

  local content = file:read("*all")
  file:close()

  local ok, data = pcall(M.parse, content)
  if not ok then
    error("YAML parse error in " .. filepath .. ": " .. tostring(data))
  end

  M.validate(data, filepath)

  return data
end

--- Load YAML from string
-- @param content string YAML content
-- @return table Parsed data
function M.loadString(content)
  local data = M.parse(content)
  M.validate(data, "string input")
  return data
end

--- Encode value to YAML string
-- @param value any Value to encode
-- @param indent number|nil Current indent level
-- @return string YAML string
function M.encode(value, indent)
  indent = indent or 0
  local indentStr = string.rep("  ", indent)

  local valueType = type(value)

  if value == nil then
    return "null"
  elseif valueType == "boolean" then
    return value and "true" or "false"
  elseif valueType == "number" then
    return tostring(value)
  elseif valueType == "string" then
    -- Check if we need to quote
    if value == "" or
       value:match("^[%s]") or value:match("[%s]$") or
       value:match("[#:]") or
       value:lower() == "true" or value:lower() == "false" or
       value:lower() == "null" or value:lower() == "yes" or value:lower() == "no" or
       tonumber(value) then
      -- Need to quote
      local escaped = value:gsub('\\', '\\\\')
                           :gsub('"', '\\"')
                           :gsub('\n', '\\n')
                           :gsub('\r', '\\r')
                           :gsub('\t', '\\t')
      return '"' .. escaped .. '"'
    end
    return value
  elseif valueType == "table" then
    local parts = {}

    -- Sort keys for consistent output
    local keys = {}
    for k, _ in pairs(value) do
      table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
      return tostring(a) < tostring(b)
    end)

    for _, k in ipairs(keys) do
      local v = value[k]
      local keyStr = tostring(k)

      if type(v) == "table" and next(v) then
        table.insert(parts, indentStr .. keyStr .. ":")
        table.insert(parts, M.encode(v, indent + 1))
      else
        local valStr = M.encode(v, indent + 1)
        table.insert(parts, indentStr .. keyStr .. ": " .. valStr)
      end
    end

    return table.concat(parts, "\n")
  else
    error("Cannot encode type: " .. valueType)
  end
end

--- Save YAML file
-- @param filepath string Destination path
-- @param data table Data to save
function M.save(filepath, data)
  local file, err = io.open(filepath, "w")
  if not file then
    error("Cannot write file: " .. filepath .. " (" .. (err or "unknown error") .. ")")
  end

  local yamlStr = M.encode(data)
  file:write(yamlStr)
  file:write("\n")
  file:close()
end

return M
