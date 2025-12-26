-- Snowman Format Converter

local M = {}

-- Require the report module
local Report = require("whisker.format.converters.report")

function M.to_harlowe(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = passage.content

    -- Convert <%= s.var %> to $var (do this first)
    content = content:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "$%1")

    -- Convert <% s.var = value; %> to (set: $var to value)
    content = content:gsub("<%%%s*(.-)%s*%%>", function(code)
      -- Handle variable assignments
      local result = code:gsub("s%.([%w_]+)%s*=%s*([^;]+)%s*;?", function(var, value)
        return "(set: $" .. var .. " to " .. value .. ")"
      end)
      return result
    end)

    -- Convert [Text](Target) to [[Text->Target]]
    content = content:gsub("%[(.-)%]%((.-)%)", "[[%1->%2]]")

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

function M.to_sugarcube(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = passage.content

    -- Convert <%= s.var %> to $var (do this first)
    content = content:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "$%1")

    -- Convert <% s.var = value %> to <<set $var to value>>
    content = content:gsub("<%%%s*(.-)%s*%%>", function(code)
      -- Handle variable assignments
      local result = code:gsub("s%.([%w_]+)%s*=%s*([^;]+)%s*;?", function(var, value)
        return "<<set $" .. var .. " to " .. value .. ">>"
      end)
      return result
    end)

    -- Convert [Text](Target) to [[Text|Target]]
    content = content:gsub("%[(.-)%]%((.-)%)", "[[%1|%2]]")

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

function M.to_chapbook(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = passage.content

    -- Convert <%= s.var %> to {var} (do this first)
    content = content:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "{%1}")

    -- Extract variable assignments from code blocks for vars section
    local vars = {}
    content = content:gsub("<%%%s*(.-)%s*%%>", function(code)
      -- Extract variable assignments
      for var, value in code:gmatch("s%.([%w_]+)%s*=%s*([^;]+)%s*;?") do
        table.insert(vars, var .. ": " .. value)
      end
      return "" -- Remove code blocks
    end)

    -- Add vars section if we have variables
    if #vars > 0 then
      table.insert(result, table.concat(vars, "\n"))
      table.insert(result, "--")
    end

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

-- Helper conversion functions
function M.convert_code_to_harlowe(snowman_text)
  local text = snowman_text

  -- Convert <% s.var = value; %> to (set: $var to value)
  text = text:gsub("<%%%s*(.-)%s*%%>", function(code)
    local result = code:gsub("s%.([%w_]+)%s*=%s*([^;]+)%s*;?", function(var, value)
      return "(set: $" .. var .. " to " .. value .. ")"
    end)
    return result
  end)

  return text
end

function M.convert_code_to_sugarcube(snowman_text)
  local text = snowman_text

  -- Convert <% s.var = value; %> to <<set $var to value>>
  text = text:gsub("<%%%s*(.-)%s*%%>", function(code)
    local result = code:gsub("s%.([%w_]+)%s*=%s*([^;]+)%s*;?", function(var, value)
      return "<<set $" .. var .. " to " .. value .. ">>"
    end)
    return result
  end)

  return text
end

function M.convert_text_to_harlowe(snowman_text)
  -- Convert <%= s.var %> to $var
  return snowman_text:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "$%1")
end

function M.convert_text_to_sugarcube(snowman_text)
  -- Convert <%= s.var %> to $var
  return snowman_text:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "$%1")
end

function M.convert_text_to_chapbook(snowman_text)
  -- Convert <%= s.var %> to {var}
  return snowman_text:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "{%1}")
end

function M.convert_link_to_harlowe(snowman_text)
  -- Convert [Text](Target) to [[Text->Target]]
  return snowman_text:gsub("%[(.-)%]%((.-)%)", "[[%1->%2]]")
end

function M.convert_link_to_sugarcube(snowman_text)
  -- Convert [Text](Target) to [[Text|Target]]
  return snowman_text:gsub("%[(.-)%]%((.-)%)", "[[%1|%2]]")
end

function M.convert_link_to_chapbook(snowman_text)
  -- Convert [Text](Target) to [[Text->Target]] (Chapbook uses same as Harlowe)
  return snowman_text:gsub("%[(.-)%]%((.-)%)", "[[%1->%2]]")
end

function M.convert_to_harlowe_passage(snowman_text)
  local text = snowman_text

  -- Convert interpolations FIRST (before code blocks)
  text = M.convert_text_to_harlowe(text)

  -- Convert code blocks
  text = M.convert_code_to_harlowe(text)

  -- Convert links
  text = M.convert_link_to_harlowe(text)

  return text
end

function M.convert_to_sugarcube_passage(snowman_text)
  local text = snowman_text

  -- Convert interpolations FIRST (before code blocks)
  text = M.convert_text_to_sugarcube(text)

  -- Convert code blocks
  text = M.convert_code_to_sugarcube(text)

  -- Convert links
  text = M.convert_link_to_sugarcube(text)

  return text
