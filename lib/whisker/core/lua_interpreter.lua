-- lib/whisker/core/lua_interpreter.lua
-- Lua interpreter with whisker.hook API namespace
-- WLS 1.0.0 compliant with:
--   GAP-002: Expression interpolation support
--   GAP-003: WLS-compliant truthiness (0 and "" are falsy)
--   GAP-007: visited() global function
--   GAP-008: Comprehensive Lua sandboxing
--   GAP-018: pick() function for random selection
--   GAP-019: whisker.hook.clear() method
--   GAP-069: isVisible() naming with backward compat alias

local Utils = require("lib.whisker.core.utils")

local LuaInterpreter = {}
LuaInterpreter.__index = LuaInterpreter

-- Track deprecation warnings to only warn once per hook name
local deprecation_warned = {}

--- GAP-008: Safe global functions (explicit allowlist)
LuaInterpreter.SAFE_GLOBALS = {
  "assert",
  "error",
  "ipairs",
  "next",
  "pairs",
  "pcall",
  "select",
  "tonumber",
  "tostring",
  "type",
  "unpack",
  "xpcall",
  "_VERSION",
}

--- GAP-008: Safe modules (full access)
LuaInterpreter.SAFE_MODULES = {
  "math",
  "string",
}

--- GAP-008: Partial modules (only specific functions allowed)
LuaInterpreter.PARTIAL_MODULES = {
  table = {
    "concat",
    "insert",
    "move",
    "pack",
    "remove",
    "sort",
    "unpack",
  },
  utf8 = {
    "char",
    "charpattern",
    "codepoint",
    "codes",
    "len",
    "offset",
  },
  os = {
    "clock",
    "date",
    "difftime",
    "time",
  },
}

--- GAP-008: Blocked functions - provide stubs with clear error messages
LuaInterpreter.BLOCKED_FUNCTIONS = {
  "require",
  "loadfile",
  "dofile",
  "load",
  "loadstring",
  "collectgarbage",
  "module",
  "setfenv",
  "getfenv",
  "newproxy",
}

--- GAP-008: Blocked modules
LuaInterpreter.BLOCKED_MODULES = {
  "io",
  "debug",
  "package",
  "coroutine",
}

--- GAP-008: Blocked os functions
LuaInterpreter.BLOCKED_OS_FUNCTIONS = {
  "execute",
  "exit",
  "remove",
  "rename",
  "getenv",
  "setenv",
  "setlocale",
  "tmpname",
}

--- Create a new LuaInterpreter instance
-- @param engine Engine instance for hook access
-- @param config table Optional configuration (deprecation_warnings, strict_api, game_state)
-- @return LuaInterpreter instance
function LuaInterpreter.new(engine, config)
  local self = setmetatable({}, LuaInterpreter)
  self.engine = engine
  self.config = config or {}
  self.game_state = self.config.game_state  -- GAP-007: Store game_state reference
  self.env = {}
  self.output_buffer = {}  -- GAP-008: Buffer for print output
  self._random_seed = nil
  self:init_sandbox_env()       -- GAP-008: Initialize sandbox first
  self:init_whisker_namespace()
  self:init_whisker_globals()   -- GAP-007: Add visited() and other globals
  self:init_pick_function()
  return self
end

--- GAP-007: Set the game state (for deferred initialization)
-- @param game_state GameState instance
function LuaInterpreter:set_game_state(game_state)
  self.game_state = game_state
  -- Re-initialize globals that depend on game_state
  self:init_whisker_globals()
end

--- GAP-008: Initialize the sandbox environment with safe functions only
function LuaInterpreter:init_sandbox_env()
  -- Copy safe globals
  for _, name in ipairs(self.SAFE_GLOBALS) do
    if _G[name] ~= nil then
      self.env[name] = _G[name]
    end
  end

  -- Copy safe modules entirely
  for _, mod_name in ipairs(self.SAFE_MODULES) do
    if _G[mod_name] then
      self.env[mod_name] = {}
      for k, v in pairs(_G[mod_name]) do
        self.env[mod_name][k] = v
      end
    end
  end

  -- Copy partial modules (only safe functions)
  for mod_name, safe_funcs in pairs(self.PARTIAL_MODULES) do
    if _G[mod_name] then
      self.env[mod_name] = self.env[mod_name] or {}
      for _, func_name in ipairs(safe_funcs) do
        if _G[mod_name][func_name] then
          self.env[mod_name][func_name] = _G[mod_name][func_name]
        end
      end
    end
  end

  -- Add blocked function stubs with clear error messages
  self:add_blocked_function_stubs()

  -- Add safe print that redirects to output buffer
  local interpreter = self
  self.env.print = function(...)
    interpreter:handle_print(...)
  end

  -- Add safe getmetatable (only works on user tables)
  self.env.getmetatable = function(obj)
    local mt = getmetatable(obj)
    if mt then
      local custom = rawget(mt, "__metatable")
      if custom then
        if custom == "protected" then
          return nil
        end
        return custom
      end
    end
    -- For user tables, allow metatable access
    if type(obj) == "table" then
      return mt
    end
    return nil
  end

  -- Add safe setmetatable (only works on user tables)
  self.env.setmetatable = function(t, mt)
    if type(t) ~= "table" then
      error("setmetatable can only be used on tables", 2)
    end
    local existing = getmetatable(t)
    if existing and type(existing) == "table" and rawget(existing, "__metatable") then
      error("cannot change a protected metatable", 2)
    end
    return setmetatable(t, mt)
  end

  -- Add rawget, rawset, rawlen for table manipulation (safe)
  self.env.rawget = rawget
  self.env.rawset = rawset
  self.env.rawlen = rawlen
