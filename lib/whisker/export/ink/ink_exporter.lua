--- Ink Exporter
-- Export stories to Ink JSON format for game engine integration
-- @module whisker.export.ink.ink_exporter
-- @author Whisker Core Team
-- @license MIT

local ExportUtils = require("whisker.export.utils")
local InkMapper = require("whisker.export.ink.mapper")
local InkSchema = require("whisker.export.ink.schema")

local InkExporter = {}
InkExporter.__index = InkExporter

--- Create a new Ink exporter instance
-- @return InkExporter A new exporter
function InkExporter.new()
  local self = setmetatable({}, InkExporter)
  return self
end

--- Check if this story can be exported to Ink format
-- @param story table Story data structure
-- @param options table Export options
-- @return boolean True if export is possible
-- @return string|nil Error message if not possible
function InkExporter:can_export(story, options)
  local compatibility = InkMapper.check_compatibility(story)

  if not compatibility.compatible then
    local error_messages = {}
    for _, issue in ipairs(compatibility.issues) do
      if issue.severity == "error" then
        table.insert(error_messages, issue.issue)
      end
    end
    return false, table.concat(error_messages, "; ")
  end

  return true
end

--- Export story to Ink JSON format
-- @param story table Story data structure
-- @param options table Export options:
--   - pretty: boolean (format JSON with indentation)
--   - validate: boolean (validate output, default true)
-- @return table Export bundle
function InkExporter:export(story, options)
  options = options or {}

  -- Map whisker story to Ink JSON
  local ink_json = InkMapper.map_story(story)

  -- Serialize to JSON string
  local json_string
  if options.pretty then
    json_string = self:to_json_pretty(ink_json, 0)
  else
    json_string = self:to_json(ink_json)
  end

  local bundle = {
    content = json_string,
    assets = {},
    manifest = ExportUtils.create_manifest("ink", story, options),
  }

  return bundle
end

--- Validate Ink export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function InkExporter:validate(bundle)
  local errors = {}
  local warnings = {}

  if not bundle.content or #bundle.content == 0 then
    table.insert(errors, {
      message = "No content in bundle",
      severity = "error",
    })
    return { valid = false, errors = errors, warnings = warnings }
  end

  -- Try to parse JSON
  local ok, ink_data = pcall(function()
    return self:parse_json(bundle.content)
  end)

  if not ok then
    table.insert(errors, {
      message = "Invalid JSON: " .. tostring(ink_data),
      severity = "error",
    })
    return { valid = false, errors = errors, warnings = warnings }
  end

  -- Validate against Ink schema
  local schema_issues = InkSchema.validate(ink_data)
  for _, issue in ipairs(schema_issues) do
    if issue.severity == "error" then
      table.insert(errors, issue)
    else
      table.insert(warnings, issue)
    end
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

--- Get exporter metadata
-- @return table Metadata
function InkExporter:metadata()
  return {
    format = "ink",
    version = "1.0.0",
    description = "Ink JSON format for ink-engine (Unity, Unreal, etc.)",
    file_extension = ".json",
  }
end

--- Convert Lua table to JSON string (compact)
-- @param data table Data to convert
-- @return string JSON string
function InkExporter:to_json(data)
  if data == nil then
    return "null"
  end

  local t = type(data)

  if t == "boolean" then
    return data and "true" or "false"
  end

  if t == "number" then
    return tostring(data)
  end

  if t == "string" then
    return '"' .. ExportUtils.escape_json(data) .. '"'
  end

  if t == "table" then
    -- Check if array (has sequential numeric keys)
    local is_array = true
    local count = 0
    for k, _ in pairs(data) do
      count = count + 1
      if type(k) ~= "number" or k ~= count then
        is_array = false
        break
      end
    end

    if is_array and count > 0 then
      -- Array
      local parts = {}
      for i, v in ipairs(data) do
        parts[i] = self:to_json(v)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    elseif count == 0 then
      -- Empty - could be array or object
      return "{}"
    else
      -- Object
      local parts = {}
      for k, v in pairs(data) do
        table.insert(parts, '"' .. ExportUtils.escape_json(tostring(k)) .. '":' .. self:to_json(v))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end

  return "null"
end

--- Convert Lua table to pretty-printed JSON string
-- @param data table Data to convert
-- @param indent number Current indent level
-- @return string Formatted JSON string
function InkExporter:to_json_pretty(data, indent)
  indent = indent or 0
  local indent_str = string.rep("  ", indent)
  local child_indent = string.rep("  ", indent + 1)

  if data == nil then
    return "null"
  end

  local t = type(data)

  if t == "boolean" then
    return data and "true" or "false"
  end

  if t == "number" then
    return tostring(data)
  end

  if t == "string" then
    return '"' .. ExportUtils.escape_json(data) .. '"'
  end

  if t == "table" then
    -- Check if array
    local is_array = true
    local count = 0
    for k, _ in pairs(data) do
      count = count + 1
      if type(k) ~= "number" or k ~= count then
        is_array = false
        break
      end
    end

    if is_array and count > 0 then
      local parts = {}
      for i, v in ipairs(data) do
        parts[i] = child_indent .. self:to_json_pretty(v, indent + 1)
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent_str .. "]"
    elseif count == 0 then
      return "{}"
    else
      local parts = {}
      local keys = {}
      for k in pairs(data) do
        table.insert(keys, k)
      end
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)

      for _, k in ipairs(keys) do
        local v = data[k]
        table.insert(parts, child_indent .. '"' .. ExportUtils.escape_json(tostring(k)) .. '": ' ..
          self:to_json_pretty(v, indent + 1))
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent_str .. "}"
    end
  end

  return "null"
end

--- Basic JSON structure validation (string-based)
-- @param json_string string JSON to validate
-- @return table Basic parsed structure with key fields
function InkExporter:parse_json(json_string)
  -- Very basic JSON validation - just extract key fields
  -- In production, use a proper JSON library

  if not json_string or #json_string == 0 then
    error("Empty JSON string")
  end

  -- Remove whitespace
  local str = json_string:gsub("^%s+", ""):gsub("%s+$", "")

  -- Check basic structure
  if str:sub(1, 1) ~= "{" then
    error("Expected object at root")
  end

  -- Extract key fields using pattern matching
  local result = {}

  -- Look for inkVersion
  local ink_version = str:match('"inkVersion"%s*:%s*(%d+)')
  if ink_version then
    result.inkVersion = tonumber(ink_version)
  end

  -- Look for root
  if str:match('"root"%s*:') then
    result.root = {}  -- Just mark that it exists
  end

  -- Look for listDefs
  if str:match('"listDefs"%s*:') then
    result.listDefs = {}
  end

  return result
end

return InkExporter
