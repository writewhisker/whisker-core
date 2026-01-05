--- ChoiceScript Importer
-- Imports stories from Choice of Games' ChoiceScript format
-- Converts ChoiceScript syntax to WLS 1.0 Story model
-- @module whisker.import.choicescript
-- @author Whisker Core Team
-- @license MIT

local IImporter = require("whisker.import.importer")

local ChoiceScriptImporter = {}
setmetatable(ChoiceScriptImporter, { __index = IImporter })

-- Dependencies for DI pattern
ChoiceScriptImporter._dependencies = {}

--- Issue severity levels
local Severity = {
  CRITICAL = "critical",
  WARNING = "warning",
  INFO = "info",
}

--- Create a new ChoiceScript importer
-- @param container table DI container (optional)
-- @return ChoiceScriptImporter
function ChoiceScriptImporter.new(container)
  local self = setmetatable({}, { __index = ChoiceScriptImporter })
  self._container = container
  self._issues = {}
  self._current_scene = "startup"
  return self
end

--- Check if source can be imported as ChoiceScript
-- @param source string Source content
-- @param options table Import options
-- @return boolean
-- @return string|nil Error message
function ChoiceScriptImporter:can_import(source, options)
  if type(source) ~= "string" or source == "" then
    return false, "Empty or invalid source"
  end

  -- ChoiceScript detection heuristics
  local has_commands = source:find("%*create%s") ~= nil
      or source:find("%*temp%s") ~= nil
      or source:find("%*label%s") ~= nil
      or source:find("%*choice%s*\n") ~= nil
      or source:find("%*goto%s") ~= nil
      or source:find("%*set%s") ~= nil
      or source:find("%*if%s") ~= nil
      or source:find("%*finish") ~= nil
      or source:find("%*scene_list") ~= nil
      or source:find("%*title%s") ~= nil
      or source:find("%*author%s") ~= nil

  local has_indented_choices = source:find("%*choice%s*\n%s+#") ~= nil
  local has_cs_variables = source:find("%$[%w_]+") ~= nil
  local has_cs_labels = source:find("%*label%s+[%w_]+") ~= nil

  if has_commands or has_indented_choices or (has_cs_variables and has_cs_labels) then
    return true
  end

  return false, "Content does not appear to be ChoiceScript format"
end

--- Detect if source is ChoiceScript format
-- @param source string Source content
-- @return boolean
function ChoiceScriptImporter:detect(source)
  local can, _ = self:can_import(source)
  return can
end

--- Validate ChoiceScript content
-- @param source string Source content
-- @return table Table with errors array
function ChoiceScriptImporter:validate(source)
  local errors = {}

  if type(source) ~= "string" then
    table.insert(errors, "ChoiceScript content must be a string")
    return errors
  end

  if source:match("^%s*$") then
    table.insert(errors, "Empty ChoiceScript content")
    return errors
  end

  return errors
end

--- Import ChoiceScript source to WLS Story
-- @param source string Source content
-- @param options table Import options
-- @return Story
function ChoiceScriptImporter:import(source, options)
  options = options or {}
  self._issues = {}

  -- Parse ChoiceScript content
  local parsed = self:_parse_choicescript(source)

  -- Convert to Story model
  local story = self:_convert_to_story(parsed)

  return story
end

--- Get importer metadata
-- @return table
function ChoiceScriptImporter:metadata()
  return {
    name = "choicescript",
    version = "1.0.0",
    description = "Import ChoiceScript stories to WLS format",
    extensions = { ".txt" },
    mime_types = { "text/plain" },
    source_format = "ChoiceScript",
    target_format = "WLS 1.0",
  }
end

--- Get conversion issues
-- @return table Array of issues
function ChoiceScriptImporter:get_issues()
  return self._issues
end

