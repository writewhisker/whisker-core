--- Debug Variable Inspector
-- Provides variable inspection for debugging WLS stories
-- @module whisker.debug.inspector
-- @author Whisker Core Team
-- @license MIT

local Inspector = {}
Inspector.__index = Inspector
Inspector._dependencies = {}

-- Scope IDs for DAP
Inspector.SCOPE_GLOBAL = 1000
Inspector.SCOPE_TEMP = 2000
Inspector.SCOPE_COLLECTIONS = 3000
Inspector.SCOPE_SYSTEM = 4000
Inspector.SCOPE_HOOKS = 5000

--- Create a new inspector
-- @param game_state table Game state instance
-- @param interpreter table Interpreter instance (optional)
-- @return Inspector Inspector instance
function Inspector.new(game_state, interpreter)
  local self = setmetatable({}, Inspector)
  self._game_state = game_state
  self._interpreter = interpreter
  self._variable_refs = {}  -- ref_id -> { type, data }
  self._next_ref = 6000
  self._watch_expressions = {}
  return self
end

--- Set the game state
-- @param game_state table Game state instance
function Inspector:set_game_state(game_state)
  self._game_state = game_state
end

--- Set the interpreter
-- @param interpreter table Interpreter instance
function Inspector:set_interpreter(interpreter)
  self._interpreter = interpreter
end

--- Get all variable scopes
-- @return table Array of scope objects
function Inspector:get_scopes()
  return {
    {
      name = "Story Variables",
      variablesReference = Inspector.SCOPE_GLOBAL,
      expensive = false
    },
    {
      name = "Temp Variables",
      variablesReference = Inspector.SCOPE_TEMP,
      expensive = false
    },
    {
      name = "Collections",
      variablesReference = Inspector.SCOPE_COLLECTIONS,
      expensive = false
    },
    {
      name = "System State",
      variablesReference = Inspector.SCOPE_SYSTEM,
      expensive = false
    }
  }
end

--- Get variables for a scope reference
-- @param scope_ref number Scope or variable reference ID
-- @return table Array of variable objects
function Inspector:get_variables(scope_ref)
  if scope_ref == Inspector.SCOPE_GLOBAL then
    return self:_get_global_variables()
  elseif scope_ref == Inspector.SCOPE_TEMP then
    return self:_get_temp_variables()
  elseif scope_ref == Inspector.SCOPE_COLLECTIONS then
    return self:_get_collections()
  elseif scope_ref == Inspector.SCOPE_SYSTEM then
    return self:_get_system_state()
  elseif self._variable_refs[scope_ref] then
    return self:_expand_reference(scope_ref)
  end
  return {}
end

--- Get global (story) variables
-- @return table Array of variable objects
function Inspector:_get_global_variables()
  local vars = {}

  if not self._game_state then
    return vars
  end

  -- Try to get all variables from game state
  local all_vars = {}
  if self._game_state.get_all_variables then
    all_vars = self._game_state:get_all_variables() or {}
  elseif self._game_state.variables then
    all_vars = self._game_state.variables or {}
  end

  for name, value in pairs(all_vars) do
    table.insert(vars, self:_create_variable("$" .. name, value))
  end

  table.sort(vars, function(a, b) return a.name < b.name end)
  return vars
end

--- Get temp variables
-- @return table Array of variable objects
function Inspector:_get_temp_variables()
  local vars = {}

  if not self._game_state then
    return vars
  end

  -- Try to get temp variables from game state
  local all_temp = {}
  if self._game_state.get_all_temp_variables then
    all_temp = self._game_state:get_all_temp_variables() or {}
  elseif self._game_state.temp_variables then
    all_temp = self._game_state.temp_variables or {}
  end

  for name, value in pairs(all_temp) do
    table.insert(vars, self:_create_variable("_" .. name, value))
  end

  table.sort(vars, function(a, b) return a.name < b.name end)
  return vars
end