end

--- GAP-008: Add stubs for blocked functions with clear error messages
function LuaInterpreter:add_blocked_function_stubs()
  -- Helper to create blocked function stub
  local function blocked_message(name)
    return function()
      error("Function '" .. name .. "' is not available in Whisker scripts for security reasons", 2)
    end
  end

  -- Add blocked global function stubs
  for _, name in ipairs(self.BLOCKED_FUNCTIONS) do
    self.env[name] = blocked_message(name)
  end

  -- Add blocked module stubs
  for _, mod_name in ipairs(self.BLOCKED_MODULES) do
    self.env[mod_name] = setmetatable({}, {
      __index = function(_, key)
        error("Module '" .. mod_name .. "' is not available in Whisker scripts for security reasons", 2)
      end,
      __call = function()
        error("Module '" .. mod_name .. "' is not available in Whisker scripts for security reasons", 2)
      end,
    })
  end

  -- Add blocked os function stubs (os module already has safe functions)
  if self.env.os then
    for _, func_name in ipairs(self.BLOCKED_OS_FUNCTIONS) do
      self.env.os[func_name] = blocked_message("os." .. func_name)
    end
  end
end

--- GAP-008: Handle print output (redirect to buffer)
-- @param ... Print arguments
function LuaInterpreter:handle_print(...)
  local args = {...}
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(args[i])
  end
  local message = table.concat(parts, "\t")
  table.insert(self.output_buffer, message)
end

--- GAP-008: Get and clear the output buffer
-- @return string Collected output
function LuaInterpreter:flush_output()
  local output = table.concat(self.output_buffer, "\n")
  self.output_buffer = {}
  return output
end

--- GAP-007 & GAP-070: Initialize Whisker-specific global functions
function LuaInterpreter:init_whisker_globals()
  local interpreter = self

  -- GAP-007 & GAP-070: visited() global function
  -- Returns the number of times a passage has been visited
  self.env.visited = function(passage_name)
    if type(passage_name) ~= "string" then
      error("visited() requires a string passage name", 2)
    end
    if interpreter.game_state then
      return interpreter.game_state:get_visit_count(passage_name) or 0
    end
    return 0
  end

  -- GAP-007: visits() as alias for visited() for compatibility
  self.env.visits = self.env.visited

  -- GAP-070: hasVisited() convenience function
  -- Returns true if passage has been visited at least once
  self.env.hasVisited = function(passage_name)
    return interpreter.env.visited(passage_name) > 0
  end

  -- random() utility function with flexible signature
  self.env.random = function(min, max)
    if min and max then
      return math.random(min, max)
    elseif min then
      return math.random(min)
    else
      return math.random()
    end
  end

  -- turns() utility function - returns current turn number
  self.env.turns = function()
    if interpreter.game_state and interpreter.game_state.get_turn_count then
      return interpreter.game_state:get_turn_count() or 0
    end
    return 0
  end

  -- current() utility function - returns current passage name
  self.env.current = function()
    if interpreter.game_state then
      return interpreter.game_state:get_current_passage()
    end
    return nil
  end

  -- previous() utility function - returns previous passage name
  self.env.previous = function()
    if interpreter.game_state and interpreter.game_state.get_previous_passage then
      return interpreter.game_state:get_previous_passage()
    end
    return nil
  end
end

--- Set the random seed for reproducible pick() results
-- @param seed number The seed value
function LuaInterpreter:set_random_seed(seed)
  self._random_seed = seed
  math.randomseed(seed)
end

--- Get the current random seed
-- @return number|nil The current seed or nil if not set
function LuaInterpreter:get_random_seed()
  return self._random_seed
end

