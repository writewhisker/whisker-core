-- Ink Format Converter
-- Converts Ink stories to Twine formats and vice versa

local M = {}

local Report = require("whisker.format.converters.report")
local Compat = require("whisker.format.converters.ink_compat")

--- Parse Ink content into internal structure
-- @param ink_content string The raw Ink content
-- @return table Parsed story structure
function M.parse(ink_content)
  local story = {
    title = "Untitled",
    format = "ink",
    passages = {},
    variables = {},
    metadata = {}
  }

  local current_knot = nil
  local current_content = {}
  local lines = {}

  -- Split content into lines
  for line in (ink_content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  -- First pass: extract global variables
  for _, line in ipairs(lines) do
    local var, value = line:match("^%s*VAR%s+([%w_]+)%s*=%s*(.+)%s*$")
    if var then
      story.variables[var] = value
    end
  end

  -- Second pass: extract knots and content
  for _, line in ipairs(lines) do
    -- Check for knot header (=== knot_name ===)
    local knot_name = line:match("^%s*===%s*([%w_]+)%s*===?%s*$")
    if knot_name then
      -- Save previous knot
      if current_knot then
        table.insert(story.passages, {
          name = current_knot,
          content = table.concat(current_content, "\n"),
          tags = {}
        })
      end
      current_knot = knot_name
      current_content = {}
    elseif current_knot then
      -- Skip VAR declarations in knot content
      if not line:match("^%s*VAR%s+") then
        table.insert(current_content, line)
      end
    elseif not line:match("^%s*VAR%s+") and line:match("%S") then
      -- Content before first knot - create implicit "Start" knot
      if not current_knot then
        current_knot = "Start"
      end
      table.insert(current_content, line)
    end
  end

  -- Save last knot
  if current_knot then
    table.insert(story.passages, {
      name = current_knot,
      content = table.concat(current_content, "\n"),
      tags = {}
    })
  end

  -- If no passages found, create a Start passage with all content
  if #story.passages == 0 and #lines > 0 then
    local non_var_lines = {}
    for _, line in ipairs(lines) do
      if not line:match("^%s*VAR%s+") then
        table.insert(non_var_lines, line)
      end
    end
    table.insert(story.passages, {
      name = "Start",
      content = table.concat(non_var_lines, "\n"),
      tags = {}
    })
  end

  return story
end

--- Convert Ink content to Harlowe
-- @param ink_content string Raw Ink content or parsed story
-- @return string Harlowe Twee content
function M.to_harlowe(ink_content)
  local parsed
  if type(ink_content) == "string" then
    parsed = M.parse(ink_content)
  else
    parsed = ink_content
  end

  local result = {}

  -- Add variable declarations at the start
  if parsed.variables and next(parsed.variables) then
    table.insert(result, ":: StoryInit")
    for var, value in pairs(parsed.variables) do
      table.insert(result, "(set: $" .. var .. " to " .. value .. ")")
    end
    table.insert(result, "")
  end

  -- Convert each passage
  for _, passage in ipairs(parsed.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = M.convert_ink_content_to_harlowe(passage.content)
    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

--- Convert Ink passage content to Harlowe
-- @param content string Ink passage content
-- @return string Harlowe content
function M.convert_ink_content_to_harlowe(content)
  local lines = {}

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    local converted = line

    -- Convert variable assignments: ~ var = value -> (set: $var to value)
    converted = converted:gsub("~%s*([%w_]+)%s*=%s*(.+)", function(var, value)
      return "(set: $" .. var .. " to " .. value .. ")"
    end)

    -- Convert conditionals: {condition: text} -> (if: condition)[text]
    converted = converted:gsub("{%s*([^:}]+)%s*:%s*([^}]*)}", function(cond, body)
      cond = cond:gsub("([%w_]+)", function(var)
        if var:match("^%d") or var == "true" or var == "false" or var == "and" or var == "or" or var == "not" then
          return var
        end
        return "$" .. var
      end)
      return "(if: " .. cond .. ")[" .. body .. "]"
    end)

    -- Convert choices with divert: * [Choice] -> target
    local indent, choice_text, target = converted:match("^(%s*)%*+%s*%[([^%]]+)%]%s*%->%s*([%w_%.]+)")
    if choice_text and target then
      target = target:gsub("%.", "_")
      converted = indent .. "[[" .. choice_text .. "->" .. target .. "]]"
    else
      -- Convert choices without divert: * [Choice text]
      indent, choice_text = converted:match("^(%s*)%*+%s*%[([^%]]+)%]%s*$")
      if choice_text then
        target = choice_text:gsub("%s+", "_")
        converted = indent .. "[[" .. choice_text .. "->" .. target .. "]]"
      else
        -- Convert simple choices: * Choice text
        indent, choice_text = converted:match("^(%s*)%*+%s+([^%[%]]+)$")
        if choice_text then
          choice_text = choice_text:match("^%s*(.-)%s*$")
          target = choice_text:gsub("%s+", "_")
          converted = indent .. "[[" .. choice_text .. "->" .. target .. "]]"
        end
      end
    end

    -- Convert standalone diverts: -> target (only if not already converted)
    if not converted:match("%[%[.-%]%]") then
      local divert_indent, divert_target = converted:match("^(%s*)%->%s*([%w_%.]+)%s*$")
      if divert_target then
        divert_target = divert_target:gsub("%.", "_")
        converted = divert_indent .. "[[" .. divert_target .. "]]"
      else
        -- Convert inline diverts within text (not inside links)
        converted = converted:gsub("%->%s*([%w_%.]+)", function(t)
          t = t:gsub("%.", "_")
          return "[[" .. t .. "]]"
        end)
      end
    end

    -- Convert variable interpolation: {var} -> $var
    converted = converted:gsub("{([%w_]+)}", function(var)
      return "$" .. var
    end)

    table.insert(lines, converted)
  end

  -- Remove trailing empty line that we added
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end

  return table.concat(lines, "\n")
end

--- Convert Ink content to SugarCube
-- @param ink_content string Raw Ink content or parsed story
-- @return string SugarCube Twee content
function M.to_sugarcube(ink_content)
  local parsed
  if type(ink_content) == "string" then
    parsed = M.parse(ink_content)
  else
    parsed = ink_content
  end

  local result = {}

  -- Add variable declarations
  if parsed.variables and next(parsed.variables) then
    table.insert(result, ":: StoryInit")
    for var, value in pairs(parsed.variables) do
      table.insert(result, "<<set $" .. var .. " to " .. value .. ">>")
    end
    table.insert(result, "")
  end

  -- Convert each passage
  for _, passage in ipairs(parsed.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = M.convert_ink_content_to_sugarcube(passage.content)
    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

--- Convert Ink passage content to SugarCube
-- @param content string Ink passage content
-- @return string SugarCube content
function M.convert_ink_content_to_sugarcube(content)
  local text = content

  -- Convert variable assignments: ~ var = value -> <<set $var to value>>
  text = text:gsub("~%s*([%w_]+)%s*=%s*(.+)", function(var, value)
    return "<<set $" .. var .. " to " .. value .. ">>"
  end)

  -- Convert conditionals: {condition: text} -> <<if condition>>text<</if>>
  text = text:gsub("{%s*([^:}]+)%s*:%s*([^}]*)}", function(cond, body)
    cond = cond:gsub("([%w_]+)", function(var)
      if var:match("^%d") or var == "true" or var == "false" or var == "and" or var == "or" or var == "not" then
        return var
      end
      return "$" .. var
    end)
    return "<<if " .. cond .. ">>" .. body .. "<</if>>"
  end)

  -- Convert choices with divert
  text = text:gsub("^(%s*)%*+%s*%[([^%]]+)%]%s*%->%s*([%w_%.]+)", function(indent, choice_text, target)
    target = target:gsub("%.", "_")
    return indent .. "[[" .. choice_text .. "|" .. target .. "]]"
  end)

  -- Convert choices: * [Choice text] -> [[Choice text|target]]
  text = text:gsub("^(%s*)%*+%s*%[([^%]]+)%]%s*$", function(indent, choice_text)
    local target = choice_text:gsub("%s+", "_")
    return indent .. "[[" .. choice_text .. "|" .. target .. "]]"
  end)

  -- Convert simple choices
  text = text:gsub("^(%s*)%*+%s+([^%[%]%->]+)$", function(indent, choice_text)
    choice_text = choice_text:match("^%s*(.-)%s*$")
    local target = choice_text:gsub("%s+", "_")
    return indent .. "[[" .. choice_text .. "|" .. target .. "]]"
  end)

  -- Convert diverts
  text = text:gsub("^(%s*)%->%s*([%w_%.]+)%s*$", function(indent, target)
    target = target:gsub("%.", "_")
    return indent .. "[[" .. target .. "]]"
  end)

  text = text:gsub("%->%s*([%w_%.]+)", function(target)
    target = target:gsub("%.", "_")
    return "[[" .. target .. "]]"
  end)

  -- Convert variable interpolation
  text = text:gsub("{([%w_]+)}", function(var)
    return "$" .. var
  end)

  return text
end

--- Convert Ink content to Chapbook
-- @param ink_content string Raw Ink content or parsed story
-- @return string Chapbook Twee content
function M.to_chapbook(ink_content)
  local parsed
  if type(ink_content) == "string" then
    parsed = M.parse(ink_content)
  else
    parsed = ink_content
  end

  local result = {}

  -- Convert each passage
  for _, passage in ipairs(parsed.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    -- Extract variables and content
    local vars = {}
    local content_lines = {}

    for line in (passage.content .. "\n"):gmatch("([^\n]*)\n") do
      local var, value = line:match("~%s*([%w_]+)%s*=%s*(.+)")
      if var then
        table.insert(vars, var .. ": " .. value)
      else
        table.insert(content_lines, line)
      end
    end

    -- Add variables from story globals for first passage
    if passage.name == "Start" and parsed.variables and next(parsed.variables) then
      for var, value in pairs(parsed.variables) do
        table.insert(vars, 1, var .. ": " .. value)
      end
    end

    -- Add vars section
    if #vars > 0 then
      table.insert(result, table.concat(vars, "\n"))
      table.insert(result, "--")
    end

    local content = M.convert_ink_content_to_chapbook(table.concat(content_lines, "\n"))
    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

--- Convert Ink passage content to Chapbook
-- @param content string Ink passage content
-- @return string Chapbook content
function M.convert_ink_content_to_chapbook(content)
  local text = content

  -- Remove variable assignments (handled separately in vars section)
  text = text:gsub("~%s*[%w_]+%s*=%s*.+", "")

  -- Convert conditionals: {condition: text} -> [if condition]text[continue]
  text = text:gsub("{%s*([^:}]+)%s*:%s*([^}]*)}", function(cond, body)
    return "[if " .. cond .. "]" .. body .. "[continue]"
  end)

  -- Convert choices with divert
  text = text:gsub("^(%s*)%*+%s*%[([^%]]+)%]%s*%->%s*([%w_%.]+)", function(indent, choice_text, target)
    target = target:gsub("%.", "_")
    return indent .. "[[" .. choice_text .. "->" .. target .. "]]"
  end)

  -- Convert choices
  text = text:gsub("^(%s*)%*+%s*%[([^%]]+)%]%s*$", function(indent, choice_text)
    local target = choice_text:gsub("%s+", "_")
    return indent .. "[[" .. choice_text .. "->" .. target .. "]]"
  end)

  text = text:gsub("^(%s*)%*+%s+([^%[%]%->]+)$", function(indent, choice_text)
    choice_text = choice_text:match("^%s*(.-)%s*$")
    local target = choice_text:gsub("%s+", "_")
    return indent .. "[[" .. choice_text .. "->" .. target .. "]]"
  end)

  -- Convert diverts
  text = text:gsub("^(%s*)%->%s*([%w_%.]+)%s*$", function(indent, target)
    target = target:gsub("%.", "_")
    return indent .. "[[" .. target .. "]]"
  end)

  text = text:gsub("%->%s*([%w_%.]+)", function(target)
    target = target:gsub("%.", "_")
    return "[[" .. target .. "]]"
  end)

  -- Convert variable interpolation: {var} -> {var}
  -- Chapbook already uses {var} syntax, so no change needed

  return text
end

--- Convert Ink content to Snowman
-- @param ink_content string Raw Ink content or parsed story
-- @return string Snowman Twee content
function M.to_snowman(ink_content)
  local parsed
  if type(ink_content) == "string" then
    parsed = M.parse(ink_content)
  else
    parsed = ink_content
  end

  local result = {}

  -- Add variable declarations
  if parsed.variables and next(parsed.variables) then
    table.insert(result, ":: StoryInit")
    for var, value in pairs(parsed.variables) do
      table.insert(result, "<% s." .. var .. " = " .. value .. "; %>")
    end
    table.insert(result, "")
  end

  -- Convert each passage
  for _, passage in ipairs(parsed.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = M.convert_ink_content_to_snowman(passage.content)
    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

--- Convert Ink passage content to Snowman
-- @param content string Ink passage content
-- @return string Snowman content
function M.convert_ink_content_to_snowman(content)
  local text = content

  -- Convert variable assignments: ~ var = value -> <% s.var = value; %>
  text = text:gsub("~%s*([%w_]+)%s*=%s*(.+)", function(var, value)
    return "<% s." .. var .. " = " .. value .. "; %>"
  end)

  -- Convert conditionals: {condition: text} -> <% if (condition) { %>text<% } %>
  text = text:gsub("{%s*([^:}]+)%s*:%s*([^}]*)}", function(cond, body)
    cond = cond:gsub("([%w_]+)", function(var)
      if var:match("^%d") or var == "true" or var == "false" or var == "and" or var == "or" or var == "not" then
        return var
      end
      return "s." .. var
    end)
    return "<% if (" .. cond .. ") { %>" .. body .. "<% } %>"
  end)

  -- Convert choices with divert
  text = text:gsub("^(%s*)%*+%s*%[([^%]]+)%]%s*%->%s*([%w_%.]+)", function(indent, choice_text, target)
    target = target:gsub("%.", "_")
    return indent .. "[" .. choice_text .. "](" .. target .. ")"
  end)

  -- Convert choices
  text = text:gsub("^(%s*)%*+%s*%[([^%]]+)%]%s*$", function(indent, choice_text)
    local target = choice_text:gsub("%s+", "_")
    return indent .. "[" .. choice_text .. "](" .. target .. ")"
  end)

  text = text:gsub("^(%s*)%*+%s+([^%[%]%->]+)$", function(indent, choice_text)
    choice_text = choice_text:match("^%s*(.-)%s*$")
    local target = choice_text:gsub("%s+", "_")
    return indent .. "[" .. choice_text .. "](" .. target .. ")"
  end)

  -- Convert diverts
  text = text:gsub("^(%s*)%->%s*([%w_%.]+)%s*$", function(indent, target)
    target = target:gsub("%.", "_")
    return indent .. "[" .. target .. "](" .. target .. ")"
  end)

  text = text:gsub("%->%s*([%w_%.]+)", function(target)
    target = target:gsub("%.", "_")
    return "[" .. target .. "](" .. target .. ")"
  end)

  -- Convert variable interpolation: {var} -> <%= s.var %>
  text = text:gsub("{([%w_]+)}", function(var)
    return "<%= s." .. var .. " %>"
  end)

  return text
end

-- With report versions

--- Convert Ink to Harlowe with detailed report
-- @param ink_content string Raw Ink content
-- @return string, Report Converted content and report
function M.to_harlowe_with_report(ink_content)
  local parsed = type(ink_content) == "string" and M.parse(ink_content) or ink_content
  local report = Report.new("ink", "harlowe")
  report:set_passage_count(#parsed.passages)

  for _, passage in ipairs(parsed.passages) do
    local content = passage.content

    -- Track converted features
    for _, item in ipairs(Compat.INK_TO_TWINE_SUPPORTED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_converted(item.ink_feature, passage.name, {
            original = item.ink_pattern,
            result = item.twine_equivalent
          })
        end
      end
    end

    -- Track approximated features
    for _, item in ipairs(Compat.INK_TO_TWINE_APPROXIMATED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_approximated(item.ink_feature, passage.name,
            item.ink_pattern, item.approximation, {notes = item.notes})
        end
      end
    end

    -- Track incompatible features
    for _, item in ipairs(Compat.INK_TO_TWINE_INCOMPATIBLE) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_lost(item.ink_feature, passage.name, item.description, {
            severity = item.severity
          })
        end
      end
    end
  end

  local result = M.to_harlowe(parsed)
  return result, report
end

--- Convert Ink to SugarCube with detailed report
-- @param ink_content string Raw Ink content
-- @return string, Report Converted content and report
function M.to_sugarcube_with_report(ink_content)
  local parsed = type(ink_content) == "string" and M.parse(ink_content) or ink_content
  local report = Report.new("ink", "sugarcube")
  report:set_passage_count(#parsed.passages)

  for _, passage in ipairs(parsed.passages) do
    local content = passage.content

    for _, item in ipairs(Compat.INK_TO_TWINE_SUPPORTED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_converted(item.ink_feature, passage.name, {
            original = item.ink_pattern,
            result = item.twine_equivalent
          })
        end
      end
    end

    for _, item in ipairs(Compat.INK_TO_TWINE_APPROXIMATED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_approximated(item.ink_feature, passage.name,
            item.ink_pattern, item.approximation, {notes = item.notes})
        end
      end
    end

    for _, item in ipairs(Compat.INK_TO_TWINE_INCOMPATIBLE) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_lost(item.ink_feature, passage.name, item.description, {
            severity = item.severity
          })
        end
      end
    end
  end

  local result = M.to_sugarcube(parsed)
  return result, report
end

--- Convert Ink to Chapbook with detailed report
-- @param ink_content string Raw Ink content
-- @return string, Report Converted content and report
function M.to_chapbook_with_report(ink_content)
  local parsed = type(ink_content) == "string" and M.parse(ink_content) or ink_content
  local report = Report.new("ink", "chapbook")
  report:set_passage_count(#parsed.passages)

  for _, passage in ipairs(parsed.passages) do
    local content = passage.content

    for _, item in ipairs(Compat.INK_TO_TWINE_SUPPORTED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_converted(item.ink_feature, passage.name, {
            original = item.ink_pattern,
            result = item.twine_equivalent
          })
        end
      end
    end

    for _, item in ipairs(Compat.INK_TO_TWINE_APPROXIMATED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_approximated(item.ink_feature, passage.name,
            item.ink_pattern, item.approximation, {notes = item.notes})
        end
      end
    end

    for _, item in ipairs(Compat.INK_TO_TWINE_INCOMPATIBLE) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_lost(item.ink_feature, passage.name, item.description, {
            severity = item.severity
          })
        end
      end
    end
  end

  local result = M.to_chapbook(parsed)
  return result, report
end

--- Convert Ink to Snowman with detailed report
-- @param ink_content string Raw Ink content
-- @return string, Report Converted content and report
function M.to_snowman_with_report(ink_content)
  local parsed = type(ink_content) == "string" and M.parse(ink_content) or ink_content
  local report = Report.new("ink", "snowman")
  report:set_passage_count(#parsed.passages)

  for _, passage in ipairs(parsed.passages) do
    local content = passage.content

    for _, item in ipairs(Compat.INK_TO_TWINE_SUPPORTED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_converted(item.ink_feature, passage.name, {
            original = item.ink_pattern,
            result = item.twine_equivalent
          })
        end
      end
    end

    for _, item in ipairs(Compat.INK_TO_TWINE_APPROXIMATED) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_approximated(item.ink_feature, passage.name,
            item.ink_pattern, item.approximation, {notes = item.notes})
        end
      end
    end

    for _, item in ipairs(Compat.INK_TO_TWINE_INCOMPATIBLE) do
      if content:match(item.ink_pattern) then
        for _ in content:gmatch(item.ink_pattern) do
          report:add_lost(item.ink_feature, passage.name, item.description, {
            severity = item.severity
          })
        end
      end
    end
  end

  local result = M.to_snowman(parsed)
  return result, report
end

return M
