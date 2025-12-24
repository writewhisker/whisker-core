--- Vendor Mock Implementations
-- Mock implementations of vendor interfaces for testing
-- @module tests.mocks.vendor_mocks
-- @author Whisker Core Team
-- @license MIT

local M = {}

--- Create a mock JSON codec
-- @param overrides table|nil Method overrides
-- @return IJsonCodec Mock codec
function M.create_mock_json_codec(overrides)
  overrides = overrides or {}

  local mock = {
    _encode_calls = {},
    _decode_calls = {},

    encode = function(self, value, options)
      table.insert(self._encode_calls, { value = value, options = options })
      if overrides.encode then
        return overrides.encode(self, value, options)
      end
      -- Simple JSON encoding for basic types
      if type(value) == "string" then
        return '"' .. value .. '"'
      elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
      elseif type(value) == "nil" then
        return "null"
      elseif type(value) == "table" then
        -- Simple table encoding
        if #value > 0 then
          -- Array
          local parts = {}
          for _, v in ipairs(value) do
            local encoded, _ = self:encode(v)
            table.insert(parts, encoded)
          end
          return "[" .. table.concat(parts, ",") .. "]"
        else
          -- Object
          local parts = {}
          for k, v in pairs(value) do
            local encoded, _ = self:encode(v)
            table.insert(parts, '"' .. tostring(k) .. '":' .. encoded)
          end
          return "{" .. table.concat(parts, ",") .. "}"
        end
      end
      return "{}", nil
    end,

    decode = function(self, json_string, options)
      table.insert(self._decode_calls, { json_string = json_string, options = options })
      if overrides.decode then
        return overrides.decode(self, json_string, options)
      end
      -- Return a simple mock table for testing
      return { _mock = true }, nil
    end,

    get_library_name = function()
      return overrides.library_name or "mock"
    end,

    supports = function(self, feature)
      if overrides.supports then
        return overrides.supports(self, feature)
      end
      return false
    end,

    null = function()
      return overrides.null_value
    end,
  }

  return mock
end

--- Create a mock Ink runtime
-- @param overrides table|nil Method overrides
-- @return IInkRuntime Mock runtime
function M.create_mock_ink_runtime(overrides)
  overrides = overrides or {}

  local mock = {
    _create_story_calls = {},

    create_story = function(self, ink_data)
      table.insert(self._create_story_calls, { ink_data = ink_data })
      if overrides.create_story then
        return overrides.create_story(self, ink_data)
      end
      return M.create_mock_story_wrapper(), nil
    end,

    get_runtime_name = function()
      return overrides.runtime_name or "mock"
    end,

    get_ink_version = function()
      return overrides.ink_version or 21
    end,

    supports = function(self, feature)
      if overrides.supports then
        return overrides.supports(self, feature)
      end
      return true
    end,
  }

  return mock
end

--- Create a mock story wrapper
-- @param overrides table|nil Method overrides
-- @return IStoryWrapper Mock wrapper
function M.create_mock_story_wrapper(overrides)
  overrides = overrides or {}

  local can_continue = true
  local text_queue = overrides.text_queue or { "Hello, World!\n" }
  local current_index = 1
  local choices = overrides.choices or {}

  local mock = {
    -- Track method calls
    _continue_calls = 0,
    _choice_calls = {},

    canContinue = function()
      return can_continue and current_index <= #text_queue
    end,

    Continue = function(self)
      self._continue_calls = self._continue_calls + 1
      if current_index <= #text_queue then
        local text = text_queue[current_index]
        current_index = current_index + 1
        if current_index > #text_queue then
          can_continue = false
        end
        return text
      end
      return ""
    end,

    currentText = function()
      if current_index > 1 and current_index <= #text_queue + 1 then
        return text_queue[current_index - 1]
      end
      return ""
    end,

    currentTags = function()
      return overrides.tags or {}
    end,

    currentChoices = function()
      return choices
    end,

    ChooseChoiceIndex = function(self, index)
      table.insert(self._choice_calls, index)
    end,

    ChoosePathString = function(self, path, reset_callstack)
      self._last_path = path
    end,

    get_state = function()
      return {
        save = function() return {} end,
        load = function() end,
        variablesState = {
          GetVariableWithName = function() return nil end,
          SetVariable = function() end,
          _globalVariables = {},
        },
      }
    end,

    save = function()
      return {}
    end,

    load = function() end,

    ResetState = function()
      can_continue = true
      current_index = 1
    end,

    BindExternalFunction = function() end,
    UnbindExternalFunction = function() end,
    ObserveVariable = function() end,
    RemoveVariableObserver = function() end,

    currentFlowName = function()
      return overrides.flow_name or "DEFAULT"
    end,

    SwitchFlow = function() end,
    RemoveFlow = function() end,

    aliveFlowNames = function()
      return overrides.alive_flows or {}
    end,

    HasFunction = function()
      return false
    end,

    EvaluateFunction = function()
      return nil, ""
    end,

    get_ink_data = function()
      return overrides.ink_data or { inkVersion = 21, root = {} }
    end,

    get_raw_story = function()
      return { _mock = true }
    end,

    GetVariable = function(self, name)
      return nil
    end,

    SetVariable = function(self, name, value)
    end,

    get_variables_state = function()
      return {
        GetVariableWithName = function() return nil end,
        SetVariable = function() end,
        _globalVariables = {},
      }
    end,

    state = {
      save = function() return {} end,
      load = function() end,
      variablesState = {
        GetVariableWithName = function() return nil end,
        SetVariable = function() end,
        _globalVariables = {},
      },
    },
  }

  return mock
end

return M
