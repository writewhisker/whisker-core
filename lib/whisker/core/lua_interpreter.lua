-- lib/whisker/core/lua_interpreter.lua
-- Lua interpreter with whisker.hook API namespace

local LuaInterpreter = {}
LuaInterpreter.__index = LuaInterpreter

--- Create a new LuaInterpreter instance
-- @param engine Engine instance for hook access
-- @return LuaInterpreter instance
function LuaInterpreter.new(engine)
  local self = setmetatable({}, LuaInterpreter)
  self.engine = engine
  self.env = {}
  self:init_whisker_namespace()
  return self
end

--- Initialize the whisker namespace with hook API
function LuaInterpreter:init_whisker_namespace()
  local engine = self.engine
  
  self.env.whisker = {
    hook = {
      ---Check if a hook is visible in the current passage
      ---@param hook_name string Hook name (without passage prefix)
      ---@return boolean True if hook exists and is visible
      visible = function(hook_name)
        if not engine.current_passage then
          return false
        end
        
        local hook_id = engine.current_passage.id .. "_" .. hook_name
        local hook = engine.hook_manager:get_hook(hook_id)
        
        return hook and hook.visible or false
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
      end
    }
  }
end

--- Evaluate a Lua expression in the whisker environment
-- @param code string Lua code to evaluate
-- @return any Result of evaluation, or nil if error
-- @return string|nil Error message if evaluation failed
function LuaInterpreter:eval(code)
  -- Create a function from the code
  local func, err = load(code, "eval", "t", self.env)

  if not func then
    return nil, err
  end

  -- Execute the function
  local success, result = pcall(func)

  if not success then
    return nil, result
  end

  return result
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

  -- Load the code
  local func, err = load(code, "execute", "t", env)
  if not func then
    return false, err
  end

  -- Execute
  local success, result = pcall(func)
  return success, result
end

--- Evaluate an expression and return the result
-- @param expr string Expression to evaluate
-- @param game_state table Game state for variable access
-- @return boolean success Whether evaluation succeeded
-- @return any result Result of evaluation or error message
function LuaInterpreter:evaluate_expression(expr, game_state)
  local env = self:create_execution_env(game_state, {})

  local func, err = load("return " .. expr, "expr", "t", env)
  if not func then
    return false, err
  end

  local success, result = pcall(func)
  return success, result
end

--- Evaluate a condition and return boolean result
-- @param expr string Condition expression
-- @param game_state table Game state for variable access
-- @return boolean success Whether evaluation succeeded
-- @return boolean|string result Boolean result or error message
function LuaInterpreter:evaluate_condition(expr, game_state)
  local success, result = self:evaluate_expression(expr, game_state)
  if not success then
    return false, result
  end
  return true, not not result  -- Convert to boolean
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
