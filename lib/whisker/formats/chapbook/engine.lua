--- Chapbook Story Engine
-- Engine for executing Chapbook-format stories
-- @module whisker.formats.chapbook.engine
-- @author Whisker Core Team
-- @license MIT

local ChapbookEngine = {}
ChapbookEngine.__index = ChapbookEngine

--- Dependencies injected via container
ChapbookEngine._dependencies = {"events", "state", "logger"}

--- Create a new ChapbookEngine instance
-- @param deps table Dependencies from container
-- @return ChapbookEngine
function ChapbookEngine.new(deps)
  local self = setmetatable({}, ChapbookEngine)

  deps = deps or {}
  self.events = deps.events
  self.state = deps.state
  self.log = deps.logger

  self._story = nil
  self._loaded = false
  self._started = false
  self._ended = false
  self._current_passage = nil
  self._variables = {}
  self._history = {}
  self._inserts = {}  -- Chapbook inserts
  self._modifiers = {}  -- Chapbook modifiers

  return self
end

--- Create ChapbookEngine via container pattern
-- @param container table DI container
-- @return ChapbookEngine
function ChapbookEngine.create(container)
  local deps = {}
  if container and container.has then
    if container:has("events") then
      deps.events = container:resolve("events")
    end
    if container:has("state") then
      deps.state = container:resolve("state")
    end
    if container:has("logger") then
      deps.logger = container:resolve("logger")
    end
  end
  return ChapbookEngine.new(deps)
end

--- Load a parsed Chapbook story
-- @param story table Parsed story with passages
-- @return boolean Success
-- @return string|nil Error message
function ChapbookEngine:load(story)
  if self._loaded then
    return nil, "Story already loaded. Call reset() first."
  end

  if not story or not story.passages then
    return nil, "Invalid story: no passages found"
  end

  self._story = story
  self._passages = {}

  -- Index passages by name
  for _, passage in ipairs(story.passages) do
    self._passages[passage.name] = passage
  end

  -- Find start passage
  self._start_passage = self:_find_start_passage()
  if not self._start_passage then
    return nil, "No start passage found"
  end

  self._loaded = true

  if self.events and self.events.emit then
    self.events:emit("chapbook:loaded", {
      passage_count = #story.passages,
      start_passage = self._start_passage
    })
  end

  return true
end

--- Find the start passage
-- @private
-- @return string|nil Start passage name
function ChapbookEngine:_find_start_passage()
  -- Check for passage named "Start"
  if self._passages["Start"] then
    return "Start"
  end

  -- Return first passage
  if self._story.passages[1] then
    return self._story.passages[1].name
  end

  return nil
end

--- Start the story
-- @return boolean Success
-- @return string|nil Error message
function ChapbookEngine:start()
  if not self._loaded then
    return nil, "No story loaded"
  end

  if self._started then
    return nil, "Story already started"
  end

  self._started = true
  self._ended = false
  self._variables = {}
  self._history = {}

  if self.events and self.events.emit then
    self.events:emit("chapbook:started", {})
  end

  return self:goto_passage(self._start_passage)
end

--- Go to a specific passage
-- @param passage_name string Name of passage to go to
-- @return boolean Success
-- @return string|nil Error message
function ChapbookEngine:goto_passage(passage_name)
  local passage = self._passages[passage_name]
  if not passage then
    return nil, "Passage not found: " .. passage_name
  end

  -- Add to history
  table.insert(self._history, passage_name)
  self._current_passage = passage_name

  if self.events and self.events.emit then
    self.events:emit("chapbook:passage_entered", {
      name = passage_name,
      tags = passage.tags
    })
  end

  return true
end

--- Get current passage content
-- @return table|nil Passage data or nil if not started
function ChapbookEngine:get_current_passage()
  if not self._started or not self._current_passage then
    return nil
  end

  local passage = self._passages[self._current_passage]
  if not passage then
    return nil
  end

  local vars_section, text_section = self:_split_passage(passage.content)

  -- Process vars section first
  if vars_section then
    self:_process_vars_section(vars_section)
  end

  return {
    name = passage.name,
    content = self:_process_content(text_section or passage.content),
    tags = passage.tags or {},
    links = self:_extract_links(text_section or passage.content)
  }
end

--- Split passage into vars and text sections
-- @private
-- @param content string Passage content
-- @return string|nil, string Vars section and text section
function ChapbookEngine:_split_passage(content)
  -- Chapbook uses -- to separate vars from text
  local vars, text = content:match("^(.-)%-%-\n(.*)$")
  if vars and text then
    return vars, text
  end
  return nil, content
end

--- Process vars section
-- @private
-- @param vars_section string Vars section content
function ChapbookEngine:_process_vars_section(vars_section)
  -- Chapbook format: varname: value
  for var, value in vars_section:gmatch("([%w_]+):%s*([^\n]+)") do
    self._variables[var] = self:_evaluate_value(value)
  end
end

