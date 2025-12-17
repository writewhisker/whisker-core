-- lib/whisker/script/generator/sourcemap.lua
-- Source map generation for Whisker Script

local M = {}

-- ============================================
-- SourceMap Class
-- ============================================

local SourceMap = {}
SourceMap.__index = SourceMap

--- Create a new source map
-- @param options table Options { source_file: string }
-- @return SourceMap
function SourceMap.new(options)
  options = options or {}
  return setmetatable({
    version = 3,
    file = options.file or "generated.lua",
    source_root = options.source_root or "",
    sources = { options.source_file or "input.wsk" },
    names = {},
    mappings = {},
    _name_index = {},
    _raw_mappings = {},
  }, SourceMap)
end

--- Add a mapping from generated position to source position
-- @param mapping table { generated_line, generated_column, source_line, source_column, name? }
function SourceMap:add_mapping(mapping)
  local entry = {
    generated_line = mapping.generated_line or 1,
    generated_column = mapping.generated_column or 0,
    source_index = 0, -- We only have one source file
    source_line = mapping.source_line or 1,
    source_column = mapping.source_column or 0,
    name_index = nil
  }

  -- Handle name if provided
  if mapping.name then
    local name_idx = self._name_index[mapping.name]
    if not name_idx then
      name_idx = #self.names
      table.insert(self.names, mapping.name)
      self._name_index[mapping.name] = name_idx
    end
    entry.name_index = name_idx
  end

  table.insert(self._raw_mappings, entry)
end

--- Get mapping for a generated position
-- @param line number Generated line (1-based)
-- @param column number Generated column (0-based)
-- @return table|nil Original source position
function SourceMap:get_original_position(line, column)
  -- Find the closest mapping at or before the given position
  local best = nil

  for _, m in ipairs(self._raw_mappings) do
    if m.generated_line == line then
      if m.generated_column <= column then
        if not best or m.generated_column > best.generated_column then
          best = m
        end
      end
    elseif m.generated_line < line then
      if not best or m.generated_line > best.generated_line then
        best = m
      end
    end
  end

  if best then
    return {
      source = self.sources[best.source_index + 1],
      line = best.source_line,
      column = best.source_column,
      name = best.name_index and self.names[best.name_index + 1] or nil
    }
  end

  return nil
end

--- Get all mappings for a generated line
-- @param line number Generated line (1-based)
-- @return table Array of mappings
function SourceMap:get_line_mappings(line)
  local result = {}
  for _, m in ipairs(self._raw_mappings) do
    if m.generated_line == line then
      table.insert(result, {
        generated_column = m.generated_column,
        source_line = m.source_line,
        source_column = m.source_column,
        name = m.name_index and self.names[m.name_index + 1] or nil
      })
    end
  end
  -- Sort by column
  table.sort(result, function(a, b)
    return a.generated_column < b.generated_column
  end)
  return result
end

--- Encode a VLQ value
-- @param value number Integer to encode
-- @return string VLQ-encoded string
local function encode_vlq(value)
  local VLQ_BASE_SHIFT = 5
  local VLQ_BASE = 32
  local VLQ_BASE_MASK = VLQ_BASE - 1
  local VLQ_CONTINUATION_BIT = VLQ_BASE

  local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

  -- Convert to VLQ signed representation
  local vlq = value < 0 and ((-value * 2) + 1) or (value * 2)

  local result = {}
  repeat
    local digit = vlq % VLQ_BASE
    vlq = math.floor(vlq / VLQ_BASE)
    if vlq > 0 then
      digit = digit + VLQ_CONTINUATION_BIT
    end
    table.insert(result, BASE64_CHARS:sub(digit + 1, digit + 1))
  until vlq == 0

  return table.concat(result)
end

