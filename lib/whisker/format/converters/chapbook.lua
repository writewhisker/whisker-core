-- Chapbook Format Converter
-- Converts Chapbook-format stories to other Twine formats
-- Includes conversion with info about approximations used

local M = {}

-- Require the report module
local Report = require("whisker.format.converters.report")

-- Features that require approximation when converting to Harlowe
local HARLOWE_APPROXIMATIONS = {
  {
    pattern = "%[after%s+%d+s%]",
    feature = "after modifier",
    description = "Timed delays converted to (live:) but behavior differs",
    approximation = "live macro"
  },
  {
    pattern = "%[align%s+",
    feature = "align modifier",
    description = "Text alignment has no direct Harlowe equivalent",
    approximation = "removed (use CSS)"
  },
  {
    pattern = "%[note%]",
    feature = "note modifier",
    description = "Author notes converted to HTML comments",
    approximation = "HTML comment"
  },
  {
    pattern = "{embed%s+",
    feature = "embed insert",
    description = "Embedded passages work differently in Harlowe",
    approximation = "display macro"
  },
  {
    pattern = "{cycling%s+link",
    feature = "cycling link insert",
    description = "Cycling links converted to link-repeat",
    approximation = "link-repeat macro"
  },
  {
    pattern = "{text%s+input",
    feature = "text input insert",
    description = "Text inputs converted to input-box",
    approximation = "input-box macro"
  },
  {
    pattern = "{dropdown",
    feature = "dropdown insert",
    description = "Dropdowns converted to dropdown macro",
    approximation = "dropdown macro"
  },
  {
    pattern = "{reveal%s+link",
    feature = "reveal link insert",
    description = "Reveal links work similarly but syntax differs",
    approximation = "link-reveal macro"
  },
  {
    pattern = "{restart%s+link",
    feature = "restart link",
    description = "Restart functionality uses undo macro",
    approximation = "undo macro"
  },
  {
    pattern = "%[cont'd%]",
    feature = "cont'd modifier",
    description = "Continuation marker not needed in Harlowe",
    approximation = "removed"
  },
}