--- Process passage content (evaluate inserts and modifiers)
-- @private
-- @param content string Raw content
-- @return string Processed content
function ChapbookEngine:_process_content(content)
  local result = content

  -- Process {varname} inserts
  result = result:gsub("{([%w_]+)}", function(var)
    local value = self._variables[var]
    if value ~= nil then
      return tostring(value)
    else
      return "{" .. var .. "}"
    end
  end)

  -- Process [if condition] modifiers
  result = result:gsub("%[if%s+([^%]]+)%]([^\n]*)", function(cond, text)
    if self:_evaluate_condition(cond) then
      return text
    else
      return ""
    end
  end)

  -- Process [unless condition] modifiers
  result = result:gsub("%[unless%s+([^%]]+)%]([^\n]*)", function(cond, text)
    if not self:_evaluate_condition(cond) then
      return text
    else
      return ""
    end
  end)

  -- Process [cont'd] modifier (continuation)
  result = result:gsub("%[cont'd%]", "")

  return result
end

--- Evaluate a value expression
-- @private
-- @param expr string Expression to evaluate
-- @return any Evaluated value
function ChapbookEngine:_evaluate_value(expr)
  local trimmed = expr:match("^%s*(.-)%s*$")

  -- Check for number
  local num = tonumber(trimmed)
  if num then return num end

  -- Check for boolean
  if trimmed == "true" then return true end
  if trimmed == "false" then return false end

  -- Check for string (quoted)
  local str = trimmed:match('^"(.-)"$') or trimmed:match("^'(.-)'$")
  if str then return str end

  -- Check for variable reference
  local var = trimmed:match("^([%w_]+)$")
  if var and self._variables[var] ~= nil then
    return self._variables[var]
  end

  -- Return as string
  return trimmed
end

--- Evaluate a condition
-- @private
-- @param cond string Condition expression
-- @return boolean Result
function ChapbookEngine:_evaluate_condition(cond)
  -- Simple condition evaluation
  local left, op, right = cond:match("^%s*(.-)%s*([><=!]+)%s*(.-)%s*$")

  if left and op and right then
    local l = self:_evaluate_value(left)
    local r = self:_evaluate_value(right)

    -- Convert to numbers if possible
    local ln = tonumber(l)
    local rn = tonumber(r)
    if ln and rn then
      l, r = ln, rn
    end

    if op == ">" then return l > r end
    if op == "<" then return l < r end
    if op == ">=" then return l >= r end
    if op == "<=" then return l <= r end
    if op == "==" or op == "is" then return l == r end
    if op == "!=" then return l ~= r end
  end

  -- Check for truthy variable
  local var = cond:match("^%s*([%w_]+)%s*$")
  if var then
    return self._variables[var] and true or false
  end

  return false
end

--- Extract links from content
-- @private
-- @param content string Content to extract from
-- @return table Array of link objects
function ChapbookEngine:_extract_links(content)
  local links = {}

  -- Chapbook uses [[Text->Target]]
  for text, target in content:gmatch("%[%[([^%]>]+)%->([^%]]+)%]%]") do
    table.insert(links, {text = text, target = target})
  end

  -- [[Target]] (simple links)
  for target in content:gmatch("%[%[([^%]|>]+)%]%]") do
    -- Skip if already matched with ->
    local found = false
    for _, link in ipairs(links) do
      if link.target == target then
        found = true
        break
      end
    end
    if not found then
      table.insert(links, {text = target, target = target})
    end
  end

  return links
end

--- Follow a link
-- @param target string Target passage name
-- @return boolean Success
-- @return string|nil Error message
function ChapbookEngine:follow_link(target)
  return self:goto_passage(target)
end

--- Get a variable value
-- @param name string Variable name
-- @return any Variable value or nil
function ChapbookEngine:get_variable(name)
  return self._variables[name]
end

--- Set a variable value
-- @param name string Variable name
-- @param value any Variable value
function ChapbookEngine:set_variable(name, value)
  self._variables[name] = value

  if self.events and self.events.emit then
    self.events:emit("chapbook:variable_changed", {
      name = name,
      value = value
    })
  end
end

--- Get all variables
-- @return table Copy of variables table
function ChapbookEngine:get_variables()
  local copy = {}
  for k, v in pairs(self._variables) do
    copy[k] = v
  end
  return copy
end

--- Get passage history
-- @return table Array of passage names
function ChapbookEngine:get_history()
  local copy = {}
  for i, v in ipairs(self._history) do
    copy[i] = v
  end
  return copy
end

--- Check if story has ended
-- @return boolean True if story ended
function ChapbookEngine:has_ended()
  return self._ended
end

--- Check if story is loaded
-- @return boolean True if story loaded
function ChapbookEngine:is_loaded()
  return self._loaded
end

--- Check if story has started
-- @return boolean True if story started
function ChapbookEngine:is_started()
  return self._started
end

--- End the story
function ChapbookEngine:end_story()
  self._ended = true

  if self.events and self.events.emit then
    self.events:emit("chapbook:ended", {
      history = self._history
    })
  end
end

--- Reset the engine
function ChapbookEngine:reset()
  self._story = nil
  self._passages = nil
  self._loaded = false
  self._started = false
  self._ended = false
  self._current_passage = nil
  self._variables = {}
  self._history = {}
  self._inserts = {}
  self._modifiers = {}

  if self.events and self.events.emit then
    self.events:emit("chapbook:reset", {})
  end
end

--- Get engine metadata
-- @return table Engine metadata
function ChapbookEngine:get_metadata()
  return {
    format = "chapbook",
    version = "1.0.0",
    loaded = self._loaded,
    started = self._started,
    ended = self._ended,
    passage_count = self._story and #self._story.passages or 0,
    variable_count = 0
  }
end

return ChapbookEngine
