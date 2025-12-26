--- SugarCube Story Engine
-- Engine for executing SugarCube-format stories
-- @module whisker.formats.sugarcube.engine
-- @author Whisker Core Team
-- @license MIT

local SugarCubeEngine = {}
SugarCubeEngine.__index = SugarCubeEngine

--- Dependencies injected via container
SugarCubeEngine._dependencies = {"events", "state", "logger"}

--- Create a new SugarCubeEngine instance
-- @param deps table Dependencies from container
-- @return SugarCubeEngine
function SugarCubeEngine.new(deps)
  local self = setmetatable({}, SugarCubeEngine)

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
  self._temporary = {}  -- SugarCube _temporary variables
  self._history = {}
  self._visited = {}  -- Track visited passages

  return self
end

--- Create SugarCubeEngine via container pattern
-- @param container table DI container
-- @return SugarCubeEngine
function SugarCubeEngine.create(container)
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
  return SugarCubeEngine.new(deps)
end

--- Load a parsed SugarCube story
-- @param story table Parsed story with passages
-- @return boolean Success
-- @return string|nil Error message
function SugarCubeEngine:load(story)
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
    self.events:emit("sugarcube:loaded", {
      passage_count = #story.passages,
      start_passage = self._start_passage
    })
  end

  return true
end

--- Find the start passage
-- @private
-- @return string|nil Start passage name
function SugarCubeEngine:_find_start_passage()
  -- Check for passage named "Start"
  if self._passages["Start"] then
    return "Start"
  end

  -- Check for passage with "start" tag
  for name, passage in pairs(self._passages) do
    if passage.tags then
      for _, tag in ipairs(passage.tags) do
        if tag == "start" then
          return name
        end
      end
    end
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
function SugarCubeEngine:start()
  if not self._loaded then
    return nil, "No story loaded"
  end

  if self._started then
    return nil, "Story already started"
  end

  self._started = true
  self._ended = false
  self._variables = {}
  self._temporary = {}
  self._history = {}
  self._visited = {}

  if self.events and self.events.emit then
    self.events:emit("sugarcube:started", {})
  end

  return self:goto_passage(self._start_passage)
end

--- Go to a specific passage
-- @param passage_name string Name of passage to go to
-- @return boolean Success
-- @return string|nil Error message
function SugarCubeEngine:goto_passage(passage_name)
  local passage = self._passages[passage_name]
  if not passage then
    return nil, "Passage not found: " .. passage_name
  end

  -- Add to history and visited
  table.insert(self._history, passage_name)
  self._visited[passage_name] = (self._visited[passage_name] or 0) + 1
  self._current_passage = passage_name

  -- Clear temporary variables on passage change
  self._temporary = {}

  if self.events and self.events.emit then
    self.events:emit("sugarcube:passage_entered", {
      name = passage_name,
      tags = passage.tags
    })
  end

  return true
end

--- Get current passage content
-- @return table|nil Passage data or nil if not started
function SugarCubeEngine:get_current_passage()
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

--- Process passage content (evaluate macros)
-- @private
-- @param content string Raw content
-- @return string Processed content
function SugarCubeEngine:_process_content(content)
  local result = content

  -- Process <<set $var to value>> macros
  result = result:gsub("<<set%s+%$([%w_]+)%s+to%s+(.-)>>", function(var, value)
    self._variables[var] = self:_evaluate_value(value)
    return ""
  end)

  -- Process <<set _var to value>> macros (temporary)
  result = result:gsub("<<set%s+_([%w_]+)%s+to%s+(.-)>>", function(var, value)
    self._temporary[var] = self:_evaluate_value(value)
    return ""
  end)

  -- Process <<if condition>>body<</if>> macros
  result = result:gsub("<<if%s+(.-)>>(.-)<</%s*if%s*>>", function(cond, body)
    if self:_evaluate_condition(cond) then
      return body
    else
      return ""
    end
  end)

  -- Process <<print $var>> macros
  result = result:gsub("<<print%s+%$([%w_]+)%s*>>", function(var)
    local value = self._variables[var]
    if value ~= nil then
      return tostring(value)
    else
      return ""
    end
  end)

  -- Process <<= $var>> shorthand
  result = result:gsub("<<%=%s*%$([%w_]+)%s*>>", function(var)
    local value = self._variables[var]
    if value ~= nil then
      return tostring(value)
    else
      return ""
    end
  end)

  -- Replace $var with values
  result = result:gsub("%$([%w_]+)", function(var)
    local value = self._variables[var]
    if value ~= nil then
      return tostring(value)
    else
      return "$" .. var
    end
  end)

  -- Replace _var with temporary values
  result = result:gsub("_([%w_]+)", function(var)
    local value = self._temporary[var]
    if value ~= nil then
      return tostring(value)
    else
      return "_" .. var
    end
  end)

  return result