--- Get collections (lists, arrays, maps)
-- @return table Array of variable objects
function Inspector:_get_collections()
  local vars = {}

  if not self._game_state then
    return vars
  end

  -- Get collections if available
  local collections = {}
  if self._game_state.get_all_collections then
    collections = self._game_state:get_all_collections() or {}
  end

  -- Lists
  for name, list in pairs(collections.lists or {}) do
    local ref = self:_create_reference("list", list)
    table.insert(vars, {
      name = "LIST " .. name,
      value = self:_format_list_preview(list),
      type = "list",
      variablesReference = ref
    })
  end

  -- Arrays
  for name, arr in pairs(collections.arrays or {}) do
    local ref = self:_create_reference("array", arr)
    table.insert(vars, {
      name = "ARRAY " .. name,
      value = self:_format_array_preview(arr),
      type = "array",
      variablesReference = ref
    })
  end

  -- Maps
  for name, map in pairs(collections.maps or {}) do
    local ref = self:_create_reference("map", map)
    table.insert(vars, {
      name = "MAP " .. name,
      value = self:_format_map_preview(map),
      type = "map",
      variablesReference = ref
    })
  end

  return vars
end

--- Get system state variables
-- @return table Array of variable objects
function Inspector:_get_system_state()
  local vars = {}

  if not self._game_state then
    return {
      {
        name = "_passage",
        value = "(no state)",
        type = "string",
        variablesReference = 0
      }
    }
  end

  -- Current passage
  local current_passage = "(none)"
  if self._game_state.get_current_passage then
    current_passage = self._game_state:get_current_passage() or "(none)"
  elseif self._game_state.current_passage then
    current_passage = self._game_state.current_passage or "(none)"
  end

  table.insert(vars, {
    name = "_passage",
    value = current_passage,
    type = "string",
    variablesReference = 0
  })

  -- Visit count
  local visit_count = 0
  if self._game_state.get_visit_count and current_passage ~= "(none)" then
    visit_count = self._game_state:get_visit_count(current_passage) or 0
  end

  table.insert(vars, {
    name = "_visits",
    value = tostring(visit_count),
    type = "number",
    variablesReference = 0
  })

  -- Total visits
  if self._game_state.get_total_visits then
    table.insert(vars, {
      name = "_total_visits",
      value = tostring(self._game_state:get_total_visits() or 0),
      type = "number",
      variablesReference = 0
    })
  end

  -- History
  if self._game_state.get_history then
    local history = self._game_state:get_history() or {}
    local ref = self:_create_reference("array", history)
    table.insert(vars, {
      name = "_history",
      value = self:_format_array_preview(history),
      type = "array",
      variablesReference = ref
    })
  end

  return vars
end

--- Create a variable object
-- @param name string Variable name
-- @param value any Variable value
-- @return table Variable object
function Inspector:_create_variable(name, value)
  local var = {
    name = name,
    value = self:_format_value(value),
    type = type(value),
    variablesReference = 0
  }

  -- Create reference for expandable types
  if type(value) == "table" then
    var.variablesReference = self:_create_reference("table", value)
  end

  return var
end

--- Create a variable reference for expandable types
-- @param ref_type string Type of reference
-- @param data any Data for the reference
-- @return number Reference ID
function Inspector:_create_reference(ref_type, data)
  local ref = self._next_ref
  self._next_ref = self._next_ref + 1
  self._variable_refs[ref] = { type = ref_type, data = data }
  return ref
end

--- Expand a variable reference
-- @param ref number Reference ID
-- @return table Array of variable objects
function Inspector:_expand_reference(ref)
  local info = self._variable_refs[ref]
  if not info then return {} end

  local vars = {}

  if info.type == "table" then
    for k, v in pairs(info.data) do
      table.insert(vars, self:_create_variable(tostring(k), v))
    end
  elseif info.type == "list" then
    -- Show active values
    local active = info.data.active or info.data
    if type(active) == "table" then
      for name, is_active in pairs(active) do
        if is_active then
          table.insert(vars, {
            name = tostring(name),
            value = "active",
            type = "list_item",
            variablesReference = 0
          })
        end
      end
    end
  elseif info.type == "array" then
    for i, v in ipairs(info.data) do
      table.insert(vars, self:_create_variable("[" .. (i - 1) .. "]", v))
    end
  elseif info.type == "map" then
    for k, v in pairs(info.data) do
      table.insert(vars, self:_create_variable(tostring(k), v))
    end
  end

  return vars
