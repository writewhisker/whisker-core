--- SugarCube to WLS Importer
-- Converts SugarCube (Twine) stories to WLS format
-- @module whisker.import.sugarcube
-- @author Whisker Core Team
-- @license MIT

local IImporter = require("whisker.import.importer")

local SugarCubeImporter = {}
setmetatable(SugarCubeImporter, { __index = IImporter })

--- SugarCube syntax conversion patterns
SugarCubeImporter.conversions = {
  -- Variables: <<set $var = value>> -> @{var = value}
  set_var = {
    pattern = "<<set%s+%$(%w+)%s*=%s*(.-)>>",
    replace = function(name, value)
      return "@{" .. name .. " = " .. SugarCubeImporter._convert_value(value) .. "}"
    end
  },

  -- Variables: <<set $var to value>> -> @{var = value}
  set_var_to = {
    pattern = "<<set%s+%$(%w+)%s+to%s+(.-)>>",
    replace = function(name, value)
      return "@{" .. name .. " = " .. SugarCubeImporter._convert_value(value) .. "}"
    end
  },

  -- If: <<if $condition>>content<</if>> -> {condition}content{/}
  if_block = {
    pattern = "<<if%s+(.-)>>(.-)<</if>>",
    replace = function(condition, content)
      return "{" .. SugarCubeImporter._convert_condition(condition) .. "}" ..
             content .. "{/}"
    end
  },

  -- Elseif: <<elseif $condition>>
  elseif_tag = {
    pattern = "<<elseif%s+(.-)>>",
    replace = function(condition)
      return "{elif " .. SugarCubeImporter._convert_condition(condition) .. "}"
    end
  },

  -- Else: <<else>>
  else_tag = {
    pattern = "<<else>>",
    replace = "{else}"
  },

  -- Links: <<link "text" "passage">> -> + [text] -> passage
  link_full = {
    pattern = '<<link%s+"(.-)"%s+"(.-)".->>',
    replace = function(text, passage)
      return "+ [" .. text .. "] -> " .. passage
    end
  },

  -- Links: <<link [[text|passage]]>> -> + [text] -> passage
  link_bracket = {
    pattern = "<<link%s+%[%[(.-)%|(.-)%]%]>>",
    replace = function(text, passage)
      return "+ [" .. text .. "] -> " .. passage
    end
  },

  -- Links: <<link "text">><<goto "passage">><</link>> -> + [text] -> passage
  link_goto = {
    pattern = '<<link%s+"(.-)">>.-<<goto%s+"(.-)">>.-<</link>>',
    replace = function(text, passage)
      return "+ [" .. text .. "] -> " .. passage
    end
  },

  -- Goto: <<goto "passage">> -> -> passage
  goto_passage = {
    pattern = '<<goto%s+"(.-)">>',
    replace = function(passage)
      return "-> " .. passage
    end
  },

  -- Include: <<include "passage">> -> -> passage ->
  include_passage = {
    pattern = '<<include%s+"(.-)">>',
    replace = function(passage)
      return "-> " .. passage .. " ->"
    end
  },

  -- Print: <<print $var>> -> ${var}
  print_var = {
    pattern = "<<print%s+%$(%w+)>>",
    replace = function(name)
      return "${" .. name .. "}"
    end
  },

  -- Print expression: <<= expr>> -> ${expr}
  print_expr = {
    pattern = "<<=(.-)>>",
    replace = function(expr)
      return "${" .. SugarCubeImporter._convert_value(expr:match("^%s*(.-)%s*$")) .. "}"
    end
  },

  -- Timed: <<timed delay>>content<</timed>> -> @delay(delay) content
  timed_block = {
    pattern = "<<timed%s+(.-)>>(.-)<</timed>>",
    replace = function(delay, content)
      return "@delay(" .. delay .. ") " .. content
    end
  },

  -- Silently: <<silently>>content<</silently>> -> @{...} (silent execution)
  silently_block = {
    pattern = "<<silently>>(.-)<</silently>>",
    replace = function(content)
      -- Extract and convert set statements
      local result = ""
      for set_stmt in content:gmatch("<<set%s+(.-)>>") do
        result = result .. "@{" .. set_stmt:gsub("%$", "") .. "}\n"
      end
      return result
    end
  },

  -- Nobr: <<nobr>>content<</nobr>> -> content (remove newlines)
  nobr_block = {
    pattern = "<<nobr>>(.-)<</nobr>>",
    replace = function(content)
      return content:gsub("\n", " "):gsub("%s+", " ")
    end
  },

  -- Simple links: [[text|passage]] -> + [text] -> passage
  link_pipe = {
    pattern = "%[%[(.-)%|(.-)%]%]",
    replace = function(text, passage)
      return "+ [" .. text:match("^%s*(.-)%s*$") .. "] -> " .. passage:match("^%s*(.-)%s*$")
    end
  },

  -- Simple links: [[passage]] -> + [passage] -> passage
  link_simple = {
    pattern = "%[%[([^%[%]|]+)%]%]",
    replace = function(passage)
      local trimmed = passage:match("^%s*(.-)%s*$")
      return "+ [" .. trimmed .. "] -> " .. trimmed
    end
  },
}

