-- lib/whisker/script/writer.lua
-- Whisker Script source code generator
-- Converts Story objects back to .wsk source code

local M = {}

-- ============================================
-- Writer Class
-- ============================================

local Writer = {}
Writer.__index = Writer

--- Create a new Writer
-- @param options table Options { indent: string }
-- @return Writer
function Writer.new(options)
  options = options or {}
  return setmetatable({
    indent = options.indent or "  ",
    _lines = {},
  }, Writer)
end

--- Write a Story to Whisker Script source
-- @param story table Story object
-- @return string Whisker Script source code
function Writer:write(story)
  self._lines = {}

  -- Write metadata
  self:_write_metadata(story)

  -- Write passages
  self:_write_passages(story)

  -- Join with newlines and ensure final newline
  local result = table.concat(self._lines, "\n")
  if result:sub(-1) ~= "\n" then
    result = result .. "\n"
  end
  return result
end

--- Write story metadata
-- @param story table Story object
function Writer:_write_metadata(story)
  local metadata = story.metadata or {}
  local has_metadata = false

  -- Standard metadata fields (internal name -> output name)
  local field_mappings = {
    { internal = "name", output = "title" },
    { internal = "author", output = "author" },
    { internal = "version", output = "version" },
    { internal = "ifid", output = "ifid" },
  }

  local written_fields = {}
  for _, mapping in ipairs(field_mappings) do
    local value = metadata[mapping.internal]
    if value and value ~= "" then
      self:_add_line(string.format("@@ %s: %s", mapping.output, self:_format_value(value)))
      has_metadata = true
      written_fields[mapping.internal] = true
      written_fields[mapping.output] = true
    end
  end

  -- Custom metadata fields
  for key, value in pairs(metadata) do
    -- Skip fields already written
    if written_fields[key] then
      -- Already written
    -- Skip internal fields
    elseif key:sub(1, 1) == "_" or key == "format" or key == "format_version" or
       key == "uuid" or key == "created" or key == "modified" then
      -- Internal field, skip
    elseif value and value ~= "" then
      self:_add_line(string.format("@@ %s: %s", key, self:_format_value(value)))
      has_metadata = true
    end
  end

  -- Add blank line after metadata
  if has_metadata then
    self:_add_line("")
  end
end

--- Write all passages
-- @param story table Story object
function Writer:_write_passages(story)
  local passages = self:_get_passages(story)

  for i, passage in ipairs(passages) do
    if i > 1 then
      self:_add_line("")  -- Blank line between passages
    end
    self:_write_passage(passage)
  end
end

--- Get passages from story in order
-- @param story table Story object
-- @return table Array of passages
function Writer:_get_passages(story)
  local passages = {}

  -- Try different methods to get passages
  if type(story.get_all_passages) == "function" then
    passages = story:get_all_passages()
  elseif type(story.get_passages) == "function" then
    passages = story:get_passages()
  elseif type(story.passages) == "table" then
    -- Could be array or hash table
    if #story.passages > 0 then
      passages = story.passages
    else
      -- Convert hash to array
      for name, passage in pairs(story.passages) do
        -- Ensure passage has name
        if type(passage) == "table" then
          if not passage.name then
            passage.name = name
          end
          table.insert(passages, passage)
        end
      end
    end
  end

  -- Sort by name/id to ensure consistent output
  table.sort(passages, function(a, b)
    local name_a = a.name or a.id or ""
    local name_b = b.name or b.id or ""
    -- Put "Start" first
    if name_a == "Start" then return true end
    if name_b == "Start" then return false end
    return name_a < name_b
  end)

  return passages
end

--- Write a single passage
-- @param passage table Passage object
function Writer:_write_passage(passage)
  local name = passage.name or passage.id or "Unnamed"
  local tags = passage.tags or {}

  -- Write passage header
  local header = ":: " .. name
  if #tags > 0 then
    header = header .. " [" .. table.concat(tags, ", ") .. "]"
  end
  self:_add_line(header)

  -- Write passage content
  local content = passage.content or ""
  if content ~= "" then
    -- Split content into lines and write each
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
      self:_add_line(line)
    end
  end

  -- Write choices
  local choices = passage.choices or {}
  if type(passage.get_choices) == "function" then
    choices = passage:get_choices()
  end

  for _, choice in ipairs(choices) do
    self:_write_choice(choice)
  end
end

--- Write a choice
-- @param choice table Choice object
function Writer:_write_choice(choice)
  local text = choice.text or choice.label or ""
  local target = choice.target or choice.link or ""
  local condition = choice.condition or nil

  local line = "+ "

  -- Add condition if present
  if condition and condition ~= "" then
    line = line .. "{ " .. condition .. " } "
  end

  -- Add choice text
  line = line .. "[" .. text .. "]"

  -- Add target
  if target and target ~= "" then
    line = line .. " -> " .. target
  end

  self:_add_line(line)
end

--- Format a value for metadata output
-- @param value any Value to format
-- @return string Formatted value
function Writer:_format_value(value)
  if type(value) == "string" then
    -- Quote strings that contain special characters
    if value:match("[%.:%[%]{}()+*/\\%$@~<>!|,]") or value:match("^%d") then
      return '"' .. value:gsub('"', '\\"') .. '"'
    end
    return value
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "boolean" then
    return value and "true" or "false"
  elseif type(value) == "table" then
    -- Simple array/list
    local parts = {}
    for _, v in ipairs(value) do
      table.insert(parts, self:_format_value(v))
    end
    return table.concat(parts, ", ")
  else
    return tostring(value)
  end
end

--- Add a line to output
-- @param line string Line to add
function Writer:_add_line(line)
  table.insert(self._lines, line)
end

M.Writer = Writer

--- Module metadata
M._whisker = {
  name = "script.writer",
  version = "1.0.0",
  description = "Whisker Script source code generator",
  depends = {},
  capability = "script.writer"
}

return M
