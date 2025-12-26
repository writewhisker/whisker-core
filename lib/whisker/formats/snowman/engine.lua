--- Snowman Story Engine
-- Engine for executing Snowman-format stories
-- @module whisker.formats.snowman.engine
-- @author Whisker Core Team
-- @license MIT

local SnowmanEngine = {}
SnowmanEngine.__index = SnowmanEngine

--- Dependencies injected via container
SnowmanEngine._dependencies = {"events", "state", "logger"}

--- Create a new SnowmanEngine instance
-- @param deps table Dependencies from container
-- @return SnowmanEngine
function SnowmanEngine.new(deps)
  local self = setmetatable({}, SnowmanEngine)

  deps = deps or {}
  self.events = deps.events
  self.state = deps.state
  self.log = deps.logger

  self._story = nil
  self._loaded = false
  self._started = false
  self._ended = false
  self._current_passage = nil
  self._state = {}  -- Snowman uses s.variable syntax
  self._history = {}

  return self
end

--- Create SnowmanEngine via container pattern
-- @param container table DI container
-- @return SnowmanEngine
function SnowmanEngine.create(container)
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
  return SnowmanEngine.new(deps)
end

--- Load a parsed Snowman story
-- @param story table Parsed story with passages
-- @return boolean Success
-- @return string|nil Error message
function SnowmanEngine:load(story)
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
    self.events:emit("snowman:loaded", {
      passage_count = #story.passages,
      start_passage = self._start_passage
    })
  end

  return true
end

--- Find the start passage
-- @private
-- @return string|nil Start passage name
function SnowmanEngine:_find_start_passage()
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
function SnowmanEngine:start()
  if not self._loaded then
    return nil, "No story loaded"
  end

  if self._started then
    return nil, "Story already started"
  end

  self._started = true
  self._ended = false
  self._state = {}
  self._history = {}

  if self.events and self.events.emit then
    self.events:emit("snowman:started", {})
  end

  return self:goto_passage(self._start_passage)
end

--- Go to a specific passage
-- @param passage_name string Name of passage to go to
-- @return boolean Success
-- @return string|nil Error message
function SnowmanEngine:goto_passage(passage_name)
  local passage = self._passages[passage_name]
  if not passage then
    return nil, "Passage not found: " .. passage_name
  end

  -- Add to history
  table.insert(self._history, passage_name)
  self._current_passage = passage_name

  if self.events and self.events.emit then
    self.events:emit("snowman:passage_entered", {
      name = passage_name,
      tags = passage.tags
    })
  end

  return true
end

--- Get current passage content
-- @return table|nil Passage data or nil if not started
function SnowmanEngine:get_current_passage()
  if not self._started or not self._current_passage then
    return nil
  end

  local passage = self._passages[self._current_passage]
  if not passage then
    return nil
  end

  return {
    name = passage.name,
    content = self:_process_content(passage.content),
    tags = passage.tags or {},
    links = self:_extract_links(passage.content)
  }
end

--- Process passage content (evaluate JavaScript-like expressions)
-- @private
-- @param content string Raw content
-- @return string Processed content
function SnowmanEngine:_process_content(content)
  local result = content

  -- Two-pass approach to handle <%= %> and <% %> correctly
  -- Step 1: Save <%= expr %> blocks with placeholders
  local output_blocks = {}
  local idx = 0
  result = result:gsub("<%%=(.-)%%>", function(expr)
    idx = idx + 1
    output_blocks[idx] = expr
    return "\0OUTPUT_" .. idx .. "\0"
  end)

  -- Step 2: Process <% code %> blocks (execute and remove)
  result = result:gsub("<%%(.-)%%>", function(code)
    self:_execute_code(code)
    return ""
  end)

  -- Step 3: Replace output placeholders with evaluated values
  result = result:gsub("\0OUTPUT_(%d+)\0", function(idx_str)
    local expr = output_blocks[tonumber(idx_str)]
    local value = self:_evaluate_expression(expr)
    if value ~= nil then
      return tostring(value)
    else
      return ""
    end
  end)

  -- Process ${expr} interpolation
  result = result:gsub("%${([^}]+)}", function(expr)
    local value = self:_evaluate_expression(expr)
    if value ~= nil then
      return tostring(value)
    else
      return ""
    end
  end)

  return result
end

--- Execute JavaScript-like code
-- @private
-- @param code string Code to execute
function SnowmanEngine:_execute_code(code)
  -- Process s.variable = value assignments
  for var, value in code:gmatch("s%.([%w_]+)%s*=%s*([^;]+)") do
    self._state[var] = self:_evaluate_value(value)
  end

  -- Process window.story.show('passage') calls
  local show_passage = code:match("window%.story%.show%s*%(%s*['\"]([^'\"]+)['\"]%s*%)")
  if show_passage then
    self:goto_passage(show_passage)
  end