end

--- Format a value for display
-- @param value any Value to format
-- @return string Formatted value
function Inspector:_format_value(value)
  local t = type(value)
  if t == "nil" then
    return "nil"
  elseif t == "boolean" then
    return value and "true" or "false"
  elseif t == "number" then
    return tostring(value)
  elseif t == "string" then
    if #value > 50 then
      return '"' .. value:sub(1, 47) .. '..."'
    end
    return '"' .. value .. '"'
  elseif t == "table" then
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return string.format("{...} (%d items)", count)
  else
    return tostring(value)
  end
end

--- Format list preview
-- @param list table List data
-- @return string Formatted preview
function Inspector:_format_list_preview(list)
  local active = {}
  local data = list.active or list
  if type(data) == "table" then
    for name, is_active in pairs(data) do
      if is_active then table.insert(active, tostring(name)) end
    end
  end
  if #active == 0 then return "(empty)" end
  if #active <= 3 then return table.concat(active, ", ") end
  return active[1] .. ", " .. active[2] .. ", ... (" .. #active .. " active)"
end

--- Format array preview
-- @param arr table Array data
-- @return string Formatted preview
function Inspector:_format_array_preview(arr)
  local count = #arr
  if count == 0 then return "[]" end
  return string.format("[...] (%d items)", count)
end

--- Format map preview
-- @param map table Map data
-- @return string Formatted preview
function Inspector:_format_map_preview(map)
  local count = 0
  for _ in pairs(map) do count = count + 1 end
  if count == 0 then return "{}" end
  return string.format("{...} (%d entries)", count)
end

--- Set a variable value
-- @param scope_ref number Scope reference
-- @param name string Variable name
-- @param value any New value
-- @return boolean Success
function Inspector:set_variable(scope_ref, name, value)
  if not self._game_state then
    return false
  end

  if scope_ref == Inspector.SCOPE_GLOBAL then
    -- Remove $ prefix if present
    local clean_name = name:match("^%$(.+)$") or name
    if self._game_state.set then
      self._game_state:set(clean_name, value)
      return true
    end
  elseif scope_ref == Inspector.SCOPE_TEMP then
    -- Remove _ prefix if present
    local clean_name = name:match("^_(.+)$") or name
    if self._game_state.set_temp then
      self._game_state:set_temp(clean_name, value)
      return true
    end
  end

  return false
end

--- Evaluate an expression
-- @param expression string Expression to evaluate
-- @return any Result
-- @return string|nil Error message
function Inspector:evaluate(expression)
  if not self._interpreter then
    return nil, "No interpreter available"
  end

  -- Try to evaluate the expression
  local ok, result = pcall(function()
    if self._interpreter.eval then
      return self._interpreter:eval(expression)
    elseif self._interpreter.evaluate then
      return self._interpreter:evaluate(expression)
    else
      return nil, "Interpreter does not support evaluation"
    end
  end)

  if ok then
    return result
  else
    return nil, tostring(result)
  end
end

--- Add a watch expression
-- @param expression string Expression to watch
-- @return number Watch ID
function Inspector:add_watch(expression)
  local id = #self._watch_expressions + 1
  self._watch_expressions[id] = {
    expression = expression,
    last_value = nil
  }
  return id
end

--- Remove a watch expression
-- @param id number Watch ID
function Inspector:remove_watch(id)
  self._watch_expressions[id] = nil
end

--- Evaluate all watch expressions
-- @return table Array of watch results
function Inspector:evaluate_watches()
  local results = {}
  for id, watch in pairs(self._watch_expressions) do
    local value, err = self:evaluate(watch.expression)
    table.insert(results, {
      id = id,
      expression = watch.expression,
      value = value,
      error = err
    })
    watch.last_value = value
  end
  return results
end

--- Clear all variable references (call when execution resumes)
function Inspector:clear_references()
  self._variable_refs = {}
  self._next_ref = 6000
end

return Inspector
