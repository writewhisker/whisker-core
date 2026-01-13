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

return LuaInterpreter