end

function M.convert_to_chapbook_passage(snowman_text)
  local vars = {}
  local content_lines = {}

  -- Extract code blocks and parse variable assignments
  for line in (snowman_text .. "\n"):gmatch("([^\n]*)\n") do
    local code_match = line:match("<%%%s*(.-)%s*%%>")
    if code_match and not code_match:match("^=") then
      -- Extract variable assignments
      for var, value in code_match:gmatch("s%.([%w_]+)%s*=%s*([^;]+)%s*;?") do
        table.insert(vars, var .. ": " .. value)
      end
    else
      table.insert(content_lines, line)
    end
  end

  -- Build result
  local result = {}

  if #vars > 0 then
    table.insert(result, table.concat(vars, "\n"))
    table.insert(result, "--")
  end

  -- Convert remaining content
  local content = table.concat(content_lines, "\n")

  -- Convert <%= s.var %> to {var}
  content = M.convert_text_to_chapbook(content)

  -- Convert links
  content = M.convert_link_to_chapbook(content)

  table.insert(result, content)

  return table.concat(result, "\n")
end

function M.convert_conditional_to_harlowe(snowman_text)
  -- Convert <% if (s.var > value) { %>...<% } %> to (if: $var > value)[...]
  return snowman_text:gsub("<%%%s*if%s*%((.-)%)%s*{%s*%%>(.-)<%% }%s*%%>", function(cond, body)
    -- Convert s.var to $var in condition
    cond = cond:gsub("s%.([%w_]+)", "$%1")
    return "(if: " .. cond .. ")[" .. body .. "]"
  end)
end

function M.convert_conditional_to_sugarcube(snowman_text)
  -- Convert <% if (s.var > value) { %>...<% } %> to <<if $var > value>>...<</if>>
  return snowman_text:gsub("<%%%s*if%s*%((.-)%)%s*{%s*%%>(.-)<%% }%s*%%>", function(cond, body)
    -- Convert s.var to $var in condition
    cond = cond:gsub("s%.([%w_]+)", "$%1")
    return "<<if " .. cond .. ">>" .. body .. "<</if>>"
  end)
end