--- Convert a SugarCube value to WLS
-- @param value string The SugarCube value
-- @return string The WLS value
function SugarCubeImporter._convert_value(value)
  if not value then return "nil" end

  value = value:match("^%s*(.-)%s*$")  -- Trim

  -- Boolean
  if value == "true" or value == "false" then
    return value
  end

  -- Number
  if tonumber(value) then
    return value
  end

  -- String (quoted)
  if value:match('^".-"$') or value:match("^'.-'$") then
    return value
  end

  -- Variable reference $var -> var
  if value:match("^%$%w+$") then
    return value:sub(2)
  end

  -- Variable in expression
  value = value:gsub("%$(%w+)", "%1")

  return value
end

--- Convert a SugarCube condition to WLS
-- @param condition string The SugarCube condition
-- @return string The WLS condition
function SugarCubeImporter._convert_condition(condition)
  if not condition then return "true" end

  condition = condition:match("^%s*(.-)%s*$")  -- Trim

  -- Replace $var with var
  condition = condition:gsub("%$(%w+)", "%1")

  -- Replace === with ==
  condition = condition:gsub("===", "==")

  -- Replace !== with !=
  condition = condition:gsub("!==", "!=")

  -- Replace "eq" with ==
  condition = condition:gsub("%s+eq%s+", " == ")

  -- Replace "neq"/"ne" with !=
  condition = condition:gsub("%s+neq%s+", " != ")
  condition = condition:gsub("%s+ne%s+", " != ")

  -- Replace "gt" with >
  condition = condition:gsub("%s+gt%s+", " > ")

  -- Replace "gte"/"ge" with >=
  condition = condition:gsub("%s+gte%s+", " >= ")
  condition = condition:gsub("%s+ge%s+", " >= ")

  -- Replace "lt" with <
  condition = condition:gsub("%s+lt%s+", " < ")

  -- Replace "lte"/"le" with <=
  condition = condition:gsub("%s+lte%s+", " <= ")
  condition = condition:gsub("%s+le%s+", " <= ")

  -- && and || are already compatible
  -- "and" and "or" are already compatible

  return condition
end

--- Create a new SugarCube importer
-- @param container table DI container (optional)
-- @return SugarCubeImporter
function SugarCubeImporter.new(container)
  local self = setmetatable({}, { __index = SugarCubeImporter })
  self._container = container

  -- Get factories if available
  if container then
    if container:has("story_factory") then
      self._story_factory = container:resolve("story_factory")
    end
    if container:has("passage_factory") then
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