--- Generate the mappings string (VLQ encoded)
-- @return string VLQ-encoded mappings
function SourceMap:_generate_mappings_string()
  -- Sort mappings by line, then column
  local sorted = {}
  for _, m in ipairs(self._raw_mappings) do
    table.insert(sorted, m)
  end
  table.sort(sorted, function(a, b)
    if a.generated_line ~= b.generated_line then
      return a.generated_line < b.generated_line
    end
    return a.generated_column < b.generated_column
  end)

  if #sorted == 0 then
    return ""
  end

  local lines = {}
  local current_line = 1
  local prev_gen_col = 0
  local prev_src_line = 0
  local prev_src_col = 0
  local prev_name = 0

  for _, m in ipairs(sorted) do
    -- Fill empty lines
    while current_line < m.generated_line do
      table.insert(lines, "")
      current_line = current_line + 1
      prev_gen_col = 0
    end

    -- Build segment
    local segment = {}

    -- Generated column (relative to previous in line)
    table.insert(segment, encode_vlq(m.generated_column - prev_gen_col))
    prev_gen_col = m.generated_column

    -- Source index (always 0 for single source)
    table.insert(segment, encode_vlq(m.source_index))

    -- Source line (relative)
    table.insert(segment, encode_vlq((m.source_line - 1) - prev_src_line))
    prev_src_line = m.source_line - 1

    -- Source column (relative)
    table.insert(segment, encode_vlq(m.source_column - prev_src_col))
    prev_src_col = m.source_column

    -- Name index if present
    if m.name_index then
      table.insert(segment, encode_vlq(m.name_index - prev_name))
      prev_name = m.name_index
    end

    -- Add to current line
    if not lines[current_line] then
      lines[current_line] = ""
    end
    if lines[current_line] ~= "" then
      lines[current_line] = lines[current_line] .. ","
    end
    lines[current_line] = lines[current_line] .. table.concat(segment)
  end

  return table.concat(lines, ";")
end

--- Serialize to JSON format (Source Map v3)
-- @return string JSON representation
function SourceMap:to_json()
  local mappings = self:_generate_mappings_string()

  local parts = {
    '{"version":3',
    ',"file":' .. string.format("%q", self.file),
    ',"sourceRoot":' .. string.format("%q", self.source_root),
    ',"sources":[' .. table.concat(
      (function()
        local s = {}
        for _, src in ipairs(self.sources) do
          table.insert(s, string.format("%q", src))
        end
        return s
      end)(),
      ","
    ) .. ']',
    ',"names":[' .. table.concat(
      (function()
        local n = {}
        for _, name in ipairs(self.names) do
          table.insert(n, string.format("%q", name))
        end
        return n
      end)(),
      ","
    ) .. ']',
    ',"mappings":' .. string.format("%q", mappings),
    '}'
  }

  return table.concat(parts)
end

--- Create from JSON (for testing/loading)
-- @param json string JSON string
-- @return SourceMap
function SourceMap.from_json(json)
  -- Simple JSON parsing for sourcemap format
  local sm = SourceMap.new()

  -- Extract version
  local version = json:match('"version"%s*:%s*(%d+)')
  if version then sm.version = tonumber(version) end

  -- Extract file
  local file = json:match('"file"%s*:%s*"([^"]*)"')
  if file then sm.file = file end

  -- Extract sourceRoot
  local source_root = json:match('"sourceRoot"%s*:%s*"([^"]*)"')
  if source_root then sm.source_root = source_root end

  -- Extract sources (simple case)
  local sources_str = json:match('"sources"%s*:%s*%[([^%]]*)%]')
  if sources_str then
    sm.sources = {}
    for src in sources_str:gmatch('"([^"]*)"') do
      table.insert(sm.sources, src)
    end
  end

  -- Extract names
  local names_str = json:match('"names"%s*:%s*%[([^%]]*)%]')
  if names_str then
    sm.names = {}
    for name in names_str:gmatch('"([^"]*)"') do
      table.insert(sm.names, name)
      sm._name_index[name] = #sm.names - 1
    end
  end

  return sm
end

--- Get count of mappings
-- @return number
function SourceMap:count()
  return #self._raw_mappings
end

--- Check if source map has any mappings
-- @return boolean
function SourceMap:has_mappings()
  return #self._raw_mappings > 0
end

M.SourceMap = SourceMap

--- Module metadata
M._whisker = {
  name = "script.generator.sourcemap",
  version = "0.1.0",
  description = "Source map generation for Whisker Script",
  depends = {},
  capability = "script.generator.sourcemap"
}

return M