function M.convert_conditional_to_chapbook(snowman_text)
  -- Convert <% if (s.var > value) { %>...<% } %> to [if var > value]...[continue]
  return snowman_text:gsub("<%%%s*if%s*%((.-)%)%s*{%s*%%>(.-)<%% }%s*%%>", function(cond, body)
    -- Convert s.var to var in condition (Chapbook doesn't use $ or s.)
    cond = cond:gsub("s%.([%w_]+)", "%1")
    return "[if " .. cond .. "]" .. body .. "[continue]"
  end)
end

-- Features directly converted to Harlowe
local HARLOWE_CONVERTED = {
  {pattern = "<%%%s*s%.", feature = "set", converts_to = "(set: ...)"},
  {pattern = "<%%=%s*s%.", feature = "variable", converts_to = "$var"},
  {pattern = "%[.-%]%(.-%)", feature = "link", converts_to = "[[...->...]]"},
}

-- Features approximated in Harlowe
local HARLOWE_APPROXIMATED = {
  {pattern = "<%%%s*if%s*%(", feature = "if", converts_to = "(if: ...)", notes = "Condition syntax differs"},
}

-- Features incompatible with Harlowe
local HARLOWE_INCOMPATIBLE = {
  {pattern = "window%.", feature = "window-object", description = "Direct DOM access not available in Harlowe"},
  {pattern = "document%.", feature = "document-object", description = "Direct DOM access not available in Harlowe"},
}

-- Features directly converted to SugarCube
local SUGARCUBE_CONVERTED = {
  {pattern = "<%%%s*s%.", feature = "set", converts_to = "<<set>>"},
  {pattern = "<%%=%s*s%.", feature = "variable", converts_to = "$var"},
  {pattern = "%[.-%]%(.-%)", feature = "link", converts_to = "[[...|...]]"},
}

-- Features approximated in SugarCube
local SUGARCUBE_APPROXIMATED = {
  {pattern = "<%%%s*if%s*%(", feature = "if", converts_to = "<<if>>", notes = "Syntax differs"},
}

-- Features incompatible with SugarCube
local SUGARCUBE_INCOMPATIBLE = {}

-- Features directly converted to Chapbook
local CHAPBOOK_CONVERTED = {
  {pattern = "<%%%s*s%.", feature = "set", converts_to = "vars section"},
  {pattern = "<%%=%s*s%.", feature = "variable", converts_to = "{var}"},
}

-- Features approximated in Chapbook
local CHAPBOOK_APPROXIMATED = {
  {pattern = "<%%%s*if%s*%(", feature = "if", converts_to = "[if ...]", notes = "Syntax differs"},
}

-- Features incompatible with Chapbook
local CHAPBOOK_INCOMPATIBLE = {
  {pattern = "window%.", feature = "window-object", description = "Direct JS access limited in Chapbook"},
  {pattern = "document%.", feature = "document-object", description = "Direct JS access limited in Chapbook"},
}

--- Convert Snowman to Harlowe with detailed report
-- @param parsed_story table The parsed Snowman story
-- @return string, Report The converted content and conversion report
function M.to_harlowe_with_report(parsed_story)
  local report = Report.new("snowman", "harlowe")
  report:set_passage_count(#parsed_story.passages)

  for _, passage in ipairs(parsed_story.passages) do
    local content = passage.content

    -- Track converted features
    for _, conv in ipairs(HARLOWE_CONVERTED) do
      if content:match(conv.pattern) then
        for _ in content:gmatch(conv.pattern) do
          report:add_converted(conv.feature, passage.name, {
            original = conv.pattern,
            result = conv.converts_to
          })
        end
      end
    end

    -- Track approximated features
    for _, approx in ipairs(HARLOWE_APPROXIMATED) do
      if content:match(approx.pattern) then
        for _ in content:gmatch(approx.pattern) do
          report:add_approximated(
            approx.feature,
            passage.name,
            approx.pattern,
            approx.converts_to,
            {notes = approx.notes}
          )
        end
      end
    end

    -- Track incompatible features
    for _, incomp in ipairs(HARLOWE_INCOMPATIBLE) do
      if content:match(incomp.pattern) then
        for _ in content:gmatch(incomp.pattern) do
          report:add_lost(incomp.feature, passage.name, incomp.description, {})
        end
      end
    end
  end

  local result = M.to_harlowe(parsed_story)
  return result, report
end

--- Convert Snowman to SugarCube with detailed report
-- @param parsed_story table The parsed Snowman story
-- @return string, Report The converted content and conversion report
function M.to_sugarcube_with_report(parsed_story)
  local report = Report.new("snowman", "sugarcube")
  report:set_passage_count(#parsed_story.passages)

  for _, passage in ipairs(parsed_story.passages) do
    local content = passage.content

    -- Track converted features
    for _, conv in ipairs(SUGARCUBE_CONVERTED) do
      if content:match(conv.pattern) then
        for _ in content:gmatch(conv.pattern) do
          report:add_converted(conv.feature, passage.name, {
            original = conv.pattern,
            result = conv.converts_to
          })
        end
      end
    end

    -- Track approximated features
    for _, approx in ipairs(SUGARCUBE_APPROXIMATED) do
      if content:match(approx.pattern) then
        for _ in content:gmatch(approx.pattern) do
          report:add_approximated(
            approx.feature,
            passage.name,
            approx.pattern,
            approx.converts_to,
            {notes = approx.notes}
          )
        end
      end
    end

    -- Track incompatible features
    for _, incomp in ipairs(SUGARCUBE_INCOMPATIBLE) do
      if content:match(incomp.pattern) then
        for _ in content:gmatch(incomp.pattern) do
          report:add_lost(incomp.feature, passage.name, incomp.description, {})
        end
      end
    end
  end

  local result = M.to_sugarcube(parsed_story)
  return result, report
end

--- Convert Snowman to Chapbook with detailed report
-- @param parsed_story table The parsed Snowman story
-- @return string, Report The converted content and conversion report
function M.to_chapbook_with_report(parsed_story)
  local report = Report.new("snowman", "chapbook")
  report:set_passage_count(#parsed_story.passages)

  for _, passage in ipairs(parsed_story.passages) do
    local content = passage.content

    -- Track converted features
    for _, conv in ipairs(CHAPBOOK_CONVERTED) do
      if content:match(conv.pattern) then
        for _ in content:gmatch(conv.pattern) do
          report:add_converted(conv.feature, passage.name, {
            original = conv.pattern,
            result = conv.converts_to
          })
        end
      end
    end

    -- Track approximated features
    for _, approx in ipairs(CHAPBOOK_APPROXIMATED) do
      if content:match(approx.pattern) then
        for _ in content:gmatch(approx.pattern) do
          report:add_approximated(
            approx.feature,
            passage.name,
            approx.pattern,
            approx.converts_to,
            {notes = approx.notes}
          )
        end
      end
    end

    -- Track incompatible features
    for _, incomp in ipairs(CHAPBOOK_INCOMPATIBLE) do
      if content:match(incomp.pattern) then
        for _ in content:gmatch(incomp.pattern) do
          report:add_lost(incomp.feature, passage.name, incomp.description, {})
        end
      end
    end
  end

  local result = M.to_chapbook(parsed_story)
  return result, report
end

return M
