--- Ink Importer
-- Imports stories from Ink narrative scripting language format (.ink files)
-- Converts Ink syntax to WLS 1.0 Story model
-- @module whisker.import.ink
-- @author Whisker Core Team
-- @license MIT

local IImporter = require("whisker.import.importer")

local InkImporter = {}
setmetatable(InkImporter, { __index = IImporter })

-- Dependencies for DI pattern
InkImporter._dependencies = {}

--- Issue severity levels
local Severity = {
  CRITICAL = "critical",
  WARNING = "warning",
  INFO = "info",
}

--- Create a new Ink importer
-- @param container table DI container (optional)
-- @return InkImporter
function InkImporter.new(container)
  local self = setmetatable({}, { __index = InkImporter })
  self._container = container
  self._issues = {}
  self._current_knot = ""

  -- Get factories if available
  if container then
    if container.has and container:has("story_factory") then
      self._story_factory = container:resolve("story_factory")
    end
    if container.has and container:has("passage_factory") then
      self._passage_factory = container:resolve("passage_factory")
    end
  end

  -- Fallback to requiring factories
  if not self._story_factory then
    local ok, factory = pcall(require, "whisker.core.factories.story_factory")
    if ok then self._story_factory = factory.new() end
  end
  if not self._passage_factory then
    local ok, factory = pcall(require, "whisker.core.factories.passage_factory")
    if ok then self._passage_factory = factory.new() end
  end

  return self
end

--- Check if source can be imported as Ink
-- @param source string Source content
-- @param options table Import options
-- @return boolean
-- @return string|nil Error message
function InkImporter:can_import(source, options)
  if type(source) ~= "string" or source == "" then
    return false, "Empty or invalid source"
  end

  -- Check for Ink-specific patterns (simpler patterns that work across lines)
  local has_knot = source:find("===[ \t]*%w+[ \t]*===") ~= nil
  local has_choice = source:find("[*+][ \t]*%[") ~= nil
  local has_var = source:find("VAR[ \t]+%w+[ \t]*=") ~= nil
  local has_divert = source:find("->[ \t]*%w+") ~= nil

  -- At least two Ink patterns should match
  local matches = 0
  if has_knot then matches = matches + 1 end
  if has_choice then matches = matches + 1 end
  if has_var then matches = matches + 1 end
  if has_divert then matches = matches + 1 end

  if matches < 2 then
    return false, "Content does not appear to be Ink format"
  end

  return true
end

--- Detect if source is Ink format
-- @param source string Source content
-- @return boolean
function InkImporter:detect(source)
  local can, _ = self:can_import(source)
  return can
end

--- Validate Ink content
-- @param source string Source content
-- @return table Table with errors array
function InkImporter:validate(source)
  local errors = {}

  if type(source) ~= "string" then
    table.insert(errors, "Ink import requires string content")
    return errors
  end

  if source:match("^%s*$") then
    table.insert(errors, "Empty Ink content")
    return errors
  end

  -- Check for unmatched braces
  local open_braces = 0
  local close_braces = 0
  for _ in source:gmatch("{") do open_braces = open_braces + 1 end
  for _ in source:gmatch("}") do close_braces = close_braces + 1 end

  if open_braces ~= close_braces then
    table.insert(errors, string.format(
      "Unmatched braces: %d open, %d close", open_braces, close_braces
    ))
  end

  return errors
end

--- Import Ink source to WLS Story
-- @param source string Source content
-- @param options table Import options
-- @return Story
function InkImporter:import(source, options)
  options = options or {}
  self._issues = {}

  -- Parse Ink content
  local parsed = self:_parse_ink(source)

  -- Convert to Story model
  local story = self:_convert_to_story(parsed)

  return story
end

--- Get importer metadata
-- @return table
function InkImporter:metadata()
  return {
    name = "ink",
    version = "1.0.0",
    description = "Import Ink narrative scripting language stories to WLS format",
    extensions = { ".ink" },
    mime_types = { "text/plain", "text/x-ink" },
    source_format = "Ink",
    target_format = "WLS 1.0",
  }
end

--- Get conversion issues
-- @return table Array of issues
function InkImporter:get_issues()
  return self._issues
end

--- Build loss report from collected issues
-- @return table Loss report
function InkImporter:get_loss_report()
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
-- @param message string Issue message
-- @param passage_name string|nil Passage name
function InkImporter:_add_issue(severity, category, feature, message, passage_name)
  table.insert(self._issues, {
    severity = severity,
    category = category,
    feature = feature,
    message = message,
    passage_name = passage_name,
    passage_id = passage_name,
  })
