--- Chapbook to WLS Importer
-- Converts Chapbook (Twine) stories to WLS format
-- @module whisker.import.chapbook
-- @author Whisker Core Team
-- @license MIT

local IImporter = require("whisker.import.importer")

local ChapbookImporter = {}
setmetatable(ChapbookImporter, { __index = IImporter })

--- Create a new Chapbook importer
-- @param container table DI container (optional)
-- @return ChapbookImporter
function ChapbookImporter.new(container)
  local self = setmetatable({}, { __index = ChapbookImporter })
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
function ChapbookImporter:can_import(source, options)
  if type(source) ~= "string" or source == "" then
    return false, "Empty or invalid source"
  end

  -- Chapbook-specific markers
  local has_chapbook = source:find("%[if%s+") or
                       source:find("%[else%]") or
                       source:find("%[continue%]") or
                       source:find("^%s*%w+:%s*%d+", 1) or  -- var: value format
                       source:find("%-%-%-")  -- Section separator

  if not has_chapbook then
    return false, "No Chapbook syntax detected"
  end

  return true
end

--- Detect if source is Chapbook format
-- @param source string Source content
-- @return boolean
function ChapbookImporter:detect(source)
  local can, _ = self:can_import(source)
  return can
end

--- Import Chapbook source to WLS Story
-- @param source string Source content
-- @param options table Import options
-- @return Story
function ChapbookImporter:import(source, options)
  options = options or {}

  -- Convert Chapbook syntax to WLS
  local wls_content = self:convert_to_wls(source)

  -- Parse WLS content to story
  local story = self:parse_wls_to_story(wls_content)

  return story
end

--- Convert Chapbook source to WLS format
-- @param source string Chapbook source
-- @return string WLS formatted content
function ChapbookImporter:convert_to_wls(source)
  local result = source

  -- Chapbook uses a "vars section" at the top of passages separated by ---
  -- Format:
  -- varName: value
  -- anotherVar: "string"
  -- ---
  -- Passage content here

  -- Convert variable declarations at passage start
  -- This requires per-passage processing
  result = self:_convert_vars_sections(result)

  -- Convert conditionals: [if condition]content[else]alt[continue] -> {condition}content{else}alt{/}
  result = result:gsub("%[if%s+(.-)%](.-)", function(condition, rest)
    local wls_condition = self:_convert_condition(condition)
    return "{" .. wls_condition .. "}" .. rest
  end)

  -- Convert else
  result = result:gsub("%[else%]", "{else}")

  -- Convert continue (end of conditional)
  result = result:gsub("%[continue%]", "{/}")

  -- Convert links: [[text->passage]] -> + [text] -> passage
  result = result:gsub("%[%[(.-)%->(.-)%]%]", function(text, passage)
    return "+ [" .. text:match("^%s*(.-)%s*$") .. "] -> " .. passage:match("^%s*(.-)%s*$")
  end)

  -- Convert links: [[text<-passage]] -> + [text] -> passage
  result = result:gsub("%[%[(.-)%<%-(.-)%]%]", function(passage, text)
    return "+ [" .. text:match("^%s*(.-)%s*$") .. "] -> " .. passage:match("^%s*(.-)%s*$")
  end)

  -- Convert simple links: [[passage]] -> + [passage] -> passage
  result = result:gsub("%[%[([^%[%]<>%-]+)%]%]", function(passage)
    local trimmed = passage:match("^%s*(.-)%s*$")
    return "+ [" .. trimmed .. "] -> " .. trimmed
  end)

  -- Convert variable interpolation: {varName} -> ${varName}
  -- But avoid converting our conditionals {condition}
  result = result:gsub("{(%w+)}", function(name)
    -- Check if it looks like a condition (has operators)
    if name:find("[<>=!]") or name:find("%s+and%s+") or name:find("%s+or%s+") then
      return "{" .. name .. "}"
    end
    return "${" .. name .. "}"
  end)

  -- Convert append: [append] -> (concatenate to previous)
  result = result:gsub("%[append%]", "")

  -- Convert reveal links: [reveal link: text]hidden[continue] -> + [text]\nhidden
  result = result:gsub("%[reveal%s+link:%s*(.-)%](.-)", function(text, content)
    return "+ [" .. text:match("^%s*(.-)%s*$") .. "]\n" .. content
  end)

  -- Section breaks --- can become horizontal rules
  result = result:gsub("\n%-%-%-\n", "\n---\n")

  return result
end

--- Convert variable sections in Chapbook passages
-- @param source string Source content
-- @return string Converted content
function ChapbookImporter:_convert_vars_sections(source)
  local lines = {}
  local in_vars_section = false
  local passage_started = false

  for line in source:gmatch("[^\n]*") do
    -- Check for passage header
    if line:match("^::%s*.+") then
      passage_started = true
      in_vars_section = true  -- Vars section starts after passage header
      table.insert(lines, line)
    elseif in_vars_section then
      -- Check for section separator
      if line:match("^%-%-%-$") then
        in_vars_section = false
        -- Don't add the separator line
      else
        -- Check for variable declaration: name: value
        local var_name, var_value = line:match("^%s*(%w+):%s*(.+)$")
        if var_name and var_value then
          -- Convert to WLS VAR or @{} syntax
          var_value = var_value:match("^%s*(.-)%s*$")

          -- Determine value type
          if var_value == "true" or var_value == "false" then
            table.insert(lines, "VAR " .. var_name .. " = " .. var_value)
          elseif tonumber(var_value) then
            table.insert(lines, "VAR " .. var_name .. " = " .. var_value)
          elseif var_value:match('^".-"$') or var_value:match("^'.-'$") then
            table.insert(lines, "VAR " .. var_name .. " = " .. var_value)
          else
            table.insert(lines, "VAR " .. var_name .. ' = "' .. var_value .. '"')
          end
        elseif line:match("^%s*$") then
          -- Empty line in vars section - ignore
        else
          -- Not a var declaration, maybe content started without ---
          in_vars_section = false
          table.insert(lines, line)
        end
      end
    else
      table.insert(lines, line)
    end
  end

  return table.concat(lines, "\n")
end

--- Convert a Chapbook condition to WLS
-- @param condition string The Chapbook condition
-- @return string The WLS condition
function ChapbookImporter:_convert_condition(condition)
  if not condition then return "true" end

  condition = condition:match("^%s*(.-)%s*$")  -- Trim

  -- Chapbook uses simple variable names without prefixes
  -- Operators: is, is not, <, >, <=, >=, and, or

  -- Replace "is not" with !=
  condition = condition:gsub("%s+is%s+not%s+", " != ")

  -- Replace "is" with ==
  condition = condition:gsub("%s+is%s+", " == ")

  -- Replace "isn't" with !=
  condition = condition:gsub("%s+isn't%s+", " != ")

  -- "and" and "or" are already compatible

  return condition
end

--- Parse WLS content into a Story object
-- @param wls_content string WLS formatted content
-- @return Story
function ChapbookImporter:parse_wls_to_story(wls_content)
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
    -- Check for variable declaration
    local var_name, var_value = line:match("^VAR%s+(%w+)%s*=%s*(.+)$")
    if var_name then
      story.variables[var_name] = var_value
    else
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
function ChapbookImporter:metadata()
  return {
    name = "chapbook",
    version = "1.2.3",
    description = "Import Chapbook (Twine) stories to WLS format",
    extensions = { ".html", ".htm" },
    mime_types = { "text/html" },
    source_format = "Chapbook",
    target_format = "WLS 1.0",
  }
end

return ChapbookImporter
