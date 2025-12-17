-- whisker/formats/ink/json_loader.lua
-- Native JSON loading for Ink stories
-- Eliminates the need for json_to_lua.sh pre-conversion

local json = require("whisker.utils.json")

local JsonLoader = {}
JsonLoader.__index = JsonLoader

-- Minimum supported Ink JSON version
local MIN_INK_VERSION = 19
-- Current Ink JSON version for compatibility reference
local MAX_INK_VERSION = 21

-- Module metadata
JsonLoader._whisker = {
  name = "InkJsonLoader",
  version = "1.0.0",
  description = "Native JSON loader for Ink stories",
  depends = {},
  capability = "formats.ink.json"
}

-- Create a new JsonLoader instance
function JsonLoader.new()
  local instance = setmetatable({}, JsonLoader)
  return instance
end

-- Load Ink JSON from a file path
-- @param path string - Path to the ink.json file
-- @return table|nil, string|nil - Story definition table or nil with error message
function JsonLoader:load_file(path)
  local file, err = io.open(path, "r")
  if not file then
    return nil, "Failed to open file: " .. (err or path)
  end

  local content = file:read("*a")
  file:close()

  if not content or content == "" then
    return nil, "File is empty: " .. path
  end

  return self:load_string(content)
end

-- Load Ink JSON from a string
-- @param content string - JSON content
-- @return table|nil, string|nil - Story definition table or nil with error message
function JsonLoader:load_string(content)
  if type(content) ~= "string" then
    return nil, "Content must be a string"
  end

  if content == "" then
    return nil, "Content is empty"
  end

  -- Parse JSON
  local ok, result = pcall(json.decode, content)
  if not ok then
    return nil, "JSON parse error: " .. tostring(result)
  end

  if result == nil then
    return nil, "JSON parse returned nil"
  end

  -- Validate Ink structure
  local valid, err = self:validate(result)
  if not valid then
    return nil, err
  end

  return result
end

-- Validate Ink JSON structure
-- @param data table - Parsed JSON data
-- @return boolean, string|nil - True if valid, or false with error message
function JsonLoader:validate(data)
  if type(data) ~= "table" then
    return false, "Invalid Ink JSON: expected table, got " .. type(data)
  end

  -- Check for required inkVersion field
  local version = data.inkVersion
  if version == nil then
    return false, "Invalid Ink JSON: missing inkVersion field"
  end

  if type(version) ~= "number" then
    return false, "Invalid Ink JSON: inkVersion must be a number"
  end

  -- Check version compatibility
  if version < MIN_INK_VERSION then
    return false, string.format(
      "Unsupported Ink version: %d (minimum supported: %d)",
      version, MIN_INK_VERSION
    )
  end

  if version > MAX_INK_VERSION then
    -- Warn but don't fail for newer versions
    -- Future versions might be compatible
  end

  -- Check for required root field
  if data.root == nil then
    return false, "Invalid Ink JSON: missing root field"
  end

  if type(data.root) ~= "table" then
    return false, "Invalid Ink JSON: root must be a table/array"
  end

  return true
end

-- Get the Ink version from loaded data
-- @param data table - Loaded story data
-- @return number|nil - Ink version or nil if not found
function JsonLoader:get_version(data)
  if type(data) == "table" then
    return data.inkVersion
  end
  return nil
end

-- Check if data looks like Ink JSON
-- @param data table|string - Data to check
-- @return boolean - True if it appears to be Ink JSON
function JsonLoader:is_ink_json(data)
  -- If string, try to parse first
  if type(data) == "string" then
    local ok, parsed = pcall(json.decode, data)
    if not ok or type(parsed) ~= "table" then
      return false
    end
    data = parsed
  end

  if type(data) ~= "table" then
    return false
  end

  -- Check for Ink-specific fields
  return data.inkVersion ~= nil and data.root ~= nil
end

-- Get story metadata from the root container
-- @param data table - Loaded story data
-- @return table - Metadata table (may be empty)
function JsonLoader:get_metadata(data)
  local metadata = {}

  if type(data) ~= "table" then
    return metadata
  end

  -- inkVersion
  metadata.ink_version = data.inkVersion

  -- List definitions (if present)
  if data.listDefs then
    metadata.has_lists = true
    metadata.list_count = 0
    for _ in pairs(data.listDefs) do
      metadata.list_count = metadata.list_count + 1
    end
  end

  -- Try to extract global tags from root container
  -- Global tags are stored as "#tag" strings in the root
  local global_tags = {}
  if type(data.root) == "table" then
    for i, item in ipairs(data.root) do
      if type(item) == "string" and item:sub(1, 1) == "#" then
        table.insert(global_tags, item:sub(2))
      end
    end
  end

  if #global_tags > 0 then
    metadata.global_tags = global_tags

    -- Parse common tag patterns
    for _, tag in ipairs(global_tags) do
      local key, value = tag:match("^(%w+):%s*(.+)$")
      if key and value then
        metadata[key:lower()] = value
      end
    end
  end

  return metadata
end

return JsonLoader