end

--- Parse Ink content into intermediate structure
-- @param content string Ink source content
-- @return table Parsed Ink story structure
function InkImporter:_parse_ink(content)
  local story = {
    title = "Untitled Ink Story",
    author = nil,
    variables = {},
    knots = {},
    includes = {},
    external_functions = {},
  }

  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  local current_knot = nil
  local current_stitch = nil
  local current_content = {}
  local in_block_comment = false

  local i = 1
  while i <= #lines do
    local line = lines[i]
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Handle block comments
    if in_block_comment then
      if trimmed:find("%*/") then
        in_block_comment = false
      end
      i = i + 1
      goto continue
    end

    if trimmed:find("^/%*") then
      if not trimmed:find("%*/") then
        in_block_comment = true
      end
      i = i + 1
      goto continue
    end

    -- Skip empty lines and single-line comments
    if trimmed == "" or trimmed:match("^//") then
      i = i + 1
      goto continue
    end

    -- INCLUDE directive
    local include = trimmed:match("^INCLUDE%s+(.+)$")
    if include then
      table.insert(story.includes, include:match("^%s*(.-)%s*$"))
      self:_add_issue(Severity.INFO, "include", "INCLUDE directive",
        "INCLUDE " .. include .. " - external files not automatically resolved")
      i = i + 1
      goto continue
    end

    -- EXTERNAL function declaration
    local func = trimmed:match("^EXTERNAL%s+(%w+)")
    if func then
      table.insert(story.external_functions, func)
      self:_add_issue(Severity.WARNING, "external", "EXTERNAL function",
        "External function " .. func .. " requires manual implementation")
      i = i + 1
      goto continue
    end

    -- VAR declaration (use [%w_]+ to allow underscores in names)
    local var_name, var_value = trimmed:match("^VAR%s+([%w_]+)%s*=%s*(.+)$")
    if var_name then
      story.variables[var_name] = {
        value = var_value:match("^%s*(.-)%s*$"),
        var_type = self:_infer_type(var_value:match("^%s*(.-)%s*$")),
      }
      i = i + 1
      goto continue
    end

    -- CONST declaration (use [%w_]+ to allow underscores in names)
    local const_name, const_value = trimmed:match("^CONST%s+([%w_]+)%s*=%s*(.+)$")
    if const_name then
      story.variables[const_name] = {
        value = const_value:match("^%s*(.-)%s*$"),
        var_type = self:_infer_type(const_value:match("^%s*(.-)%s*$")),
      }
      i = i + 1
      goto continue
    end

    -- Knot header (=== knot_name ===)
    local knot_name, knot_params = trimmed:match("^===[ \t]*(%w+)[ \t]*%((.-)%)[ \t]*===?$")
    if not knot_name then
      knot_name = trimmed:match("^===[ \t]*(%w+)[ \t]*===?$")
    end

    if knot_name then
      -- Save previous knot
      if current_knot then
        if current_stitch then
          current_knot.stitches[current_stitch] = self:_copy_table(current_content)
        else
          current_knot.content = self:_copy_table(current_content)
        end
        story.knots[current_knot.name] = current_knot
      end

      current_knot = {
        name = knot_name,
        content = {},
        stitches = {},
        is_function = knot_params ~= nil,
      }
      current_stitch = nil
      current_content = {}
      self._current_knot = knot_name

      if knot_params then
        self:_add_issue(Severity.WARNING, "function", "Parameterized knot",
          "Knot " .. knot_name .. " has parameters - converted to regular passage", knot_name)
      end

      i = i + 1
      goto continue
    end

    -- Function header (=== function name(params) ===)
    local func_name = trimmed:match("^===[ \t]*function[ \t]+(%w+)[ \t]*%(.-%)[ \t]*===?$")
    if func_name then
      if current_knot then
        if current_stitch then
          current_knot.stitches[current_stitch] = self:_copy_table(current_content)
        else
          current_knot.content = self:_copy_table(current_content)
        end
        story.knots[current_knot.name] = current_knot
      end

      current_knot = {
        name = func_name,
        content = {},
        stitches = {},
        is_function = true,
      }
      current_stitch = nil
      current_content = {}
      self._current_knot = func_name

      self:_add_issue(Severity.WARNING, "function", "Ink function",
        "Function " .. func_name .. " converted to tunnel passage", func_name)

      i = i + 1
      goto continue
    end

    -- Stitch header (= stitch_name)
    local stitch_name = trimmed:match("^=[ \t]*(%w+)%s*$")
    if stitch_name and current_knot then
      -- Save previous stitch content
      if current_stitch then
        current_knot.stitches[current_stitch] = self:_copy_table(current_content)
      else
        current_knot.content = self:_copy_table(current_content)
      end

      current_stitch = stitch_name
      current_content = {}

      i = i + 1
      goto continue
    end

    -- Regular content line
    table.insert(current_content, line)

    i = i + 1
    ::continue::
  end

  -- Save last knot
  if current_knot then
    if current_stitch then
      current_knot.stitches[current_stitch] = self:_copy_table(current_content)
    else
      current_knot.content = self:_copy_table(current_content)
    end
    story.knots[current_knot.name] = current_knot
  end

  -- If no knots, create implicit Start
  local has_knots = false
  for _ in pairs(story.knots) do
    has_knots = true
    break
  end

  if not has_knots then
    local content_lines = {}
    for _, line in ipairs(lines) do
      local trimmed = line:match("^%s*(.-)%s*$")
      if not trimmed:match("^VAR%s") and not trimmed:match("^CONST%s") and trimmed ~= "" then
        table.insert(content_lines, line)
      end
    end
    if #content_lines > 0 then
      story.knots["Start"] = {
        name = "Start",
        content = content_lines,
        stitches = {},
      }
    end
  end

  return story
