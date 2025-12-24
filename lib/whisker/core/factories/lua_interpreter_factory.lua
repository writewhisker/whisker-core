--- LuaInterpreter Factory
-- Factory implementation for creating LuaInterpreter instances
-- Implements ILuaInterpreterFactory interface
-- @module whisker.core.factories.lua_interpreter_factory
-- @author Whisker Core Team
-- @license MIT

local LuaInterpreter = require("whisker.core.lua_interpreter")

local LuaInterpreterFactory = {}
LuaInterpreterFactory.__index = LuaInterpreterFactory

-- Dependencies for DI pattern (none for LuaInterpreterFactory)
LuaInterpreterFactory._dependencies = {}

--- Create a new LuaInterpreterFactory instance
-- @param deps table|nil Dependencies from container
-- @return LuaInterpreterFactory The factory instance
function LuaInterpreterFactory.new(deps)
  local self = setmetatable({}, LuaInterpreterFactory)
  self._deps = deps or {}
  return self
end

--- Create a new LuaInterpreter instance
-- Implements ILuaInterpreterFactory:create
-- @param config table|nil Interpreter configuration (max_instructions, timeout)
-- @return LuaInterpreter The new interpreter instance
function LuaInterpreterFactory:create(config)
  return LuaInterpreter.new(config)
end

--- Get the LuaInterpreter class (for type checking)
-- @return table The LuaInterpreter class table
function LuaInterpreterFactory:get_class()
  return LuaInterpreter
end

return LuaInterpreterFactory