--- Initialize the pick() function (GAP-018)
function LuaInterpreter:init_pick_function()
  local interpreter = self

  --- pick() - Select random element(s) from a list
  ---@param list table The list to pick from
  ---@param count number|nil Number of elements to pick (default 1)
  ---@param allow_repeat boolean|nil Allow repeated picks (default false)
  ---@return any|table Single element if count=1, else array
  self.env.pick = function(list, count, allow_repeat)
    if list == nil then
      error("pick() requires a list argument", 2)
    end

    if type(list) ~= "table" then
      error("pick() argument must be a table/list", 2)
    end

    if #list == 0 then
      return nil
    end

    count = count or 1
    allow_repeat = allow_repeat or false

    if count == 1 then
      -- Single pick: return element directly
      local idx = math.random(1, #list)
      return list[idx]
    else
      -- Multiple picks: return array
      local result = {}

      if allow_repeat then
        -- With repetition: simple random picks
        for i = 1, count do
          local idx = math.random(1, #list)
          table.insert(result, list[idx])
        end
      else
        -- Without repetition: Fisher-Yates partial shuffle
        local actual_count = math.min(count, #list)

        -- Create copy to avoid modifying original
        local copy = {}
        for i, v in ipairs(list) do
          copy[i] = v
        end

        for i = 1, actual_count do
          local j = math.random(i, #copy)
          copy[i], copy[j] = copy[j], copy[i]
          table.insert(result, copy[i])
        end
      end

      return result
    end
  end

  -- Also alias in whisker namespace
  self.env.whisker = self.env.whisker or {}
  self.env.whisker.pick = self.env.pick

  -- GAP-071: pickWeighted() - Select random element with weighted probability
  ---@param items table The list of items to pick from
  ---@param weights table Weights for each item
  ---@return any Selected item
  self.env.pickWeighted = function(items, weights)
    if type(items) ~= "table" or #items == 0 then
      return nil
    end

    if not weights then
      -- Equal weights
      return items[math.random(#items)]
    end

    -- Calculate total weight
    local total = 0
    for i, w in ipairs(weights) do
      total = total + (w or 1)
    end

    -- Pick based on weight
    local r = math.random() * total
    local cumulative = 0
    for i, w in ipairs(weights) do
      cumulative = cumulative + (w or 1)
      if r <= cumulative then
        return items[i]
      end
    end

    -- Fallback
    return items[#items]
  end

  -- GAP-071: shuffle() - Return shuffled copy of array
  ---@param items table The list to shuffle
  ---@return table Shuffled copy
  self.env.shuffle = function(items)
    if type(items) ~= "table" then
      error("shuffle() requires a table argument", 2)
    end

    -- Copy array
    local result = {}
    for i, v in ipairs(items) do
      result[i] = v
    end

    -- Fisher-Yates shuffle
    for i = #result, 2, -1 do
      local j = math.random(i)
      result[i], result[j] = result[j], result[i]
    end

    return result
  end

  -- Aliases in whisker namespace
  self.env.whisker.pickWeighted = self.env.pickWeighted
  self.env.whisker.shuffle = self.env.shuffle
end

--- Initialize the whisker namespace with hook API
function LuaInterpreter:init_whisker_namespace()
  local engine = self.engine
  local interpreter = self

  -- Helper function for isVisible (GAP-069)
  local function check_is_visible(hook_name)
    if type(hook_name) ~= "string" then
      error("whisker.hook.isVisible: name must be a string", 2)
    end
    if not engine.current_passage then
      return false
    end

    local hook_id = engine.current_passage.id .. "_" .. hook_name
    local hook = engine.hook_manager:get_hook(hook_id)

    return hook and hook.visible or false
  end

  self.env.whisker = {
    hook = {
      -- GAP-069: Primary API (spec-compliant)
      ---Check if a hook is visible in the current passage
      ---@param hook_name string Hook name (without passage prefix)
      ---@return boolean True if hook exists and is visible
      isVisible = check_is_visible,

      -- GAP-069: Deprecated alias for backward compatibility
      ---@deprecated Use isVisible instead
      ---@param hook_name string Hook name (without passage prefix)
      ---@return boolean True if hook exists and is visible
      visible = function(hook_name)
        -- Check strict mode
        if interpreter.config and interpreter.config.strict_api then
          error("whisker.hook.visible() is deprecated. Use whisker.hook.isVisible() instead.", 2)
        end

        -- Warn once per hook name
        if not deprecation_warned[hook_name] then
          deprecation_warned[hook_name] = true
          -- Log deprecation warning if enabled
          if not interpreter.config or interpreter.config.deprecation_warnings ~= false then
            io.stderr:write(string.format(
              "[DEPRECATION] whisker.hook.visible('%s') is deprecated. " ..
              "Use whisker.hook.isVisible('%s') instead.\n",
              hook_name or "", hook_name or ""
            ))
          end
        end

        -- Call the primary function
        return check_is_visible(hook_name)
      end,

      ---Check if a hook's content contains specific text
      ---@param hook_name string Hook name
      ---@param text string Text to search for
      ---@return boolean True if hook contains text
      contains = function(hook_name, text)
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local hook = engine.hook_manager:get_hook(hook_id)

        if not hook or not hook.visible then
          return false
        end

        return hook.current_content:find(text, 1, true) ~= nil
      end,

      ---Get the current content of a hook
      ---@param hook_name string Hook name
      ---@return string|nil Hook content, or nil if not found/hidden
      get = function(hook_name)
        if not engine.current_passage then
          return nil
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local hook = engine.hook_manager:get_hook(hook_id)

        if not hook or not hook.visible then
          return nil
        end

        return hook.current_content
      end,

      ---Check if hook exists (regardless of visibility)
      ---@param hook_name string Hook name
      ---@return boolean True if hook exists
      exists = function(hook_name)
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        return engine.hook_manager:get_hook(hook_id) ~= nil
      end,

      ---Check if hook is hidden
      ---@param hook_name string Hook name
      ---@return boolean True if hook exists and is hidden
      hidden = function(hook_name)
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local hook = engine.hook_manager:get_hook(hook_id)

        return hook and not hook.visible or false
      end,

      ---Get hook content as a number (for HP, counters, etc.)
      ---@param hook_name string Hook name
      ---@return number|nil Numeric value, or nil if invalid
      number = function(hook_name)
        if not engine.current_passage then
          return nil
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local hook = engine.hook_manager:get_hook(hook_id)

        if not hook or not hook.visible then
          return nil
        end

        return tonumber(hook.current_content)
      end,

      -- Mutation Functions (M4: Expose whisker.hook mutation API)

      ---Replace hook content entirely
      ---@param hook_name string Hook name
      ---@param content string New content
      ---@return boolean True if successful
      replace = function(hook_name, content)
        if type(hook_name) ~= "string" then
          error("whisker.hook.replace: name must be a string", 2)
        end
        if type(content) ~= "string" then
          error("whisker.hook.replace: content must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local success, err = engine.hook_manager:replace_hook(hook_id, content)
        return success
      end,

      ---Append content to hook
      ---@param hook_name string Hook name
      ---@param content string Content to append
      ---@return boolean True if successful
      append = function(hook_name, content)
        if type(hook_name) ~= "string" then
          error("whisker.hook.append: name must be a string", 2)
        end
        if type(content) ~= "string" then
          error("whisker.hook.append: content must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local success, err = engine.hook_manager:append_hook(hook_id, content)
        return success
      end,

      ---Prepend content to hook
      ---@param hook_name string Hook name
      ---@param content string Content to prepend
      ---@return boolean True if successful
      prepend = function(hook_name, content)
        if type(hook_name) ~= "string" then
          error("whisker.hook.prepend: name must be a string", 2)
        end
        if type(content) ~= "string" then
          error("whisker.hook.prepend: content must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local success, err = engine.hook_manager:prepend_hook(hook_id, content)
        return success
      end,

      ---Show a hidden hook
      ---@param hook_name string Hook name
      ---@return boolean True if successful
      show = function(hook_name)
        if type(hook_name) ~= "string" then
          error("whisker.hook.show: name must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local success, err = engine.hook_manager:show_hook(hook_id)
        return success
      end,

      ---Hide a visible hook
      ---@param hook_name string Hook name
      ---@return boolean True if successful
      hide = function(hook_name)
        if type(hook_name) ~= "string" then
          error("whisker.hook.hide: name must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local success, err = engine.hook_manager:hide_hook(hook_id)
        return success
      end,

      -- GAP-019: Clear hook content (different from hide)
      ---Clear a hook's content to empty string
      ---@param hook_name string Hook name
      ---@return boolean True if successful
      clear = function(hook_name)
        if type(hook_name) ~= "string" then
          error("whisker.hook.clear: name must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local success, err = engine.hook_manager:clear_hook(hook_id)
        return success
      end,

      -- GAP-019: Check if hook was cleared
      ---Check if hook was explicitly cleared (not just empty)
      ---@param hook_name string Hook name
      ---@return boolean True if hook was cleared
      isCleared = function(hook_name)
        if type(hook_name) ~= "string" then
          error("whisker.hook.isCleared: name must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        return engine.hook_manager:is_cleared(hook_id)
      end,

      -- GAP-073: Reset hook to original content
      ---Reset hook to original content
      ---@param hook_name string Hook name
      ---@return boolean True if successful
      reset = function(hook_name)
        if type(hook_name) ~= "string" then
          error("whisker.hook.reset: name must be a string", 2)
        end
        if not engine.current_passage then
          return false
        end

        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local success, err = engine.hook_manager:reset_hook(hook_id)
        return success
      end,

      -- ================================================================
      -- GAP-072: Hook All Implementation - Bulk Operations Namespace
      -- ================================================================
      all = {
        ---Hide all hooks in current passage
        ---@param pattern string|nil Optional name pattern
        ---@return number Count of hooks hidden
        hide = function(pattern)
          if not engine.current_passage then
            return 0
          end
          return engine.hook_manager:hide_all(
            engine.current_passage.id,
            pattern
          )
        end,

        ---Show all hooks in current passage
        ---@param pattern string|nil Optional name pattern
        ---@return number Count of hooks shown
        show = function(pattern)
          if not engine.current_passage then
            return 0
          end
          return engine.hook_manager:show_all(
            engine.current_passage.id,
            pattern
          )
        end,

        ---Replace content of all hooks
        ---@param content string New content
        ---@param pattern string|nil Optional name pattern
        ---@return number Count of hooks replaced
        replace = function(content, pattern)
          if type(content) ~= "string" then
            error("whisker.hook.all.replace: content must be a string", 2)
          end
          if not engine.current_passage then
            return 0
          end
          return engine.hook_manager:replace_all(
            engine.current_passage.id,
            content,
            pattern
          )
        end,

        ---Clear all hooks (set to empty string)
        ---@param pattern string|nil Optional name pattern
        ---@return number Count of hooks cleared
        clear = function(pattern)
          if not engine.current_passage then
            return 0
          end
          return engine.hook_manager:clear_all(
            engine.current_passage.id,
            pattern
          )
        end,

        ---Reset all hooks to original content
        ---@param pattern string|nil Optional name pattern
        ---@return number Count of hooks reset
        reset = function(pattern)
          if not engine.current_passage then
            return 0
          end
          return engine.hook_manager:reset_all(
            engine.current_passage.id,
            pattern
          )
        end,

        ---Iterate over all hooks with callback
        ---@param callback function Function(hook) to call
        ---@param pattern string|nil Optional name pattern
        each = function(callback, pattern)
          if type(callback) ~= "function" then
            error("whisker.hook.all.each: callback must be a function", 2)
          end
          if not engine.current_passage then
            return
          end
          engine.hook_manager:each(
            engine.current_passage.id,
            function(hook)
              -- Wrap hook for safe access
              callback({
                name = hook.name,
                content = hook.current_content,
                visible = hook.visible
              })
            end,
            pattern
          )
        end,

        ---Find hooks matching criteria
        ---@param criteria table { pattern, visible, content_pattern }
        ---@return table Array of hook info
        find = function(criteria)
          if not engine.current_passage then
            return {}
          end
          local hooks = engine.hook_manager:find_hooks(
            engine.current_passage.id,
            criteria or {}
          )
          -- Return safe copies
          local results = {}
          for _, hook in ipairs(hooks) do
            table.insert(results, {
              name = hook.name,
              content = hook.current_content,
              visible = hook.visible
            })
          end
          return results
        end
      }
    }
  }
end

-- Helper function for Lua version compatible code loading with environment
-- Lua 5.2+ uses load(chunk, chunkname, mode, env)
-- Lua 5.1/LuaJIT uses loadstring + setfenv
local function load_with_env(code, chunkname, env)
  if setfenv then
    -- Lua 5.1/LuaJIT path
    local func, err = loadstring(code, chunkname)
    if func then
      setfenv(func, env)
    end
    return func, err
  else
    -- Lua 5.2+ path
    return load(code, chunkname, "t", env)
  end
end

--- Evaluate a Lua expression in the whisker environment
-- @param code string Lua code to evaluate
-- @return any Result of evaluation, or nil if error
-- @return string|nil Error message if evaluation failed
function LuaInterpreter:eval(code)
  -- Create a function from the code using "t" mode (text only, no bytecode)
  -- Use load_with_env for Lua 5.1/LuaJIT compatibility
  local func, err = load_with_env(code, "whisker_eval", self.env)

  if not func then
    return nil, "Lua syntax error: " .. tostring(err)
  end

  -- Execute the function with pcall for safety
  local success, result = pcall(func)

  if not success then
    return nil, "Lua runtime error: " .. tostring(result)
  end

  return result
end

--- Execute Lua code (alias for eval)
-- @param code string Lua code to execute
-- @return any Result of execution
-- @return string|nil Error message if execution failed
function LuaInterpreter:execute(code)
  return self:eval(code)
end

--- Set a variable in the sandbox environment
-- @param name string Variable name
-- @param value any Variable value
function LuaInterpreter:set_variable(name, value)
  self.env[name] = value
end

--- Get a variable from the sandbox environment
-- @param name string Variable name
-- @return any Variable value or nil
function LuaInterpreter:get_variable(name)
  return self.env[name]
end

--- Append output to buffer (for inline Lua blocks)
-- @param text string Text to append
function LuaInterpreter:append_output(text)
  table.insert(self.output_buffer, tostring(text))
end

--- GAP-008: Check if a function name is blocked
-- @param name string Function name to check
-- @return boolean True if function is blocked
function LuaInterpreter:is_blocked(name)
  for _, blocked in ipairs(self.BLOCKED_FUNCTIONS) do
    if name == blocked then
      return true
    end
  end
  for _, blocked in ipairs(self.BLOCKED_MODULES) do
    if name == blocked then
      return true
    end
  end
  return false
end

--- GAP-008: Get sandbox configuration for inspection/testing
-- @return table Sandbox configuration
function LuaInterpreter:get_sandbox_config()
  return {
    safe_globals = self.SAFE_GLOBALS,
    safe_modules = self.SAFE_MODULES,
    partial_modules = self.PARTIAL_MODULES,
    blocked_functions = self.BLOCKED_FUNCTIONS,
    blocked_modules = self.BLOCKED_MODULES,
    blocked_os_functions = self.BLOCKED_OS_FUNCTIONS,
  }
end

--- Build a safe evaluation environment with game state variables
-- GAP-002: Expression evaluation environment
-- @param game_state table The game state for variable access
-- @param context table Optional additional context
-- @return table The evaluation environment
function LuaInterpreter:build_environment(game_state, context)
  -- Start with the sandbox environment
  local env = {}
  for k, v in pairs(self.env) do
    env[k] = v
  end
  context = context or {}

  -- Add all story variables from game state
  if game_state then
    -- Add regular variables
    if game_state.get_all_variables then
      for k, v in pairs(game_state:get_all_variables()) do
        env[k] = v
      end
    elseif game_state.variables then
      for k, v in pairs(game_state.variables) do
        env[k] = v
      end
    end
    -- Add temp variables with underscore prefix for direct access
    if game_state.get_all_temp_variables then
      for k, v in pairs(game_state:get_all_temp_variables()) do
        env["_" .. k] = v
      end
    elseif game_state.temp_variables then
      for k, v in pairs(game_state.temp_variables) do
        env["_" .. k] = v
      end
    end
  end

  -- GAP-003: Expose WLS truthiness functions to authors
  env.whisker = env.whisker or {}
  env.whisker.is_truthy = Utils.is_truthy
  env.whisker.is_falsy = Utils.is_falsy
  env.truthy = Utils.is_truthy
  env.falsy = Utils.is_falsy

  -- Add context-specific functions
  if context.visited then
    env.visited = context.visited
  end
  if context.pick then
    env.pick = context.pick
  end
  if context.random then
    env.random = context.random
  end

  -- Add story/engine context functions
  if context.story then
    env._story = context.story
  end

  return env
end

--- Transform WLS expression syntax to Lua
-- Handles ternary operator and other WLS-specific syntax
-- GAP-002: Expression transformation
-- @param expr string The WLS expression
-- @return string The transformed Lua expression
function LuaInterpreter:transform_expression(expr)
  local result = expr

  -- Transform ternary operator: a ? b : c -> (truthy(a) and (b) or (c))
  -- This handles WLS truthiness for ternary conditions
  -- Simple transform for non-nested ternaries
  result = result:gsub("([^?]+)%?([^:]+):(.+)", function(cond, t, f)
    -- Use truthy() for WLS-compliant boolean evaluation
    return string.format("((truthy(%s)) and (%s) or (%s))", cond, t, f)
  end)

  return result
end

--- Evaluate an expression string
-- GAP-002: Expression interpolation support
-- @param expr string The expression to evaluate
-- @param game_state table The game state for variable access
-- @param context table Optional additional context
-- @return boolean success True if evaluation succeeded
-- @return any|nil result The result of evaluation, or nil on error
function LuaInterpreter:evaluate_expression(expr, game_state, context)
  -- Handle empty expression
  if not expr or expr == "" then
    return false, nil
  end

  -- Build evaluation environment
  local env = self:build_environment(game_state, context or {})

  -- Transform WLS operators to Lua
  local lua_expr = self:transform_expression(expr)

  -- Compile and execute (use load_with_env for Lua 5.1/LuaJIT compatibility)
  local chunk, err = load_with_env("return " .. lua_expr, "expr", env)
  if not chunk then
    return false, nil
  end

  local pcall_success, result = pcall(chunk)
  if not pcall_success then
    return false, nil
  end

  return true, result
end

--- Evaluate a condition expression and return boolean using WLS truthiness
-- GAP-003: WLS-compliant truthiness (0 and "" are falsy)
-- This is the primary method for conditional evaluation in WLS
-- @param condition string The condition expression
-- @param game_state table The game state for variable access
-- @param context table Optional additional context
-- @return boolean success True if evaluation succeeded
-- @return boolean|nil result The WLS-truthiness result, or nil on error
function LuaInterpreter:evaluate_condition(condition, game_state, context)
  -- Nil or empty condition is truthy (no condition means always true)
  if not condition or condition == "" then
    return true, true
  end

  -- Evaluate the expression
  local success, result = self:evaluate_expression(condition, game_state, context)

  if not success then
    -- On error, return false with error info
    return false, nil
  end

  -- Apply WLS truthiness rules to the result
  -- GAP-003: 0 and "" are falsy, unlike Lua native
  return true, Utils.is_truthy(result)
end

--- Execute Lua code with game state context
-- @param code string Lua code to execute
-- @param game_state table Game state for variable access
-- @param context table Additional context (story, engine, etc.)
-- @return boolean success Whether execution succeeded
-- @return any result Result of execution or error message
function LuaInterpreter:execute_code(code, game_state, context)
  -- Create environment with whisker API and game state access
  local env = self:create_execution_env(game_state, context)

  -- Load the code (use load_with_env for Lua 5.1/LuaJIT compatibility)
  local func, err = load_with_env(code, "execute", env)
  if not func then
    return false, err
  end

  -- Execute
  local success, result = pcall(func)
  return success, result
end

--- Create the whisker.state API for script access
-- @param game_state table Game state to wrap
-- @param context table|nil Optional context; if provided, returns full {whisker: {state: ...}} structure
-- @return table api The whisker.state API table (or full nested structure if context provided)
function LuaInterpreter:create_story_api(game_state, context)
  local state_api = {
    get = function(key)
      if game_state.get then
        return game_state:get(key)
      end
      return game_state[key]
    end,
    set = function(key, value)
      if game_state.set then
        return game_state:set(key, value)
      end
      game_state[key] = value
    end,
    has = function(key)
      if game_state.has then
        return game_state:has(key)
      end
      return game_state[key] ~= nil
    end,
    delete = function(key)
      if game_state.delete then
        return game_state:delete(key)
      end
      game_state[key] = nil
    end,
    all = function()
      if game_state.get_all_variables then
        return game_state:get_all_variables()
      end
      return game_state
    end,
    reset = function()
      if game_state.reset then
        return game_state:reset()
      end
    end,
    -- Temp variable support
    get_temp = function(key)
      if game_state.get_temp then
        return game_state:get_temp(key)
      end
      return nil
    end,
    set_temp = function(key, value)
      -- Check if a story variable with the same name exists (prevent shadowing)
      local story_var_exists = false
      if game_state.has then
        story_var_exists = game_state:has(key)
      else
        story_var_exists = game_state[key] ~= nil
      end
      if story_var_exists then
        error("Cannot set temp variable '" .. key .. "': story variable with same name exists (shadowing not allowed)", 2)
      end
      if game_state.set_temp then
        return game_state:set_temp(key, value)
      end
    end,
    has_temp = function(key)
      if game_state.has_temp then
        return game_state:has_temp(key)
      end
      return false
    end
  }

  -- If context is provided, return full nested structure for testing
  if context ~= nil then
    return {
      whisker = {
        state = state_api
      }
    }
  end

  return state_api
end

--- Create execution environment with whisker API
-- @param game_state table Game state
-- @param context table Additional context
-- @return table env Execution environment
function LuaInterpreter:create_execution_env(game_state, context)
  local env = {}

  -- Copy base environment
  for k, v in pairs(self.env) do
    env[k] = v
  end

  -- Add whisker.state API
  env.whisker = env.whisker or {}
  env.whisker.state = self:create_story_api(game_state)

  -- Add whisker.passage API
  env.whisker.passage = {
    current = function()
      if context and context.engine and context.engine.current_passage then
        return context.engine.current_passage
      end
      return nil
    end,
    get = function(passage_id)
      if context and context.story then
        return context.story:get_passage(passage_id)
      end
      return nil
    end,
    exists = function(passage_id)
      if context and context.story then
        return context.story:get_passage(passage_id) ~= nil
      end
      return false
    end,
    all = function()
      if context and context.story then
        local ids = {}
        local passages = context.story:get_all_passages()
        for _, p in ipairs(passages) do
          table.insert(ids, p.id)
        end
        return ids
      end
      return {}
    end,
    tags = function(tag)
      if context and context.story then
        local result = {}
        local passages = context.story:get_all_passages()
        for _, p in ipairs(passages) do
          if p.tags then
            for _, t in ipairs(p.tags) do
              if t == tag then
                table.insert(result, p)
                break
              end
            end
          end
        end
        return result
      end
      return {}
    end,
    go = function(passage_id)
      -- Deferred navigation - store for engine to process
      if context then
        context._pending_navigation = passage_id
      end
    end
  }

  -- Add whisker.history API
  env.whisker.history = {
    canBack = function()
      if context and context.engine and context.engine.history then
        return #context.engine.history > 0
      end
      return false
    end,
    list = function()
      if game_state and game_state.visited_passages then
        local list = {}
        for passage_id, _ in pairs(game_state.visited_passages) do
          table.insert(list, passage_id)
        end
        return list
      end
      return {}
    end,
    count = function()
      if game_state and game_state.visited_passages then
        local count = 0
        for _ in pairs(game_state.visited_passages) do
          count = count + 1
        end
        return count
      end
      return 0
    end,
    contains = function(passage_id)
      if game_state and game_state.visited_passages then
        return game_state.visited_passages[passage_id] ~= nil
      end
      return false
    end,
    clear = function()
      if game_state then
        game_state.visited_passages = {}
      end
    end
  }

  -- Add whisker.choice API
  env.whisker.choice = {
    available = function()
      if context and context.engine and context.engine.current_passage then
        local passage = context.engine.current_passage
        if passage.get_choices then
          return passage:get_choices()
        elseif passage.choices then
          return passage.choices
        end
      end
      return {}
    end,
    count = function()
      local choices = env.whisker.choice.available()
      return #choices
    end,
    select = function(index)
      -- Deferred choice selection
      if context then
        context._pending_choice = index
      end
    end
  }

  -- Add top-level functions

  -- visited() - check visit count for current or specific passage
  env.visited = function(passage_id)
    if passage_id then
      return game_state:get_visit_count(passage_id) or 0
    else
      local current = game_state:get_current_passage()
      return current and (game_state:get_visit_count(current) or 0) or 0
    end
  end

  -- random(max) or random(min, max) - generate random number
  env.random = function(a, b)
    if b then
      return math.random(a, b)
    else
      return math.random(1, a)
    end
  end

  -- pick(...) - pick random from arguments
  env.pick = function(...)
    local args = {...}
    if #args == 0 then return nil end
    return args[math.random(1, #args)]
  end

  -- get(key) - legacy get function
  env.get = function(key)
    if game_state.get then
      return game_state:get(key)
    end
    return game_state[key]
  end

  -- set(key, value) - legacy set function
  env.set = function(key, value)
    if game_state.set then
      game_state:set(key, value)
    else
      game_state[key] = value
    end
  end

  -- has(key) - legacy has function
  env.has = function(key)
    if game_state.has then
      return game_state:has(key)
    end
    return game_state[key] ~= nil
  end

  -- del(key) - legacy delete function
  env.del = function(key)
    if game_state.delete then
      return game_state:delete(key)
    end
    game_state[key] = nil
  end

  -- inc(key, amount) - legacy increment function
  env.inc = function(key, amount)
    amount = amount or 1
    if game_state.increment then
      return game_state:increment(key, amount)
    end
    local current = game_state[key] or 0
    game_state[key] = current + amount
    return game_state[key]
  end

  -- dec(key, amount) - legacy decrement function
  env.dec = function(key, amount)
    amount = amount or 1
    if game_state.decrement then
      return game_state:decrement(key, amount)
    end
    local current = game_state[key] or 0
    game_state[key] = current - amount
    return game_state[key]
  end

  -- Add direct variable access (variables accessible as globals)
  setmetatable(env, {
    __index = function(_, key)
      -- First check if it's a temp variable (prefixed with _)
      if key:sub(1, 1) == "_" and game_state.get_temp then
        local temp_key = key:sub(2)
        local val = game_state:get_temp(temp_key)
        if val ~= nil then return val end
      end
      -- Then check story variables
      if game_state.get then
        local val = game_state:get(key)
        if val ~= nil then return val end
      elseif game_state[key] ~= nil then
        return game_state[key]
      end
      -- Fall back to global environment
      return _G[key]
    end,
    __newindex = function(_, key, value)
      if game_state.set then
        game_state:set(key, value)
      else
        game_state[key] = value
      end
    end
  })

  return env
end

return LuaInterpreter