end

--- Evaluate a value expression
-- @private
-- @param expr string Expression to evaluate
-- @return any Evaluated value
function SnowmanEngine:_evaluate_value(expr)
  local trimmed = expr:match("^%s*(.-)%s*$")

  -- Check for number
  local num = tonumber(trimmed)
  if num then return num end

  -- Check for boolean
  if trimmed == "true" then return true end
  if trimmed == "false" then return false end

  -- Check for string
  local str = trimmed:match('^"(.-)"$') or trimmed:match("^'(.-)'$")
  if str then return str end

  -- Check for state variable reference (s.var)
  local var = trimmed:match("^s%.([%w_]+)$")
  if var then
    return self._state[var]
  end

  -- Return as string
  return trimmed
end

--- Evaluate an expression
-- @private
-- @param expr string Expression to evaluate
-- @return any Evaluated value
function SnowmanEngine:_evaluate_expression(expr)
  local trimmed = expr:match("^%s*(.-)%s*$")

  -- Check for s.variable reference
  local var = trimmed:match("^s%.([%w_]+)$")
  if var then
    return self._state[var]
  end

  -- Check for simple arithmetic (s.var + n)
  local var_name, op, num = trimmed:match("^s%.([%w_]+)%s*([%+%-])%s*(%d+)$")
  if var_name and op and num then
    local base = self._state[var_name] or 0
    local n = tonumber(num)
    if op == "+" then return base + n end
    if op == "-" then return base - n end
  end

  -- Check for conditional (s.var ? a : b)
  local cond_var, true_val, false_val = trimmed:match("^s%.([%w_]+)%s*%?%s*([^:]+)%s*:%s*(.+)$")
  if cond_var then
    if self._state[cond_var] then
      return self:_evaluate_value(true_val)
    else
      return self:_evaluate_value(false_val)
    end
  end

  return self:_evaluate_value(trimmed)
end

--- Extract links from content
-- @private
-- @param content string Content to extract from
-- @return table Array of link objects
function SnowmanEngine:_extract_links(content)
  local links = {}

  -- Snowman uses markdown-style [Text](passage)
  for text, target in content:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
    -- Skip external URLs
    if not target:match("^https?://") then
      table.insert(links, {text = text, target = target})
    end
  end

  -- Also support [[Target]] syntax
  for target in content:gmatch("%[%[([^%]]+)%]%]") do
    table.insert(links, {text = target, target = target})
  end

  return links
end

--- Follow a link
-- @param target string Target passage name
-- @return boolean Success
-- @return string|nil Error message
function SnowmanEngine:follow_link(target)
  return self:goto_passage(target)
end

--- Get a state variable value
-- @param name string Variable name
-- @return any Variable value or nil
function SnowmanEngine:get_variable(name)
  return self._state[name]
end

--- Set a state variable value
-- @param name string Variable name
-- @param value any Variable value
function SnowmanEngine:set_variable(name, value)
  self._state[name] = value

  if self.events and self.events.emit then
    self.events:emit("snowman:variable_changed", {
      name = name,
      value = value
    })
  end
end

--- Get all state variables
-- @return table Copy of state table
function SnowmanEngine:get_variables()
  local copy = {}
  for k, v in pairs(self._state) do
    copy[k] = v
  end
  return copy
end

--- Get passage history
-- @return table Array of passage names
function SnowmanEngine:get_history()
  local copy = {}
  for i, v in ipairs(self._history) do
    copy[i] = v
  end
  return copy
end

--- Check if story has ended
-- @return boolean True if story ended
function SnowmanEngine:has_ended()
  return self._ended
end

--- Check if story is loaded
-- @return boolean True if story loaded
function SnowmanEngine:is_loaded()
  return self._loaded
end

--- Check if story has started
-- @return boolean True if story started
function SnowmanEngine:is_started()
  return self._started
end

--- End the story
function SnowmanEngine:end_story()
  self._ended = true

  if self.events and self.events.emit then
    self.events:emit("snowman:ended", {
      history = self._history
    })
  end
end

--- Reset the engine
function SnowmanEngine:reset()
  self._story = nil
  self._passages = nil
  self._loaded = false
  self._started = false
  self._ended = false
  self._current_passage = nil
  self._state = {}
  self._history = {}

  if self.events and self.events.emit then
    self.events:emit("snowman:reset", {})
  end
end

--- Get engine metadata
-- @return table Engine metadata
function SnowmanEngine:get_metadata()
  return {
    format = "snowman",
    version = "1.0.0",
    loaded = self._loaded,
    started = self._started,
    ended = self._ended,
    passage_count = self._story and #self._story.passages or 0,
    variable_count = 0
  }
end

return SnowmanEngine