--- Build loss report from collected issues
-- @return table Loss report
function ChoiceScriptImporter:get_loss_report()
  local critical = {}
  local warnings = {}
  local info = {}
  local category_counts = {}
  local affected_passages = {}
  local seen_passages = {}

  for _, issue in ipairs(self._issues) do
    if issue.severity == Severity.CRITICAL then
      table.insert(critical, issue)
    elseif issue.severity == Severity.WARNING then
      table.insert(warnings, issue)
    else
      table.insert(info, issue)
    end

    category_counts[issue.category] = (category_counts[issue.category] or 0) + 1

    if issue.passage_name and not seen_passages[issue.passage_name] then
      seen_passages[issue.passage_name] = true
      table.insert(affected_passages, issue.passage_name)
    end
  end

  -- Calculate quality (1.0 = perfect, 0.0 = all critical)
  local critical_weight = 0.3
  local warning_weight = 0.1
  local quality = math.max(0, 1 - (#critical * critical_weight) - (#warnings * warning_weight))

  return {
    total_issues = #self._issues,
    critical = critical,
    warnings = warnings,
    info = info,
    category_counts = category_counts,
    affected_passages = affected_passages,
    conversion_quality = quality,
  }
end

--- Add a conversion issue
-- @param severity string Issue severity
-- @param category string Issue category
-- @param feature string Feature name
-- @param passage_name string|nil Passage name
-- @param line number|nil Line number
-- @param message string|nil Issue message
function ChoiceScriptImporter:_add_issue(severity, category, feature, passage_name, line, message)
  table.insert(self._issues, {
    severity = severity,
    category = category,
    feature = feature,
    message = message or (feature .. " may need manual adjustment"),
    passage_name = passage_name,
    passage_id = passage_name,
    line = line,
  })
end

--- Parse ChoiceScript content into intermediate structure
-- @param content string ChoiceScript source content
-- @return table Parsed structure
function ChoiceScriptImporter:_parse_choicescript(content)
  local result = {
    title = nil,
    author = nil,
    labels = {},
    variables = {},
    scenes = {},
  }

  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  -- Parse lines into structured format
  local parsed_lines = self:_parse_lines(lines)

  local current_label = nil

  for i, line in ipairs(parsed_lines) do
    if line.command == "title" then
      result.title = line.args

    elseif line.command == "author" then
      result.author = line.args

    elseif line.command == "create" or line.command == "temp" then
      local name, value = (line.args or ""):match("^([%w_]+)%s+(.+)$")
      if name and value then
        local parsed_value = self:_parse_value(value)
        result.variables[name] = {
          var_type = parsed_value.var_type,
          initial = parsed_value.value,
        }
      end

    elseif line.command == "label" then
      -- Save previous label
      if current_label then
        table.insert(result.labels, current_label)
      end
      current_label = {
        name = line.args or ("label_" .. i),
        lines = {},
        start_line = line.line_number,
      }

    elseif line.command == "scene_list" then
      -- Parse scene list (indented scene names)
      for j = i + 1, #parsed_lines do
        local scene_line = parsed_lines[j]
        if scene_line.indent > line.indent and scene_line.text then
          table.insert(result.scenes, scene_line.text:match("^%s*(.-)%s*$"))
        elseif scene_line.indent <= line.indent and scene_line.command then
          break
        end
      end

    else
      -- Add line to current label, or create implicit "start" label
      if not current_label and (line.text or line.command) then
        current_label = {
          name = "start",
          lines = {},
          start_line = line.line_number,
        }
      end
      if current_label then
        table.insert(current_label.lines, line)
      end
    end
  end

  -- Save last label
  if current_label then
    table.insert(result.labels, current_label)
  end

  return result
end

--- Parse raw lines into structured line objects
-- @param lines table Array of raw lines
-- @return table Array of parsed line objects
function ChoiceScriptImporter:_parse_lines(lines)
  local result = {}

  for i, line in ipairs(lines) do
    local leading_spaces = line:match("^(%s*)") or ""
    local indent = #leading_spaces
    local trimmed = line:match("^%s*(.-)%s*$")

    local parsed = {
      indent = indent,
      line_number = i,
    }

    if trimmed:match("^%*") then
      local command, args = trimmed:match("^%*([%w_]+)%s*(.*)$")
      if command then
        parsed.command = command
        parsed.args = args ~= "" and args or nil
      end
    elseif trimmed:match("^#") then
      -- Choice option
      parsed.text = trimmed:sub(2):match("^%s*(.-)%s*$")
      parsed.is_choice_option = true
    elseif trimmed ~= "" then
      parsed.text = trimmed
    end

    table.insert(result, parsed)
  end

  return result
end

--- Parse a ChoiceScript value
-- @param value string Value string
-- @return table {var_type, value}
function ChoiceScriptImporter:_parse_value(value)
  local trimmed = value:match("^%s*(.-)%s*$")

  if trimmed == "true" or trimmed == "false" then
    return { var_type = "boolean", value = trimmed == "true" }
  end

  if trimmed:match("^%-?%d+$") then
    return { var_type = "number", value = tonumber(trimmed) }
  end

  if trimmed:match("^%-?%d+%.%d+$") then
    return { var_type = "number", value = tonumber(trimmed) }
  end

  -- String (may or may not be quoted)
  local string_val = trimmed:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")
  return { var_type = "string", value = string_val }
end

--- Convert parsed ChoiceScript to Story model
-- @param parsed table Parsed structure
-- @return Story
function ChoiceScriptImporter:_convert_to_story(parsed)
  local passages = {}
  local variables = {}

  -- Convert variables
  for name, var_info in pairs(parsed.variables) do
    variables[name] = {
      type = var_info.var_type,
      default = var_info.initial,
    }
  end

  -- Convert labels to passages
  for i, label in ipairs(parsed.labels) do
    local content, choices, next_label = self:_convert_label_content(label, parsed.labels)

    local passage = {
      id = label.name,
      name = self:_format_label_title(label.name),
      content = content,
      choices = choices,
      tags = {},
    }

    -- If there's implicit flow to next label, add it as a choice
    if next_label and #choices == 0 then
      table.insert(passage.choices, {
        id = "continue_" .. label.name,
        text = "Continue",
        target = next_label,
      })
    end

    passages[label.name] = passage
  end

  -- Determine start passage
  local start_passage_id = "start"
  for _, label in ipairs(parsed.labels) do
    if label.name == "startup" or label.name == "start" then
      start_passage_id = label.name
      break
    end
  end
  if not passages[start_passage_id] and #parsed.labels > 0 then
    start_passage_id = parsed.labels[1].name
  end

  -- Create Story
  local Story = require("whisker.core.story")
  local story = Story.new({
    title = parsed.title or "Imported ChoiceScript Story",
    author = parsed.author or "Unknown",
    start_passage = start_passage_id,
    variables = variables,
  })

  -- Add passages to story
  local PassageFactory = require("whisker.core.factories.passage_factory")
  local factory = PassageFactory.new()
  for id, passage_data in pairs(passages) do
    local passage = factory:create(passage_data)
    story:add_passage(passage)
  end

  return story
end

--- Convert label content to WLS passage content
-- @param label table Label data
-- @param all_labels table All labels
-- @return string content
-- @return table choices
-- @return string|nil next_label
function ChoiceScriptImporter:_convert_label_content(label, all_labels)
  local content_lines = {}
  local choices = {}
  local next_label = nil

  local i = 1
  while i <= #label.lines do
    local line = label.lines[i]

    if line.command == "set" then
      table.insert(content_lines, self:_convert_set_command(line.args or "", label.name))

    elseif line.command == "if" or line.command == "elseif" or line.command == "else" then
      table.insert(content_lines, self:_convert_conditional(line, label.name))

    elseif line.command == "goto" then
      if line.args then
        next_label = line.args:match("^%s*(.-)%s*$")
        table.insert(content_lines, '{link "' .. self:_format_label_title(next_label) .. '" -> ' .. next_label .. '}')
      end

    elseif line.command == "goto_scene" then
      if line.args then
        local scene, target_label = line.args:match("^([%w_]+)%s*([%w_]*)$")
        if scene then
          local target = target_label and target_label ~= "" and (scene .. "." .. target_label) or scene
          table.insert(content_lines, '{link "Continue to ' .. scene .. '" -> ' .. target .. '}')
          self:_add_issue(Severity.WARNING, "navigation", "goto_scene", label.name, line.line_number,
            "*goto_scene may require manual scene file import")
        end
      end

    elseif line.command == "choice" or line.command == "fake_choice" then
      local parsed_choices = self:_parse_choice_block(label.lines, i)
      for _, option in ipairs(parsed_choices.options) do
        local choice = {
          id = "choice_" .. label.name .. "_" .. #choices,
          text = option.text,
          target = option.target or (label.name .. "_choice"),
          condition = option.condition or option.selectable,
        }
        table.insert(choices, choice)
      end
      i = parsed_choices.end_index

    elseif line.command == "page_break" then
      table.insert(content_lines, "\n---\n")

    elseif line.command == "line_break" then
      table.insert(content_lines, "\n")

    elseif line.command == "finish" then
      table.insert(content_lines, '{link "The End" -> END}')

    elseif line.command == "ending" then
      local ending_text = line.args or "The End"
      table.insert(content_lines, "\n" .. ending_text .. '\n{link "The End" -> END}')

    elseif line.command == "input_text" or line.command == "input_number" then
      local input_var = line.args and line.args:match("^%s*(.-)%s*$")
      if input_var then
        table.insert(content_lines, "{input " .. input_var .. "}")
        self:_add_issue(Severity.WARNING, "input", line.command, label.name, line.line_number,
          "*" .. line.command .. " converted to Whisker input syntax")
      end

    elseif line.command == "stat_chart" then
      self:_add_issue(Severity.INFO, "ui", "stat_chart", label.name, line.line_number,
        "*stat_chart not directly supported, consider using Whisker UI components")

    elseif line.command == "image" then
      if line.args then
        table.insert(content_lines, "{image " .. line.args .. "}")
      end

    elseif line.command == "sound" then
      if line.args then
        table.insert(content_lines, "{audio " .. line.args .. "}")
      end

    elseif line.command == "rand" then
      local var_name, min, max = (line.args or ""):match("^([%w_]+)%s+(%d+)%s+(%d+)$")
      if var_name then
        table.insert(content_lines, "{do " .. var_name .. " = random(" .. min .. ", " .. max .. ")}")
      end

    elseif line.command == "gosub" or line.command == "gosub_scene" then
      self:_add_issue(Severity.WARNING, "navigation", line.command, label.name, line.line_number,
        "*" .. line.command .. " subroutine pattern may need manual adjustment")
      if line.args then
        local target = line.args:match("^%s*([%w_]+)")
        if target then
          table.insert(content_lines, '{link "→" -> ' .. target .. '}')
        end
      end

    elseif line.command == "achieve" or line.command == "check_achievements" then
      self:_add_issue(Severity.INFO, "achievements", line.command, label.name, line.line_number,
        "Achievements not directly supported in Whisker")

    elseif line.command == "comment" then
      table.insert(content_lines, "<!-- " .. (line.args or "") .. " -->")

    else
      -- Regular text
      if line.text and not line.is_choice_option then
        table.insert(content_lines, self:_convert_text(line.text))
      end
    end

    i = i + 1
  end

  local content = table.concat(content_lines, "\n")
  -- Clean up multiple newlines
  content = content:gsub("\n\n\n+", "\n\n"):match("^%s*(.-)%s*$")

  return content, choices, next_label
end

--- Convert *set command to WLS syntax
-- @param args string Set command arguments
-- @param passage_name string Current passage name
-- @return string WLS syntax
function ChoiceScriptImporter:_convert_set_command(args, passage_name)
  -- Handle fairmath operators (%+ and %-)
  local var_name, fairmath_op, value = args:match("^([%w_]+)%s+(%%[+-])%s+(.+)$")
  if var_name then
    self:_add_issue(Severity.WARNING, "syntax", "fairmath", passage_name, nil,
      "Fairmath operator " .. fairmath_op .. " converted to regular arithmetic")
    local operator = fairmath_op == "%+" and "+" or "-"
    return "{do " .. var_name .. " = " .. var_name .. " " .. operator .. " " .. value .. "}"
  end

  -- Handle arithmetic operators (+, -, *, /)
  local op
  var_name, op, value = args:match("^([%w_]+)%s+([+%-*/])%s+(.+)$")
  if var_name then
    return "{do " .. var_name .. " = " .. var_name .. " " .. op .. " " .. value .. "}"
  end

  -- Simple assignment
  var_name, value = args:match("^([%w_]+)%s+(.+)$")
  if var_name then
    return "{do " .. var_name .. " = " .. value .. "}"
  end

  return "{do " .. args .. "}"
end

--- Convert conditional to WLS syntax
-- @param line table Parsed line
-- @param passage_name string Current passage name
-- @return string WLS syntax
function ChoiceScriptImporter:_convert_conditional(line, passage_name)
  local condition = line.args or "true"
  local wls_condition = self:_convert_condition(condition)

  if line.command == "if" then
    return "{if " .. wls_condition .. "}"
  elseif line.command == "elseif" then
    return "{elif " .. wls_condition .. "}"
  else -- else
    return "{else}"
  end
end

--- Convert ChoiceScript condition to WLS condition
-- @param condition string ChoiceScript condition
-- @return string WLS condition
function ChoiceScriptImporter:_convert_condition(condition)
  local result = condition
  -- Remove parentheses around variable names
  result = result:gsub("%(([%w_]+)%)", "%1")
  -- Boolean operators
  result = result:gsub("%sand%s", " && ")
  result = result:gsub("%sor%s", " || ")
  result = result:gsub("%snot%s", " ! ")
  result = result:gsub("^not%s", "! ")
  -- String comparisons
  result = result:gsub('([%w_]+)%s*=%s*"([^"]+)"', '%1 == "%2"')
  return result
end

--- Convert text with variable interpolation
-- @param text string Text to convert
-- @return string Converted text
function ChoiceScriptImporter:_convert_text(text)
  local result = text

  -- Convert multireplace @{var text1|text2|text3} to switch statement
  -- This is ChoiceScript's way of displaying different text based on numeric variable values
  result = result:gsub("@{([%w_]+)%s+([^}]+)}", function(var, options)
    local option_list = {}
    for opt in options:gmatch("[^|]+") do
      table.insert(option_list, opt:match("^%s*(.-)%s*$"))
    end
    if #option_list > 0 then
      -- Convert to switch-case style
      local switch_parts = {}
      for i, opt in ipairs(option_list) do
        table.insert(switch_parts, string.format("%s == %d: %s", var, i - 1, opt))
      end
      return "{switch " .. table.concat(switch_parts, " | ") .. "}"
    end
    return "${" .. var .. "}"
  end)

  -- Convert ${var} format (already compatible)
  -- Convert {var} format to ${var}
  result = result:gsub("{([%w_]+)}", "${%1}")

  return result
end

--- Parse a *choice block
-- @param lines table All lines in label
-- @param start_index number Start index of choice command
-- @return table {options, end_index}
function ChoiceScriptImporter:_parse_choice_block(lines, start_index)
  local options = {}
  local choice_line = lines[start_index]
  local base_indent = choice_line.indent
  local i = start_index + 1

  while i <= #lines do
    local line = lines[i]

    -- Check if we've exited the choice block
    if line.indent <= base_indent and line.command then
      break
    end

    -- Choice option (starts with #, parsed as is_choice_option)
    if line.is_choice_option or line.text then
      local option_text = line.is_choice_option and line.text or line.text
      local option = {
        text = option_text,
        body = {},
      }

      -- Parse option body and find target
      local option_indent = line.indent
      i = i + 1

      while i <= #lines and lines[i].indent > option_indent do
        local body_line = lines[i]

        if body_line.command == "goto" and body_line.args then
          option.target = body_line.args:match("^%s*(.-)%s*$")
        elseif body_line.command == "selectable_if" and body_line.args then
          option.selectable = self:_convert_condition(body_line.args)
        end

        table.insert(option.body, body_line)
        i = i + 1
      end

      table.insert(options, option)
      goto continue
    end

    i = i + 1
    ::continue::
  end

  return { options = options, end_index = i - 1 }
end

--- Format label name as a title
-- @param name string Label name
-- @return string Formatted title
function ChoiceScriptImporter:_format_label_title(name)
  local words = {}
  for word in name:gmatch("[^_]+") do
    table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
  end
  return table.concat(words, " ")
end

return ChoiceScriptImporter
