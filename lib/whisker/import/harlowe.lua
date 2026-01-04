--- Harlowe to WLS Importer
-- Converts Harlowe (Twine) stories to WLS format
-- @module whisker.import.harlowe
-- @author Whisker Core Team
-- @license MIT

local IImporter = require("whisker.import.importer")

local HarloweImporter = {}
setmetatable(HarloweImporter, { __index = IImporter })

--- Harlowe syntax conversion patterns
HarloweImporter.conversions = {
  -- Variables: (set: $var to value) -> @{var = value}
  set_var = {
    pattern = "%(set:%s*%$(%w+)%s+to%s+(.-)%)",
    replace = function(name, value)
      return "@{" .. name .. " = " .. HarloweImporter._convert_value(value) .. "}"
    end
  },

  -- Conditionals: (if: $var)[content] -> {var}content{/}
  if_start = {
    pattern = "%(if:%s*(.-)%)%[",
    replace = function(condition)
      return "{" .. HarloweImporter._convert_condition(condition) .. "}"
    end
  },

  -- Unless: (unless: $var)[content] -> {not var}content{/}
  unless_start = {
    pattern = "%(unless:%s*(.-)%)%[",
    replace = function(condition)
      return "{not " .. HarloweImporter._convert_condition(condition) .. "}"
    end
  },

  -- Else-if: (else-if: $var)[content]
  elseif_block = {
    pattern = "%]%(else%-if:%s*(.-)%)%[",
    replace = function(condition)
      return "{elif " .. HarloweImporter._convert_condition(condition) .. "}"
    end
  },

  -- Else: (else:)[content]
  else_block = {
    pattern = "%]%(else:%s*%)%[",
    replace = "{else}"
  },

  -- End conditional: ]
  if_end = {
    pattern = "%]",
    replace = "{/}"
  },

  -- Links: [[text->passage]] -> + [text] -> passage
  link_arrow = {
    pattern = "%[%[(.-)%->(.-)%]%]",
    replace = function(text, passage)
      return "+ [" .. text:match("^%s*(.-)%s*$") .. "] -> " .. passage:match("^%s*(.-)%s*$")
    end
  },

  -- Links: [[passage<-text]] -> + [text] -> passage
  link_arrow_rev = {
    pattern = "%[%[(.-)%<%-(.-)%]%]",
    replace = function(passage, text)
      return "+ [" .. text:match("^%s*(.-)%s*$") .. "] -> " .. passage:match("^%s*(.-)%s*$")
    end
  },

  -- Simple links: [[passage]] -> + [passage] -> passage
  link_simple = {
    pattern = "%[%[([^%[%]<>%-]+)%]%]",
    replace = function(passage)
      local trimmed = passage:match("^%s*(.-)%s*$")
      return "+ [" .. trimmed .. "] -> " .. trimmed
    end
  },

  -- Print: (print: $var) -> ${var}
  print_var = {
    pattern = "%(print:%s*%$(%w+)%s*%)",
    replace = function(name)
      return "${" .. name .. "}"
    end
  },

  -- Go-to: (go-to: "passage") -> -> passage
  goto_passage = {
    pattern = '%(go%-to:%s*"(.-)"%s*%)',
    replace = function(passage)
      return "-> " .. passage
    end
  },

  -- Display: (display: "passage") -> -> passage ->
  display_passage = {
    pattern = '%(display:%s*"(.-)"%s*%)',
    replace = function(passage)
      return "-> " .. passage .. " ->"
    end
  },

  -- Live: (live:)[content] -> content (ignore live wrapper)
  live_block = {
    pattern = "%(live:%s*%)",
    replace = ""
  },

  -- Stop: (stop:) -> (nothing in WLS)
  stop_block = {
    pattern = "%(stop:%s*%)",
    replace = ""
  },
}

--- Convert a Harlowe value to WLS
-- @param value string The Harlowe value
-- @return string The WLS value
function HarloweImporter._convert_value(value)
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

  -- Variable reference
  if value:match("^%$%w+$") then
    return value:sub(2)  -- Remove $ prefix
  end

  -- Expression - keep as-is
  return value
end

--- Convert a Harlowe condition to WLS
-- @param condition string The Harlowe condition
-- @return string The WLS condition
function HarloweImporter._convert_condition(condition)
  if not condition then return "true" end

  condition = condition:match("^%s*(.-)%s*$")  -- Trim

  -- Replace $var with var
  condition = condition:gsub("%$(%w+)", "%1")

  -- Replace "is" with ==
  condition = condition:gsub("%s+is%s+", " == ")

  -- Replace "is not" with !=
  condition = condition:gsub("%s+is%s+not%s+", " != ")

  -- Replace "and" (already compatible)
  -- Replace "or" (already compatible)

  -- Replace "contains" with list_has()
  condition = condition:gsub("(%w+)%s+contains%s+(%w+)", "list_has(%1, %2)")

  return condition
end

--- Create a new Harlowe importer
-- @param container table DI container (optional)
-- @return HarloweImporter
function HarloweImporter.new(container)
  local self = setmetatable({}, { __index = HarloweImporter })
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
function HarloweImporter:can_import(source, options)
  if type(source) ~= "string" or source == "" then
    return false, "Empty or invalid source"
  end

  -- Must have Harlowe-like syntax
  local has_harlowe = source:find("%(set:") or
                      source:find("%(if:") or
                      source:find("%(link:") or
                      source:find("%(go%-to:")

  if not has_harlowe then
    return false, "No Harlowe syntax detected"
  end

  return true
end

--- Detect if source is Harlowe format
-- @param source string Source content
-- @return boolean
function HarloweImporter:detect(source)
  local can, _ = self:can_import(source)
  return can
end

--- Import Harlowe source to WLS Story
-- @param source string Source content
-- @param options table Import options
-- @return Story
function HarloweImporter:import(source, options)
  options = options or {}

  -- Convert Harlowe syntax to WLS
  local wls_content = self:convert_to_wls(source)

  -- Parse WLS content to story
  local story = self:parse_wls_to_story(wls_content)

  return story
end

--- Convert Harlowe source to WLS format
-- @param source string Harlowe source
-- @return string WLS formatted content
function HarloweImporter:convert_to_wls(source)
  local result = source

  -- Apply conversions in order
  for name, conv in pairs(self.conversions) do
    if type(conv.replace) == "function" then
      result = result:gsub(conv.pattern, conv.replace)
    else
      result = result:gsub(conv.pattern, conv.replace)
    end
  end

  -- Clean up any remaining Harlowe hooks []
  result = result:gsub("%[([^%[%]]+)%]", function(content)
    -- If it looks like a choice, leave it
    if content:match("^%s*%+") then
      return "[" .. content .. "]"
    end
    -- Otherwise, just return the content
    return content
  end)

  return result
end

--- Parse WLS content into a Story object
-- @param wls_content string WLS formatted content
-- @return Story
function HarloweImporter:parse_wls_to_story(wls_content)
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
function HarloweImporter:metadata()
  return {
    name = "harlowe",
    version = "3.3.0",
    description = "Import Harlowe (Twine) stories to WLS format",
    extensions = { ".html", ".htm" },
    mime_types = { "text/html" },
    source_format = "Harlowe",
    target_format = "WLS 1.0",
  }
end

return HarloweImporter