end

--- Evaluate a value expression
-- @private
-- @param expr string Expression to evaluate
-- @return any Evaluated value
function SugarCubeEngine:_evaluate_value(expr)
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

  -- Check for variable reference
  local var = trimmed:match("^%$([%w_]+)$")
  if var then
    return self._variables[var]
  end

  -- Check for temporary variable reference
  local temp = trimmed:match("^_([%w_]+)$")
  if temp then
    return self._temporary[temp]
  end

  -- Return as string
  return trimmed
end

--- Evaluate a condition
-- @private
-- @param cond string Condition expression
-- @return boolean Result
function SugarCubeEngine:_evaluate_condition(cond)
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
    if op == "==" or op == "eq" then return l == r end
    if op == "!=" or op == "neq" then return l ~= r end
  end

  -- Check for visited function
  local visited_passage = cond:match("visited%s*%(%s*['\"]([^'\"]+)['\"]%s*%)")
  if visited_passage then
    return (self._visited[visited_passage] or 0) > 0
  end

  -- Check for truthy variable
  local var = cond:match("^%s*%$([%w_]+)%s*$")
  if var then
    return self._variables[var] and true or false
  end

  return false
end

--- Extract links from content
-- @private
-- @param content string Content to extract from
-- @return table Array of link objects
function SugarCubeEngine:_extract_links(content)
  local links = {}

  -- [[Text|Target]]
  for text, target in content:gmatch("%[%[([^%]|]+)|([^%]]+)%]%]") do
    table.insert(links, {text = text, target = target})
  end

  -- [[Target]] (simple links)
  for target in content:gmatch("%[%[([^%]|]+)%]%]") do
    -- Skip if already matched with |
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
function SugarCubeEngine:follow_link(target)
  return self:goto_passage(target)
end

--- Get a variable value
-- @param name string Variable name
-- @return any Variable value or nil
function SugarCubeEngine:get_variable(name)
  return self._variables[name]
end

--- Set a variable value
-- @param name string Variable name
-- @param value any Variable value
function SugarCubeEngine:set_variable(name, value)
  self._variables[name] = value

  if self.events and self.events.emit then
    self.events:emit("sugarcube:variable_changed", {
      name = name,
      value = value
    })
  end
end

--- Get all variables
-- @return table Copy of variables table
function SugarCubeEngine:get_variables()
  local copy = {}
  for k, v in pairs(self._variables) do
    copy[k] = v
  end
  return copy
end

--- Get visit count for a passage
-- @param passage_name string Passage name
-- @return number Visit count
function SugarCubeEngine:visited(passage_name)
  return self._visited[passage_name] or 0
end

--- Get passage history
-- @return table Array of passage names
function SugarCubeEngine:get_history()
  local copy = {}
  for i, v in ipairs(self._history) do
    copy[i] = v
  end
  return copy
end

--- Go back in history
-- @return boolean Success
-- @return string|nil Error message
function SugarCubeEngine:go_back()
  if #self._history <= 1 then
    return nil, "No history to go back to"
  end

  -- Remove current passage from history
  table.remove(self._history)

  -- Get previous passage
  local previous = self._history[#self._history]
  table.remove(self._history)  -- Remove it so goto_passage can add it back

  return self:goto_passage(previous)
end

--- Check if story has ended
-- @return boolean True if story ended
function SugarCubeEngine:has_ended()
  return self._ended
end

--- Check if story is loaded
-- @return boolean True if story loaded
function SugarCubeEngine:is_loaded()
  return self._loaded
end

--- Check if story has started
-- @return boolean True if story started
function SugarCubeEngine:is_started()
  return self._started
end

--- End the story
function SugarCubeEngine:end_story()
  self._ended = true

  if self.events and self.events.emit then
    self.events:emit("sugarcube:ended", {
      history = self._history
    })
  end
end

--- Reset the engine
function SugarCubeEngine:reset()
  self._story = nil
  self._passages = nil
  self._loaded = false
  self._started = false
  self._ended = false
  self._current_passage = nil
  self._variables = {}
  self._temporary = {}
  self._history = {}
  self._visited = {}

  if self.events and self.events.emit then
    self.events:emit("sugarcube:reset", {})
  end
end

--- Get engine metadata
-- @return table Engine metadata
function SugarCubeEngine:get_metadata()
  return {
    format = "sugarcube",
    version = "1.0.0",
    loaded = self._loaded,
    started = self._started,
    ended = self._ended,
    passage_count = self._story and #self._story.passages or 0,
    variable_count = 0
  }
end

return SugarCubeEngine
