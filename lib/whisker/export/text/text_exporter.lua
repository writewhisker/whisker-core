--- Text Exporter
-- Export stories to plain text transcripts
-- @module whisker.export.text.text_exporter
-- @author Whisker Core Team
-- @license MIT

local ExportUtils = require("whisker.export.utils")

local TextExporter = {}
TextExporter._dependencies = {}
TextExporter.__index = TextExporter

--- Create a new text exporter instance
-- @return TextExporter A new exporter
function TextExporter.new(deps)
  deps = deps or {}
  local self = setmetatable({}, TextExporter)
  return self
end

--- Check if this story can be exported to text
-- @param story table Story data structure
-- @param options table Export options
-- @return boolean True if export is possible
-- @return string|nil Error message if not possible
function TextExporter:can_export(story, options)
  if not story then
    return false, "No story provided"
  end

  if not story.passages or #story.passages == 0 then
    return false, "Story has no passages"
  end

  return true
end

--- Export story to plain text transcript
-- @param story table Story data structure
-- @param options table Export options:
--   - line_width: number (default 70)
--   - include_metadata: boolean (default true)
--   - include_choices: boolean (default true)
-- @return table Export bundle
function TextExporter:export(story, options)
  options = options or {}
  local line_width = options.line_width or 70
  local include_metadata = options.include_metadata ~= false
  local include_choices = options.include_choices ~= false

  local lines = {}

  -- Header
  if include_metadata then
    table.insert(lines, string.rep("=", line_width))
    table.insert(lines, story.title or "Untitled Story")
    if story.author then
      table.insert(lines, "by " .. story.author)
    end
    table.insert(lines, string.rep("=", line_width))
    table.insert(lines, "")
  end

  -- Export each passage
  for i, passage in ipairs(story.passages) do
    table.insert(lines, self:format_passage(passage, i, options))
    table.insert(lines, "")
  end

  -- Footer
  if include_metadata then
    table.insert(lines, string.rep("-", line_width))
    table.insert(lines, string.format("Total passages: %d", #story.passages))
    table.insert(lines, "Generated: " .. ExportUtils.timestamp())
  end

  local content = table.concat(lines, "\n")

  local bundle = {
    content = content,
    assets = {},
    manifest = ExportUtils.create_manifest("text", story, options),
  }

  return bundle
end

--- Validate text export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function TextExporter:validate(bundle)
  local errors = {}

  if not bundle.content then
    table.insert(errors, {
      message = "No content in bundle",
      severity = "error",
    })
  elseif #bundle.content == 0 then
    table.insert(errors, {
      message = "Empty text content",
      severity = "error",
    })
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = {},
  }
end

--- Get exporter metadata
-- @return table Metadata
function TextExporter:metadata()
  return {
    format = "text",
    version = "1.0.0",
    description = "Plain text transcript for accessibility and testing",
    file_extension = ".txt",
  }
end

--- Format a passage as text
-- @param passage table Passage data
-- @param index number Passage index
-- @param options table Export options
-- @return string Formatted passage
function TextExporter:format_passage(passage, index, options)
  options = options or {}
  local line_width = options.line_width or 70
  local include_choices = options.include_choices ~= false

  local lines = {}

  -- Passage header
  table.insert(lines, string.format("[%d] %s", index, passage.name or "unnamed"))
  table.insert(lines, string.rep("-", line_width))

  -- Tags
  if passage.tags and #passage.tags > 0 then
    table.insert(lines, "Tags: " .. table.concat(passage.tags, ", "))
  end

  -- Passage text
  local text = passage.text or passage.content or ""
  if text ~= "" then
    table.insert(lines, "")
    -- Word wrap long lines
    for _, wrapped_line in ipairs(self:word_wrap(text, line_width)) do
      table.insert(lines, wrapped_line)
    end
    table.insert(lines, "")
  end

  -- Choices
  local choices = passage.choices or passage.links or {}
  if include_choices and #choices > 0 then
    table.insert(lines, "Choices:")
    for i, choice in ipairs(choices) do
      local choice_line = string.format("  %d. %s -> [%s]",
        i,
        choice.text or choice.label or ("Choice " .. i),
        choice.target or choice.passage or "?")

      if choice.condition then
        choice_line = choice_line .. " (conditional)"
      end

      table.insert(lines, choice_line)
    end
  elseif include_choices then
    table.insert(lines, "(End of story branch)")
  end

  return table.concat(lines, "\n")
end

--- Word wrap text to specified width
-- @param text string Text to wrap
-- @param width number Maximum line width
-- @return table Array of wrapped lines
function TextExporter:word_wrap(text, width)
  local lines = {}

  -- Split by existing newlines first
  for line in text:gmatch("[^\n]+") do
    if #line <= width then
      table.insert(lines, line)
    else
      -- Wrap long line
      local current_line = ""
      for word in line:gmatch("%S+") do
        if #current_line == 0 then
          current_line = word
        elseif #current_line + 1 + #word <= width then
          current_line = current_line .. " " .. word
        else
          table.insert(lines, current_line)
          current_line = word
        end
      end
      if #current_line > 0 then
        table.insert(lines, current_line)
      end
    end
  end

  -- Handle empty text
  if #lines == 0 then
    table.insert(lines, "")
  end

  return lines
end

return TextExporter