end

--- Convert parsed Ink to Story model
-- @param parsed table Parsed Ink structure
-- @return Story
function InkImporter:_convert_to_story(parsed)
  local passages = {}
  local variables = {}

  -- Convert variables
  for name, var_info in pairs(parsed.variables) do
    variables[name] = {
      type = var_info.var_type,
      default = self:_parse_value(var_info.value, var_info.var_type),
    }
  end

  -- Convert knots to passages
  for knot_name, knot in pairs(parsed.knots) do
    -- Convert main knot content
    local content, choices = self:_convert_content(knot.content, knot_name)

    local passage = {
      id = knot_name,
      name = knot_name,
      content = content,
      choices = choices,
      tags = {},
    }

    passages[knot_name] = passage

    -- Convert stitches as separate passages
    for stitch_name, stitch_content in pairs(knot.stitches) do
      local full_name = knot_name .. "." .. stitch_name
      local s_content, s_choices = self:_convert_content(stitch_content, full_name)

      local stitch_passage = {
        id = full_name,
        name = full_name,
        content = s_content,
        choices = s_choices,
        tags = {},
      }

      passages[full_name] = stitch_passage
    end
  end

  -- Determine start passage
  local start_passage_id = "Start"
  if not passages["Start"] then
    for name, _ in pairs(passages) do
      start_passage_id = name
      break
    end
  end

  -- Create Story directly (factories can complicate the simple creation)
  local Story = require("whisker.core.story")
  local story = Story.new({
    title = parsed.title,
    author = parsed.author,
    start_passage = start_passage_id,
    variables = variables,
  })

  -- Add passages to story
  if self._passage_factory then
    for id, passage_data in pairs(passages) do
      local passage = self._passage_factory:create(passage_data)
      story:add_passage(passage)
    end
  else
    local PassageFactory = require("whisker.core.factories.passage_factory")
    local factory = PassageFactory.new()
    for id, passage_data in pairs(passages) do
      local passage = factory:create(passage_data)
      story:add_passage(passage)
    end
  end

  return story
end