--- Check if source can be imported
-- @param source string Source content
-- @param options table Import options
-- @return boolean
-- @return string|nil Error message
function SugarCubeImporter:can_import(source, options)
  if type(source) ~= "string" or source == "" then
    return false, "Empty or invalid source"
  end

  -- Must have SugarCube-like syntax
  local has_sugarcube = source:find("<<set") or
                        source:find("<<if") or
                        source:find("<<link") or
                        source:find("<<goto")

  if not has_sugarcube then
    return false, "No SugarCube syntax detected"
  end

  return true
end

--- Detect if source is SugarCube format
-- @param source string Source content
-- @return boolean
function SugarCubeImporter:detect(source)
  local can, _ = self:can_import(source)
  return can
end

--- Import SugarCube source to WLS Story
-- @param source string Source content
-- @param options table Import options
-- @return Story
function SugarCubeImporter:import(source, options)
  options = options or {}

  -- Convert SugarCube syntax to WLS
  local wls_content = self:convert_to_wls(source)

  -- Parse WLS content to story
  local story = self:parse_wls_to_story(wls_content)

  return story
end

--- Convert SugarCube source to WLS format
-- @param source string SugarCube source
-- @return string WLS formatted content
function SugarCubeImporter:convert_to_wls(source)
  local result = source

  -- Apply conversions in order (order matters for nested structures)
  local ordered_conversions = {
    "silently_block",
    "nobr_block",
    "timed_block",
    "if_block",
    "elseif_tag",
    "else_tag",
    "set_var",
    "set_var_to",
    "link_full",
    "link_bracket",
    "link_goto",
    "goto_passage",
    "include_passage",
    "print_var",
    "print_expr",
    "link_pipe",
    "link_simple",
  }

  for _, name in ipairs(ordered_conversions) do
    local conv = self.conversions[name]
    if conv then
      if type(conv.replace) == "function" then
        result = result:gsub(conv.pattern, conv.replace)
      else
        result = result:gsub(conv.pattern, conv.replace)
      end
    end
  end

  -- Clean up remaining << >> tags
  result = result:gsub("<<[^>]+>>", "")

  return result
end

--- Parse WLS content into a Story object
-- @param wls_content string WLS formatted content
-- @return Story
function SugarCubeImporter:parse_wls_to_story(wls_content)
  -- Use the WLS parser if available
  local ok, parser = pcall(require, "whisker.parser")
  if ok and parser.parse then
    local result = parser.parse(wls_content)
    if result and result.story then
      return result.story
    end
  end

  -- Fallback: manual parsing
  local story = self._story_factory and self._story_factory:create({}) or {
    metadata = {},
    variables = {},
    passages = {},
  }

  local current_passage = nil
  local current_content = {}

  for line in wls_content:gmatch("[^\n]+") do
    -- Check for passage header
    local passage_name = line:match("^::%s*(.+)$")
    if passage_name then
      -- Save previous passage
      if current_passage then
        current_passage.content = table.concat(current_content, "\n")
        story.passages[current_passage.id] = current_passage
      end

      -- Start new passage
      passage_name = passage_name:match("^%s*(.-)%s*$")
      current_passage = {
        id = passage_name:gsub("%s+", "_"):lower(),
        name = passage_name,
        content = "",
        choices = {},
      }
      current_content = {}

      if not story.start_passage then
        story.start_passage = current_passage.id
      end
    elseif current_passage then
      table.insert(current_content, line)
    end
  end

  -- Save last passage
  if current_passage then
    current_passage.content = table.concat(current_content, "\n")
    story.passages[current_passage.id] = current_passage
  end

  return story
end

--- Get importer metadata
-- @return table
function SugarCubeImporter:metadata()
  return {
    name = "sugarcube",
    version = "2.36.1",
    description = "Import SugarCube (Twine) stories to WLS format",
    extensions = { ".html", ".htm" },
    mime_types = { "text/html" },
    source_format = "SugarCube",
    target_format = "WLS 1.0",
  }
end

return SugarCubeImporter
