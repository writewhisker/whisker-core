--- Vendor Abstraction Interfaces
-- Interfaces for external vendor dependencies (DI pattern)
-- @module whisker.interfaces.vendor
-- @author Whisker Core Team
-- @license MIT

local M = {}

--- IJsonCodec Interface
-- Abstraction for JSON encoding/decoding operations
-- Enables mocking of JSON libraries in tests
-- @table IJsonCodec
M.IJsonCodec = {}

--- Encode a Lua value to JSON string
-- @param value any The Lua value to encode (table, string, number, boolean, nil)
-- @param options table|nil Encoding options
-- @param options.pretty boolean If true, format with indentation
-- @param options.indent number Indentation spaces (default 2)
-- @return string The JSON string
-- @return string|nil Error message if encoding failed
function M.IJsonCodec:encode(value, options)
  error("IJsonCodec:encode must be implemented")
end

--- Decode a JSON string to a Lua value
-- @param json_string string The JSON string to decode
-- @param options table|nil Decoding options
-- @return any The decoded Lua value
-- @return string|nil Error message if decoding failed
function M.IJsonCodec:decode(json_string, options)
  error("IJsonCodec:decode must be implemented")
end

--- Get the name of the underlying JSON library
-- @return string Library name (e.g., "cjson", "dkjson", "json")
function M.IJsonCodec:get_library_name()
  error("IJsonCodec:get_library_name must be implemented")
end

--- Check if this codec supports a feature
-- @param feature string Feature name ("pretty", "null_handling", "sparse_arrays")
-- @return boolean True if the feature is supported
function M.IJsonCodec:supports(feature)
  error("IJsonCodec:supports must be implemented")
end

--- Create a JSON null value
-- Some libraries have special null handling
-- @return any The null value appropriate for this codec
function M.IJsonCodec:null()
  error("IJsonCodec:null must be implemented")
end


--- IInkRuntime Interface
-- Abstraction for Ink story runtime operations
-- Enables mocking of tinta library in tests
-- @table IInkRuntime
M.IInkRuntime = {}

--- Create a new Ink story from parsed JSON data
-- @param ink_data table The parsed Ink JSON structure
-- @return Story The story object
-- @return string|nil Error message if creation failed
function M.IInkRuntime:create_story(ink_data)
  error("IInkRuntime:create_story must be implemented")
end

--- Get the runtime name
-- @return string Runtime name (e.g., "tinta")
function M.IInkRuntime:get_runtime_name()
  error("IInkRuntime:get_runtime_name must be implemented")
end

--- Get supported Ink version
-- @return number The supported Ink JSON version
function M.IInkRuntime:get_ink_version()
  error("IInkRuntime:get_ink_version must be implemented")
end

--- Check if this runtime supports a feature
-- @param feature string Feature name ("flows", "threads", "external_functions", "tunnels")
-- @return boolean True if the feature is supported
function M.IInkRuntime:supports(feature)
  error("IInkRuntime:supports must be implemented")
end


--- IStoryWrapper Interface
-- Wrapper around a running Ink story (returned by IInkRuntime:create_story)
-- Provides a consistent API regardless of underlying runtime
-- @table IStoryWrapper
M.IStoryWrapper = {}

--- Check if the story can continue
-- @return boolean True if there is more content
function M.IStoryWrapper:canContinue()
  error("IStoryWrapper:canContinue must be implemented")
end

--- Continue the story and get next text
-- @return string The next line of text
function M.IStoryWrapper:Continue()
  error("IStoryWrapper:Continue must be implemented")
end

--- Get current text (after Continue was called)
-- @return string Current text content
function M.IStoryWrapper:currentText()
  error("IStoryWrapper:currentText must be implemented")
end

--- Get current tags (after Continue was called)
-- @return table Array of tag strings
function M.IStoryWrapper:currentTags()
  error("IStoryWrapper:currentTags must be implemented")
end

--- Get available choices
-- @return table Array of choice objects with text, tags properties
function M.IStoryWrapper:currentChoices()
  error("IStoryWrapper:currentChoices must be implemented")
end

--- Make a choice by index (1-based in Lua)
-- @param index number The choice index
function M.IStoryWrapper:ChooseChoiceIndex(index)
  error("IStoryWrapper:ChooseChoiceIndex must be implemented")
end

--- Navigate to a specific path
-- @param path string The story path (e.g., "knot.stitch")
-- @param reset_callstack boolean|nil Whether to reset the callstack
function M.IStoryWrapper:ChoosePathString(path, reset_callstack)
  error("IStoryWrapper:ChoosePathString must be implemented")
end

--- Get the story state for save/load
-- @return table The story state object
function M.IStoryWrapper:get_state()
  error("IStoryWrapper:get_state must be implemented")
end

--- Reset the story to initial state
function M.IStoryWrapper:ResetState()
  error("IStoryWrapper:ResetState must be implemented")
end

--- Bind an external function
-- @param name string Function name
-- @param fn function The function to call
-- @param lookahead_safe boolean Whether function is safe during lookahead
function M.IStoryWrapper:BindExternalFunction(name, fn, lookahead_safe)
  error("IStoryWrapper:BindExternalFunction must be implemented")
end

--- Unbind an external function
-- @param name string Function name
function M.IStoryWrapper:UnbindExternalFunction(name)
  error("IStoryWrapper:UnbindExternalFunction must be implemented")
end

--- Observe variable changes
-- @param name string Variable name or "*" for all
-- @param callback function Callback(name, value)
function M.IStoryWrapper:ObserveVariable(name, callback)
  error("IStoryWrapper:ObserveVariable must be implemented")
end

--- Remove a variable observer
-- @param callback function The callback to remove
-- @param name string|nil Variable name
function M.IStoryWrapper:RemoveVariableObserver(callback, name)
  error("IStoryWrapper:RemoveVariableObserver must be implemented")
end

--- Get current flow name
-- @return string Current flow name
function M.IStoryWrapper:currentFlowName()
  error("IStoryWrapper:currentFlowName must be implemented")
end

--- Switch to a different flow
-- @param flow_name string Flow name
function M.IStoryWrapper:SwitchFlow(flow_name)
  error("IStoryWrapper:SwitchFlow must be implemented")
end

--- Remove a flow
-- @param flow_name string Flow name
function M.IStoryWrapper:RemoveFlow(flow_name)
  error("IStoryWrapper:RemoveFlow must be implemented")
end

--- Get all alive flow names
-- @return table Array of flow names
function M.IStoryWrapper:aliveFlowNames()
  error("IStoryWrapper:aliveFlowNames must be implemented")
end

--- Check if a function exists
-- @param name string Function name
-- @return boolean True if exists
function M.IStoryWrapper:HasFunction(name)
  error("IStoryWrapper:HasFunction must be implemented")
end

--- Evaluate an Ink function
-- @param function_name string Function name
-- @param args table Array of arguments
-- @return any Return value
-- @return string Text output
function M.IStoryWrapper:EvaluateFunction(function_name, args)
  error("IStoryWrapper:EvaluateFunction must be implemented")
end


return M