--- Convert Ink content lines to WLS content and choices
-- @param lines table Array of content lines
-- @param passage_name string Current passage name
-- @return string content
-- @return table choices
function InkImporter:_convert_content(lines, passage_name)
  local content_parts = {}
  local choices = {}
  local choice_index = 0

  for _, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed == "" then
      goto continue
    end

    -- Choice (* or +)
    local markers, bracket_text, after_text = trimmed:match("^([*+]+)%s*%[([^%]]*)%]%s*(.*)$")
    if not markers then
      markers, after_text = trimmed:match("^([*+]+)%s*(.*)$")
    end

    if markers then
      local is_sticky = markers:sub(1, 1) == "+"
      local text = bracket_text or after_text or "Continue"
      local remaining_text = after_text or ""

      -- Extract target from divert
      local target = remaining_text:match("->%s*(%w+[%.%w]*)") or ""
      remaining_text = remaining_text:gsub("->%s*%w+[%.%w]*", ""):match("^%s*(.-)%s*$")

      local choice = {
        id = passage_name .. "_choice_" .. choice_index,
        text = (text:match("^%s*(.-)%s*$") ~= "" and text:match("^%s*(.-)%s*$")) or "Continue",
        target = target ~= "" and target or nil,
      }
      choice_index = choice_index + 1

      table.insert(choices, choice)
      goto continue
    end

    -- Divert (-> target) at end of line - check this BEFORE gather point
    local divert_target = trimmed:match("^%->%s*([%w_]+[%.%w_]*)%s*$")
    if divert_target then
      local choice = {
        id = passage_name .. "_divert_" .. choice_index,
        text = "Continue",
        target = divert_target,
      }
      choice_index = choice_index + 1
      table.insert(choices, choice)
      goto continue
    end

    -- Gather point (-) but NOT divert (->)
    if trimmed:match("^%-+%s") and not trimmed:match("^%->") then
      local gather_content = trimmed:gsub("^%-+%s*", "")
      if gather_content ~= "" then
        table.insert(content_parts, gather_content)
      end
      goto continue
    end

    -- Tunnel call (-> target ->)
    local tunnel_target = trimmed:match("^%->%s*([%w_]+[%.%w_]*)%s*%->$")
    if tunnel_target then
      table.insert(content_parts, "-> " .. tunnel_target .. " ->")
      goto continue
    end

    -- Tunnel return (<-)
    if trimmed == "<-" then
      table.insert(content_parts, "<-")
      goto continue
    end

    -- Variable assignment (~ var = value)
    local var_name, var_value = trimmed:match("^~%s*(%w+)%s*=%s*(.+)$")
    if var_name then
      table.insert(content_parts, "{do " .. var_name .. " = " .. self:_convert_expression(var_value) .. "}")
      goto continue
    end

    -- Conditional content ({ condition: text } or { condition })
    local cond_inner = trimmed:match("^{([^}]+)}$")
    if cond_inner then
      if cond_inner:find(":") then
        -- Inline conditional
        local cond, cond_text = cond_inner:match("([^:]+):(.+)")
        if cond and cond_text then
          table.insert(content_parts, "{" .. self:_convert_expression(cond:match("^%s*(.-)%s*$")) .. ": " .. cond_text:match("^%s*(.-)%s*$") .. " | }")
        end
      elseif cond_inner:find("|") then
        -- Alternatives
        table.insert(content_parts, "{| " .. cond_inner .. " }")
      else
        -- Just condition check or variable interpolation
        table.insert(content_parts, "${" .. self:_convert_expression(cond_inner) .. "}")
      end
      goto continue
    end

    -- Regular text (convert inline Ink syntax)
    local converted = line

    -- Convert inline variable references {var}
    converted = converted:gsub("{(%w+)}", "$%1")

    -- Convert inline conditionals {cond: text}
    converted = converted:gsub("{([^:}]+):([^}]+)}", function(cond, text)
      return "{" .. self:_convert_expression(cond:match("^%s*(.-)%s*$")) .. ": " .. text:match("^%s*(.-)%s*$") .. " | }"
    end)

    table.insert(content_parts, converted)

    ::continue::
  end

  return table.concat(content_parts, "\n"), choices
end

--- Convert Ink expression to WLS expression
-- @param expr string Ink expression
-- @return string WLS expression
function InkImporter:_convert_expression(expr)
  local result = expr:match("^%s*(.-)%s*$")

  -- Convert 'and' to &&, 'or' to ||, 'not' to !
  result = result:gsub("%band%b", "&&")
  result = result:gsub("%bor%b", "||")
  result = result:gsub("%bnot%b", "!")

  return result
end

--- Infer type from value string
-- @param value string Value string
-- @return string Type name
function InkImporter:_infer_type(value)
  if value == "true" or value == "false" then
    return "boolean"
  end
  if value:match("^%-?%d+$") then
    return "number"
  end
  if value:match("^%-?%d+%.%d+$") then
    return "number"
  end
  if value:match('^"') or value:match("^'") then
    return "string"
  end
  return "string"
end

--- Parse value string to typed value
-- @param value string Value string
-- @param var_type string Type name
-- @return any Typed value
function InkImporter:_parse_value(value, var_type)
  if var_type == "boolean" then
    return value == "true"
  elseif var_type == "number" then
    return tonumber(value)
  else
    return value:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")
  end
end

--- Copy table (shallow)
-- @param t table Table to copy
-- @return table Copy
function InkImporter:_copy_table(t)
  local copy = {}
  for i, v in ipairs(t) do
    copy[i] = v
  end
  return copy
end

return InkImporter