function M.to_harlowe(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = passage.content

    -- Convert {var} to $var
    content = content:gsub("{([%w_]+)}", "$%1")

    -- Convert vars section to (set: ...) macros
    local vars_section, rest = content:match("^(.-)%-%-(.*)$")
    if vars_section then
      local sets = {}
      for var, value in vars_section:gmatch("([%w_]+):%s*([^\n]+)") do
        table.insert(sets, "(set: $" .. var .. " to " .. value .. ")")
      end
      content = table.concat(sets, "\n") .. "\n" .. rest
    end

    -- Convert [if cond]body to (if: cond)[body]
    content = content:gsub("%[if%s+(.-)%](.-)%[continued%]", "(if: $%1)[%2]")

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

    -- Convert vars section to <<set>> macros
    local vars_section, rest = content:match("^(.-)%-%-(.*)$")
    if vars_section then
      local sets = {}
      for var, value in vars_section:gmatch("([%w_]+):%s*([^\n]+)") do
        table.insert(sets, "<<set $" .. var .. " to " .. value .. ">>")
      end
      content = table.concat(sets, "\n") .. "\n" .. rest
    end

    -- Convert {var} to $var
    content = content:gsub("{([%w_]+)}", "$%1")

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

--- Convert Chapbook to Harlowe with info about approximations used
-- @param parsed_story table The parsed Chapbook story
-- @return string, table The converted content and info about approximations
function M.to_harlowe_with_info(parsed_story)
  local result = M.to_harlowe(parsed_story)
  local info = {
    approximations_used = {},
    exact_conversion = true
  }

  -- Check each passage for features that require approximation
  for _, passage in ipairs(parsed_story.passages) do
    for _, approx in ipairs(HARLOWE_APPROXIMATIONS) do
      if passage.content:match(approx.pattern) then
        table.insert(info.approximations_used, {
          passage = passage.name,
          feature = approx.feature,
          description = approx.description,
          approximation = approx.approximation
        })
        info.exact_conversion = false
      end
    end
  end

  return result, info
end

--- Get list of features that require approximation when converting to Harlowe
-- @return table List of approximation definitions
function M.get_harlowe_approximations()
  return HARLOWE_APPROXIMATIONS
end

-- Convert Chapbook to Snowman
function M.to_snowman(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = passage.content

    -- Extract vars section and convert to <% s.var = value; %>
    local vars_section, rest = content:match("^(.-)%-%-(.*)$")
    if vars_section then
      local code_blocks = {}
      for var, value in vars_section:gmatch("([%w_]+):%s*([^\n]+)") do
        table.insert(code_blocks, "<% s." .. var .. " = " .. value .. "; %>")
      end
      if #code_blocks > 0 then
        content = table.concat(code_blocks, "\n") .. "\n" .. rest
      else
        content = rest
      end
    end

    -- Convert {var} to <%= s.var %>
    content = content:gsub("{([%w_]+)}", function(var)
      return "<%= s." .. var .. " %>"
    end)

    -- Convert [if cond]body[continue] to <% if (cond) { %>body<% } %>
    content = content:gsub("%[if%s+(.-)%](.-)%[continue%]", function(cond, body)
      -- Add s. prefix to variables in condition
      cond = cond:gsub("([%w_]+)", function(word)
        -- Don't prefix operators and numbers
        if word:match("^%d") or word == "if" or word == "else" then
          return word
        end
        return "s." .. word
      end)
      return "<% if (" .. cond .. ") { %>" .. body .. "<% } %>"
    end)

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

-- Helper conversion functions
function M.convert_to_harlowe_passage(chapbook_text)
  local text = chapbook_text

  -- Extract vars section and convert to (set:) macros
  local vars_section, rest = text:match("^(.-)%-%-(.*)$")
  if vars_section then
    local sets = {}
    for var, value in vars_section:gmatch("([%w_]+):%s*([^\n]+)") do
      table.insert(sets, "(set: $" .. var .. " to " .. value .. ")")
    end
    if #sets > 0 then
      text = table.concat(sets, "\n") .. "\n" .. rest
    else
      text = rest
    end
  end

  -- Convert modifiers
  text = M.convert_modifier_to_harlowe(text)

  -- Convert {var} to $var
  text = M.convert_text_to_harlowe(text)

  return text
end

function M.convert_modifier_to_harlowe(chapbook_text)
  local text = chapbook_text

  -- Convert [if cond]body[continue] to (if: cond)[body]
  text = text:gsub("%[if%s+(.-)%](.-)%[continue%]", function(cond, body)
    -- Add $ prefix to variables
    cond = cond:gsub("([%w_]+)", function(word)
      -- Don't prefix operators and numbers
      if word:match("^%d") or word == "if" or word == "else" then
        return word
      end
      return "$" .. word
    end)
    return "(if: " .. cond .. ")[" .. body .. "]"
  end)

  -- Convert [after Xs] to (live: Xs)
  text = text:gsub("%[after%s+(%d+)s%](.-)%[continue%]", function(seconds, body)
    return "(live: " .. seconds .. "s)[" .. body .. "]"
  end)

  -- Remove other modifiers like [align center]
  text = text:gsub("%[align%s+[^%]]+%](.-)%[continue%]", "%1")

  return text
end

function M.convert_text_to_harlowe(chapbook_text)
  -- Convert {var} to $var
  return chapbook_text:gsub("{([%w_]+)}", "$%1")
end

function M.convert_var_to_harlowe(chapbook_text)
  local text = chapbook_text

  -- Convert arrays ['a', 'b'] to (a: 'a', 'b')
  text = text:gsub("%[([^%]]+)%]", function(items)
    if items:match("['\"]") then
      return "(a: " .. items .. ")"
    end
    return "[" .. items .. "]"
  end)

  -- Convert objects {key: value} to (dm: "key", value)
  text = text:gsub("{([^}]+)}", function(pairs)
    local dm_items = {}
    -- Parse key: value pairs
    for key, value in pairs:gmatch("([%w_]+):%s*([^,}]+)") do
      table.insert(dm_items, '"' .. key .. '", ' .. value)
    end
    if #dm_items > 0 then
      return "(dm: " .. table.concat(dm_items, ", ") .. ")"
    end
    return "{" .. pairs .. "}"
  end)

  return text
end

function M.convert_insert_to_harlowe(chapbook_text)
  local text = chapbook_text

  -- Convert {cycling link for: 'var', choices: [...]} to (link-repeat:)
  text = text:gsub("{cycling link for:%s*'([^']+)',%s*choices:%s*%[([^%]]+)%]}", function(var, choices)
    return "(link-repeat: " .. choices .. ")[...]"
  end)

  -- Convert {text input for: 'var'} to (input-box:)
  text = text:gsub("{text input for:%s*'([^']+)'}", function(var)
    return "(input-box: \"X\", $" .. var .. ")"
  end)

  return text
end

function M.convert_to_sugarcube_passage(chapbook_text)
  local text = chapbook_text

  -- Extract vars section and convert to <<set>> macros
  local vars_section, rest = text:match("^(.-)%-%-(.*)$")
  if vars_section then
    local sets = {}
    for var, value in vars_section:gmatch("([%w_]+):%s*([^\n]+)") do
      table.insert(sets, "<<set $" .. var .. " to " .. value .. ">>")
    end
    if #sets > 0 then
      text = table.concat(sets, "\n") .. "\n" .. rest
    else
      text = rest
    end
  end

  -- Convert {var} to $var
  text = M.convert_text_to_sugarcube(text)

  return text
end

function M.convert_modifier_to_sugarcube(chapbook_text)
  local text = chapbook_text

  -- Convert [if cond]body[continue] to <<if cond>>body<</if>>
  text = text:gsub("%[if%s+(.-)%](.-)%[continue%]", function(cond, body)
    -- Add $ prefix to variables
    cond = cond:gsub("([%w_]+)", function(word)
      if word:match("^%d") or word == "if" or word == "else" then
        return word
      end
      return "$" .. word
    end)
    return "<<if " .. cond .. ">>" .. body .. "<</if>>"
  end)

  return text
end

function M.convert_text_to_sugarcube(chapbook_text)
  -- Convert {var} to $var
  return chapbook_text:gsub("{([%w_]+)}", "$%1")
end

function M.convert_insert_to_sugarcube(chapbook_text)
  local text = chapbook_text

  -- Convert {cycling link for: 'var', choices: [...]} to <<listbox>>
  text = text:gsub("{cycling link for:%s*'([^']+)',%s*choices:%s*%[([^%]]+)%]}", function(var, choices)
    return "<<listbox \"$" .. var .. "\" " .. choices .. ">>"
  end)

  -- Convert {text input for: 'var'} to <<textbox>>
  text = text:gsub("{text input for:%s*'([^']+)'}", function(var)
    return "<<textbox \"$" .. var .. "\" \"\">>"
  end)

  return text
end

function M.convert_to_snowman_passage(chapbook_text)
  local text = chapbook_text

  -- Extract vars section and convert to <% s.var = value; %>
  local vars_section, rest = text:match("^(.-)%-%-(.*)$")
  if vars_section then
    local code_blocks = {}
    for var, value in vars_section:gmatch("([%w_]+):%s*([^\n]+)") do
      table.insert(code_blocks, "<% s." .. var .. " = " .. value .. "; %>")
    end
    if #code_blocks > 0 then
      text = table.concat(code_blocks, "\n") .. "\n" .. rest
    else
      text = rest
    end
  end

  -- Convert {var} to <%= s.var %>
  text = M.convert_text_to_snowman(text)

  return text
end

function M.convert_text_to_snowman(chapbook_text)
  -- Convert {var} to <%= s.var %>
  return chapbook_text:gsub("{([%w_]+)}", function(var)
    return "<%= s." .. var .. " %>"
  end)
end

function M.convert_modifier_to_snowman(chapbook_text)
  local text = chapbook_text

  -- Convert [if cond]body[continue] to <% if (cond) { %>body<% } %>
  text = text:gsub("%[if%s+(.-)%](.-)%[continue%]", function(cond, body)
    -- Add s. prefix to variables
    cond = cond:gsub("([%w_]+)", function(word)
      if word:match("^%d") or word == "if" or word == "else" then
        return word
      end
      return "s." .. word
    end)
    return "<% if (" .. cond .. ") { %>" .. body .. "<% } %>"
  end)

  return text
end

function M.convert_var_to_snowman(chapbook_text)
  -- Convert var: value to s.var = value
  return chapbook_text:gsub("([%w_]+):%s*(.+)", function(var, value)
    return "s." .. var .. " = " .. value
  end)
end

-- Features directly converted to Harlowe
local HARLOWE_CONVERTED = {
  {pattern = "([%w_]+):%s*", feature = "vars-section", converts_to = "(set: ...)"},
  {pattern = "{([%w_]+)}", feature = "variable", converts_to = "$var"},
  {pattern = "%[if%s+", feature = "if", converts_to = "(if: ...)"},
}

-- Features directly converted to SugarCube
local SUGARCUBE_CONVERTED = {
  {pattern = "([%w_]+):%s*", feature = "vars-section", converts_to = "<<set>>"},
  {pattern = "{([%w_]+)}", feature = "variable", converts_to = "$var"},
}

-- Features incompatible with SugarCube
local SUGARCUBE_INCOMPATIBLE = {
  {pattern = "%[after%s+", feature = "after", description = "Timed delays need <<timed>> macro"},
  {pattern = "%[align%s+", feature = "align", description = "Alignment needs CSS"},
}

-- Features directly converted to Snowman
local SNOWMAN_CONVERTED = {
  {pattern = "([%w_]+):%s*", feature = "vars-section", converts_to = "<% s.var = value %>"},
  {pattern = "{([%w_]+)}", feature = "variable", converts_to = "<%= s.var %>"},
}

-- Features incompatible with Snowman
local SNOWMAN_INCOMPATIBLE = {
  {pattern = "%[after%s+", feature = "after", description = "Timed delays require custom JS"},
  {pattern = "{cycling%s+link", feature = "cycling-link", description = "Requires custom JS"},
  {pattern = "{dropdown", feature = "dropdown", description = "Requires custom JS"},
  {pattern = "{text%s+input", feature = "text-input", description = "Requires custom JS"},
}

--- Convert Chapbook to Harlowe with detailed report
-- @param parsed_story table The parsed Chapbook story
-- @return string, Report The converted content and conversion report
function M.to_harlowe_with_report(parsed_story)
  local report = Report.new("chapbook", "harlowe")
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
    for _, approx in ipairs(HARLOWE_APPROXIMATIONS) do
      if content:match(approx.pattern) then
        for _ in content:gmatch(approx.pattern) do
          report:add_approximated(
            approx.feature,
            passage.name,
            approx.pattern,
            approx.approximation,
            {notes = approx.description}
          )
        end
      end
    end
  end

  local result = M.to_harlowe(parsed_story)
  return result, report
end

--- Convert Chapbook to SugarCube with detailed report
-- @param parsed_story table The parsed Chapbook story
-- @return string, Report The converted content and conversion report
function M.to_sugarcube_with_report(parsed_story)
  local report = Report.new("chapbook", "sugarcube")
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

--- Convert Chapbook to Snowman with detailed report
-- @param parsed_story table The parsed Chapbook story
-- @return string, Report The converted content and conversion report
function M.to_snowman_with_report(parsed_story)
  local report = Report.new("chapbook", "snowman")
  report:set_passage_count(#parsed_story.passages)

  for _, passage in ipairs(parsed_story.passages) do
    local content = passage.content

    -- Track converted features
    for _, conv in ipairs(SNOWMAN_CONVERTED) do
      if content:match(conv.pattern) then
        for _ in content:gmatch(conv.pattern) do
          report:add_converted(conv.feature, passage.name, {
            original = conv.pattern,
            result = conv.converts_to
          })
        end
      end
    end

    -- Track incompatible features
    for _, incomp in ipairs(SNOWMAN_INCOMPATIBLE) do
      if content:match(incomp.pattern) then
        for _ in content:gmatch(incomp.pattern) do
          report:add_lost(incomp.feature, passage.name, incomp.description, {})
        end
      end
    end
  end

  local result = M.to_snowman(parsed_story)
  return result, report
end

return M
