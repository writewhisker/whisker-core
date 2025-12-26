-- Harlowe Format Converter
-- Converts Harlowe-format stories to other Twine formats

local M = {}

-- Require the report module
local Report = require("whisker.format.converters.report")

-- Convert Harlowe to SugarCube
function M.to_sugarcube(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    -- Build passage header
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    -- Convert content
    local content = passage.content

    -- Convert arrays (a: ...) -> [...] - do this BEFORE set conversion
    content = content:gsub("%(%s*a:%s*(.-)%)", function(items)
      return "[" .. items .. "]"
    end)

    -- Convert datamaps (dm: ...) -> {...} - do this BEFORE set conversion
    content = content:gsub("%(%s*dm:%s*(.-)%)", function(pairs)
      return "{" .. pairs .. "}"
    end)

    -- Convert (set: $var to value) -> <<set $var to value>>
    -- Handle 'it' keyword replacement
    content = content:gsub("%(%s*set:%s*(%$[%w_]+)%s+to%s+(.-)%)", function(var, value)
      -- Replace 'it' with the variable name
      value = value:gsub("%s*it%s*", " " .. var .. " ")
      return "<<set " .. var .. " to " .. value .. ">>"
    end)

    -- Convert (if: cond)[body] -> <<if cond>>body<</if>>
    content = content:gsub("%(%s*if:%s*(.-)%)%[(.-)%]", function(cond, body)
      return "<<if " .. cond .. ">>" .. body .. "<</if>>"
    end)

    -- Convert (print: $var) -> <<print $var>>
    content = content:gsub("%(%s*print:%s*(.-)%)", function(expr)
      return "<<print " .. expr .. ">>"
    end)

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

-- Convert Harlowe to Chapbook
function M.to_chapbook(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    -- Build passage header
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = passage.content

    -- Extract variable assignments and put them in vars section
    local vars = {}
    content = content:gsub("%(%s*set:%s*%$([%w_]+)%s+to%s+(.-)%)", function(var, value)
      table.insert(vars, var .. ": " .. value)
      return "" -- Remove from content
    end)

    -- If we have vars, add them at the top
    if #vars > 0 then
      table.insert(result, table.concat(vars, "\n"))
      table.insert(result, "--")
    end

    -- Convert (dropdown: ...) to {dropdown menu for: 'var', choices: [...]}
    -- Harlowe: (dropdown: bind $var, "opt1", "opt2", "opt3")
    content = content:gsub("%(%s*dropdown:%s*bind%s*%$([%w_]+)%s*,%s*(.-)%)", function(var, options)
      -- Parse options and format for Chapbook
      local choices = {}
      for opt in options:gmatch('"([^"]*)"') do
        table.insert(choices, "'" .. opt .. "'")
      end
      return "{dropdown menu for: '" .. var .. "', choices: [" .. table.concat(choices, ", ") .. "]}"
    end)

    -- Convert (text-input: ...) to {text input for: 'var'}
    -- Harlowe: (input: bind $var) or (text-input: bind $var)
    content = content:gsub("%(%s*input:%s*bind%s*%$([%w_]+).-%)%s*", function(var)
      return "{text input for: '" .. var .. "'}"
    end)
    content = content:gsub("%(%s*text%-input:%s*bind%s*%$([%w_]+).-%)%s*", function(var)
      return "{text input for: '" .. var .. "'}"
    end)

    -- Convert (cycling-link: ...) to {cycling link for: 'var', choices: [...]}
    -- Harlowe: (cycling-link: bind $var, "opt1", "opt2", "opt3")
    content = content:gsub("%(%s*cycling%-link:%s*bind%s*%$([%w_]+)%s*,%s*(.-)%)", function(var, options)
      local choices = {}
      for opt in options:gmatch('"([^"]*)"') do
        table.insert(choices, "'" .. opt .. "'")
      end
      return "{cycling link for: '" .. var .. "', choices: [" .. table.concat(choices, ", ") .. "]}"
    end)

    -- Convert (link-repeat: "text")[body] to {cycling link} (approximate)
    -- Harlowe: (link-repeat: "Click me")[New text appears]
    content = content:gsub("%(%s*link%-repeat:%s*\"([^\"]+)\"%s*%)%[(.-)%]", function(linkText, body)
      -- Use reveal link as closest approximation
      return "{reveal link: '" .. linkText .. "', text: '" .. body:gsub("'", "\\'") .. "'}"
    end)

    -- Convert (transition: "name") to [note: transition] (CSS hint)
    -- Chapbook doesn't have built-in transitions, add as note
    content = content:gsub("%(%s*transition:%s*\"([^\"]+)\"%s*%)", function(transitionName)
      return "[note]Add CSS transition: " .. transitionName .. "[continue]"
    end)

    -- Convert $var to {var} (Chapbook doesn't use $)
    content = content:gsub("%$([%w_]+)", function(var)
      return "{" .. var .. "}"
    end)

    -- Convert (if: cond)[body] -> [if cond]body[continued]
    content = content:gsub("%(%s*if:%s*(.-)%)%[(.-)%]", function(cond, body)
      -- Remove $ from condition
      cond = cond:gsub("%$([%w_]+)", "%1")
      return "[if " .. cond .. "]\n" .. body .. "\n[continued]"
    end)

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

-- Convert Harlowe to Snowman
function M.to_snowman(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    -- Build passage header
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)

    local content = passage.content

    -- Convert (set: $var to value) -> <% s.var = value; %>
    content = content:gsub("%(%s*set:%s*%$([%w_]+)%s+to%s+(.-)%)", function(var, value)
      return "<% s." .. var .. " = " .. value .. "; %>"
    end)

    -- Convert $var to <%= s.var %>
    content = content:gsub("%$([%w_]+)", function(var)
      return "<%= s." .. var .. " %>"
    end)

    -- Convert (if: cond)[body] -> <% if (cond) { %>body<% } %>
    content = content:gsub("%(%s*if:%s*(.-)%)%[(.-)%]", function(cond, body)
      -- Convert $ to s. in condition
      cond = cond:gsub("%$([%w_]+)", "s.%1")
      return "<% if (" .. cond .. ") { %>" .. body .. "<% } %>"
    end)

    -- Convert [[Text->Target]] to [Text](Target)
    content = content:gsub("%[%[(.-)%->(.-)%]%]", function(text, target)
      return "[" .. text .. "](" .. target .. ")"
    end)

    -- Convert [[Target]] to [Target](Target)
    content = content:gsub("%[%[(.-)%]%]", function(target)
      return "[" .. target .. "](" .. target .. ")"
    end)

    table.insert(result, content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

-- Features that are automatically converted to Chapbook equivalents
local CHAPBOOK_CONVERTED = {
  {
    pattern = "%(dropdown:",
    feature = "dropdown",
    converts_to = "{dropdown menu for: 'var', choices: [...]}",
    severity = "info"
  },
  {
    pattern = "%(input:",
    feature = "input",
    converts_to = "{text input for: 'var'}",
    severity = "info"
  },
  {
    pattern = "%(text%-input:",
    feature = "text-input",
    converts_to = "{text input for: 'var'}",
    severity = "info"
  },
  {
    pattern = "%(cycling%-link:",
    feature = "cycling-link",
    converts_to = "{cycling link for: 'var', choices: [...]}",
    severity = "info"
  },
  {
    pattern = "%(link%-repeat:",
    feature = "link-repeat",
    converts_to = "{reveal link: 'text', text: '...'}",
    severity = "info"
  },
  {
    pattern = "%(transition:",
    feature = "transition",
    converts_to = "[note]Add CSS transition: name[continue]",
    severity = "info"
  },
}

-- Features that cannot be converted to Chapbook (no equivalent)
local CHAPBOOK_INCOMPATIBLE = {
  {
    pattern = "%(live:",
    feature = "live",
    description = "live macro (real-time updates) not supported in Chapbook",
    severity = "warning"
  },
  {
    pattern = "%(enchant:",
    feature = "enchant",
    description = "enchant macro (DOM manipulation) not available in Chapbook",
    severity = "warning"
  },
  {
    pattern = "%(click:",
    feature = "click",
    description = "click macro not directly available in Chapbook",
    severity = "warning"
  },
  {
    pattern = "%(mouseover:",
    feature = "mouseover",
    description = "mouseover interactions not available in Chapbook",
    severity = "warning"
  },
  {
    pattern = "%(alert:",
    feature = "alert",
    description = "alert macro needs JavaScript in Chapbook",
    severity = "info"
  },
}

--- Convert Harlowe to Chapbook with warnings about incompatible features
-- @param parsed_story table The parsed Harlowe story
-- @return string, table The converted content and list of warnings
function M.to_chapbook_with_warnings(parsed_story)
  local result = M.to_chapbook(parsed_story)
  local warnings = {}

  -- Check each passage for incompatible features
  for _, passage in ipairs(parsed_story.passages) do
    for _, incompatible in ipairs(CHAPBOOK_INCOMPATIBLE) do
      if passage.content:match(incompatible.pattern) then
        table.insert(warnings, {
          passage = passage.name,
          feature = incompatible.feature,
          description = incompatible.description,
          severity = incompatible.severity
        })
      end
    end
  end

  return result, warnings
end

--- Get list of features that may have lossy conversion to Chapbook
-- @return table List of incompatible feature definitions
function M.get_chapbook_incompatible_features()
  return CHAPBOOK_INCOMPATIBLE
end

--- Get list of features that are automatically converted to Chapbook equivalents
-- @return table List of converted feature definitions
function M.get_chapbook_converted_features()
  return CHAPBOOK_CONVERTED
end

-- Reconstruct Twee notation from parsed story
function M.reconstruct_twee(parsed_story)
  local result = {}

  for _, passage in ipairs(parsed_story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)
    table.insert(result, passage.content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

-- Additional conversion functions
function M.convert_macro_to_sugarcube(harlowe_text)
  -- Convert individual Harlowe macros to SugarCube
  local text = harlowe_text

  -- Convert arrays (a: ...) -> [...] - do this BEFORE set conversion
  text = text:gsub("%(%s*a:%s*(.-)%)", function(items)
    return "[" .. items .. "]"
  end)

  -- Convert datamaps (dm: ...) -> {...} - do this BEFORE set conversion
  text = text:gsub("%(%s*dm:%s*(.-)%)", function(pairs)
    return "{" .. pairs .. "}"
  end)

  -- Convert (set: $var to value) -> <<set $var to value>>
  -- Handle 'it' keyword replacement
  text = text:gsub("%(%s*set:%s*(%$[%w_]+)%s+to%s+(.-)%)", function(var, value)
    -- Replace 'it' with the variable name
    value = value:gsub("%s*it%s*", " " .. var .. " ")
    return "<<set " .. var .. " to " .. value .. ">>"
  end)

  text = text:gsub("%(%s*if:%s*(.-)%)%[(.-)%]", "<<if %1>>%2<</if>>")
  text = text:gsub("%(%s*print:%s*(.-)%)", "<<print %1>>")

  return text
end

function M.convert_macro_to_chapbook(harlowe_text)
  local text = harlowe_text

  -- Convert arrays (a: ...) -> [...] - do this BEFORE other conversions
  text = text:gsub("%(%s*a:%s*(.-)%)", function(items)
    return "[" .. items .. "]"
  end)

  -- Convert datamaps (dm: ...) -> {...} - do this BEFORE other conversions
  text = text:gsub("%(%s*dm:%s*(.-)%)", function(pairs)
    return "{" .. pairs .. "}"
  end)

  -- Convert (if: cond)[body] to [if cond]body
  text = text:gsub("%(%s*if:%s*(.-)%)%[(.-)%]", function(cond, body)
    -- Remove $ from condition
    cond = cond:gsub("%$([%w_]+)", "%1")
    return "[if " .. cond .. "]" .. body
  end)

  -- Remove $ from variables
  text = text:gsub("%$([%w_]+)", "%1")

  return text
end

function M.convert_to_snowman_code(harlowe_text)
  local text = harlowe_text

  -- Convert (set: $var to val) to s.var = val
  text = text:gsub("%(%s*set:%s*%$([%w_]+)%s+to%s+(.-)%)", "s.%1 = %2")

  return text
end

function M.convert_to_snowman_passage(harlowe_text)
  local text = harlowe_text

  -- Wrap variable declarations in code blocks
  text = text:gsub("%(%s*set:%s*%$([%w_]+)%s+to%s+(.-)%)", function(var, value)
    return "<% s." .. var .. " = " .. value .. "; %>"
  end)

  return text
end

function M.convert_text_to_snowman(harlowe_text)
  -- Convert interpolation
  return harlowe_text:gsub("%$([%w_]+)", function(var)
    return "<%= s." .. var .. " %>"
  end)
end

function M.convert_link_to_snowman(harlowe_text)
  return harlowe_text:gsub("%[%[(.-)%->(.-)%]%]", "[%1](%2)")
end

function M.convert_link_to_sugarcube(harlowe_text)
  -- Harlowe [[Text->Target]] to SugarCube [[Text|Target]]
  return harlowe_text:gsub("%[%[(.-)%->(.-)%]%]", "[[%1|%2]]")
end

function M.convert_function_to_sugarcube(harlowe_text)
  -- Convert Harlowe functions
  return harlowe_text:gsub("%(%s*random:%s*(.-)%)", "random(%1)")
end

function M.convert_datastructure_to_chapbook(harlowe_text)
  local text = harlowe_text

  -- Convert (a: ...) to [...]
  text = text:gsub("%(%s*a:%s*(.-)%)", function(items)
    return "[" .. items .. "]"
  end)

  -- Convert (dm: "key", value, "key2", value2) to {key: value, key2: value2}
  text = text:gsub("%(%s*dm:%s*(.-)%)", function(pairs)
    -- Parse pairs and convert to object notation
    local result = {}
    local items = {}

    -- Simple parsing: split by commas (not perfect but works for basic cases)
    for item in (pairs .. ","):gmatch("([^,]+),") do
      table.insert(items, item:match("^%s*(.-)%s*$"))  -- trim whitespace
    end

    -- Pair up keys and values
    for i = 1, #items, 2 do
      if items[i] and items[i+1] then
        local key = items[i]:gsub('["\']', '')  -- Remove quotes from key
        local value = items[i+1]
        table.insert(result, key .. ": " .. value)
      end
    end

    return "{" .. table.concat(result, ", ") .. "}"
  end)

  return text
end

function M.convert_text_to_chapbook(harlowe_text)
  -- Remove $ from variables
  return harlowe_text:gsub("%$([%w_]+)", "{%1}")
end

function M.convert_to_chapbook_passage(harlowe_text)
  local text = harlowe_text
  local vars = {}
  local content_lines = {}

  -- Extract variable assignments for vars section
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local var_match = line:match("%(%s*set:%s*%$([%w_]+)%s+to%s+(.-)%)")
    if var_match then
      local var, value = line:match("%(%s*set:%s*%$([%w_]+)%s+to%s+(.-)%)")
      table.insert(vars, var .. ": " .. value)
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
  -- Remove $ from variables
  content = content:gsub("%$([%w_]+)", "{%1}")

  table.insert(result, content)

  return table.concat(result, "\n")
end

-- Features that are directly converted to SugarCube (1:1 mapping)
local SUGARCUBE_CONVERTED = {
  {pattern = "%(set:", feature = "set", converts_to = "<<set>>"},
  {pattern = "%(if:", feature = "if", converts_to = "<<if>>"},
  {pattern = "%(print:", feature = "print", converts_to = "<<print>>"},
  {pattern = "%(a:", feature = "array", converts_to = "[...]"},
  {pattern = "%(dm:", feature = "datamap", converts_to = "{...}"},
  {pattern = "%[%[.-%->", feature = "link", converts_to = "[[|]]"},
}

-- Features that are approximated when converting to SugarCube
local SUGARCUBE_APPROXIMATED = {
  {
    pattern = "%(live:",
    feature = "live",
    converts_to = "<<repeat>>",
    notes = "SugarCube repeat is similar but not identical to Harlowe live"
  },
  {
    pattern = "%(dropdown:",
    feature = "dropdown",
    converts_to = "<<listbox>>",
    notes = "Requires SugarCube listbox macro"
  },
  {
    pattern = "%(cycling%-link:",
    feature = "cycling-link",
    converts_to = "<<cycle>>",
    notes = "Requires SugarCube cycle macro"
  },
}

-- Features incompatible with SugarCube
local SUGARCUBE_INCOMPATIBLE = {
  {
    pattern = "%(enchant:",
    feature = "enchant",
    description = "Harlowe enchant has no direct SugarCube equivalent"
  },
  {
    pattern = "%(transition:",
    feature = "transition",
    description = "Harlowe transitions need CSS implementation in SugarCube"
  },
}

-- Features directly converted to Snowman
local SNOWMAN_CONVERTED = {
  {pattern = "%(set:", feature = "set", converts_to = "<% s.var = value %>"},
  {pattern = "%$[%w_]+", feature = "variable", converts_to = "<%= s.var %>"},
  {pattern = "%[%[.-%->", feature = "link", converts_to = "[text](target)"},
}

-- Features approximated in Snowman
local SNOWMAN_APPROXIMATED = {
  {
    pattern = "%(if:",
    feature = "if",
    converts_to = "<% if () { %> ... <% } %>",
    notes = "Condition syntax differs"
  },
}

-- Features incompatible with Snowman
local SNOWMAN_INCOMPATIBLE = {
  {
    pattern = "%(live:",
    feature = "live",
    description = "Snowman has no built-in live update support"
  },
  {
    pattern = "%(enchant:",
    feature = "enchant",
    description = "Snowman has no enchant equivalent"
  },
  {
    pattern = "%(dropdown:",
    feature = "dropdown",
    description = "Requires custom JavaScript in Snowman"
  },
  {
    pattern = "%(cycling%-link:",
    feature = "cycling-link",
    description = "Requires custom JavaScript in Snowman"
  },
  {
    pattern = "%(click:",
    feature = "click",
    description = "Requires custom JavaScript in Snowman"
  },
  {
    pattern = "%(mouseover:",
    feature = "mouseover",
    description = "Requires custom JavaScript in Snowman"
  },
}

--- Convert Harlowe to Chapbook with detailed report
-- @param parsed_story table The parsed Harlowe story
-- @return string, Report The converted content and conversion report
function M.to_chapbook_with_report(parsed_story)
  local report = Report.new("harlowe", "chapbook")
  report:set_passage_count(#parsed_story.passages)

  -- Track features as we convert
  for _, passage in ipairs(parsed_story.passages) do
    local content = passage.content

    -- Track converted features
    for _, conv in ipairs(CHAPBOOK_CONVERTED) do
      if content:match(conv.pattern) then
        -- Count occurrences
        local count = 0
        for _ in content:gmatch(conv.pattern) do
          count = count + 1
        end
        for _ = 1, count do
          report:add_converted(conv.feature, passage.name, {
            original = conv.pattern,
            result = conv.converts_to
          })
        end
      end
    end

    -- Track set/if/print as converted
    if content:match("%(set:") then
      for _ in content:gmatch("%(set:") do
        report:add_converted("set", passage.name, {
          original = "(set: ...)",
          result = "vars section"
        })
      end
    end

    if content:match("%(if:") then
      for _ in content:gmatch("%(if:") do
        report:add_converted("if", passage.name, {
          original = "(if: ...)",
          result = "[if ...]"
        })
      end
    end

    -- Track incompatible/lost features
    for _, incomp in ipairs(CHAPBOOK_INCOMPATIBLE) do
      if content:match(incomp.pattern) then
        for _ in content:gmatch(incomp.pattern) do
          report:add_lost(incomp.feature, passage.name, incomp.description, {
            severity = incomp.severity or "warning"
          })
        end
      end
    end
  end

  -- Perform the actual conversion
  local result = M.to_chapbook(parsed_story)

  return result, report
end

--- Convert Harlowe to SugarCube with detailed report
-- @param parsed_story table The parsed Harlowe story
-- @return string, Report The converted content and conversion report
function M.to_sugarcube_with_report(parsed_story)
  local report = Report.new("harlowe", "sugarcube")
  report:set_passage_count(#parsed_story.passages)

  for _, passage in ipairs(parsed_story.passages) do
    local content = passage.content

    -- Track directly converted features
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

--- Convert Harlowe to Snowman with detailed report
-- @param parsed_story table The parsed Harlowe story
-- @return string, Report The converted content and conversion report
function M.to_snowman_with_report(parsed_story)
  local report = Report.new("harlowe", "snowman")
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

    -- Track approximated features
    for _, approx in ipairs(SNOWMAN_APPROXIMATED) do
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
