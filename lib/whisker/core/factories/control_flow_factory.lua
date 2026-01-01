-- lib/whisker/core/factories/control_flow_factory.lua
-- Factory for ControlFlow instances

local ControlFlow = require("whisker.core.control_flow")

local ControlFlowFactory = {}
ControlFlowFactory.__index = ControlFlowFactory
ControlFlowFactory._dependencies = {}

function ControlFlowFactory.new(deps)
    local self = setmetatable({}, ControlFlowFactory)
    self._deps = deps or {}
    return self
end

--- Create a new ControlFlow instance
---@param interpreter table The Lua interpreter
---@param game_state table The game state
---@param context table Optional context
---@return ControlFlow
function ControlFlowFactory:create(interpreter, game_state, context)
    return ControlFlow.new(interpreter, game_state, context)
end

--- Get the ControlFlow class for direct access
---@return table ControlFlow class
function ControlFlowFactory:get_class()
    return ControlFlow
end

return ControlFlowFactory
