--- Tinta Loader for Whisker-Core
-- Loads the tinta Ink runtime with proper path setup
-- @module whisker.vendor.tinta
-- @author Whisker Core Team
-- @license MIT

local M = {}

-- Get the directory where this file is located
local function get_tinta_path()
  local info = debug.getinfo(1, "S")
  local source = info.source:sub(2) -- Remove '@' prefix
  return source:match("(.-)[^/]+$") .. "source/"
end

-- Store original package.path
local original_path = package.path
local tinta_path = get_tinta_path()

-- Setup tinta's module path
local function setup_path()
  package.path = tinta_path .. "?.lua;" ..
                 tinta_path .. "?/init.lua;" ..
                 package.path
end

-- Restore original path
local function restore_path()
  package.path = original_path
end

-- Global import function that tinta expects
local function create_import(base_path)
  return function(module_name)
    -- Handle relative paths
    if module_name:match("^%.%.") then
      module_name = module_name:gsub("^%.%./", "")
    end
    -- Convert path to require format
    local require_path = module_name:gsub("/", ".")
    return require(require_path)
  end
end

-- Load tinta with proper environment
local function load_tinta()
  setup_path()

  -- Tinta uses global 'import' - set it up
  local old_import = _G.import
  _G.import = create_import(tinta_path)

  -- Load compatibility layer
  if _VERSION == "Lua 5.1" then
    _G.compat = require("compat.lua51")
  else
    _G.compat = require("compat.lua54")
  end

  -- Load dump for debugging
  _G.dump = require("libs.dump")

  -- Load lume utilities (tinta dependency)
  _G.lume = require("libs.lume")

  -- Load serialization
  _G.serialization = require("libs.serialization")

  -- Load delegate utilities
  _G.DelegateUtils = require("libs.delegate")

  -- Load inkutils
  _G.inkutils = require("libs.inkutils")

  -- Load PRNG
  _G.PRNG = require("libs.prng")

  -- Load constants
  _G.PushPopType = require("constants.push_pop_type")
  _G.ControlCommandType = require("constants.control_commands.types")
  _G.ControlCommandName = require("constants.control_commands.names")
  _G.ControlCommandValues = require("constants.control_commands.values")
  _G.NativeFunctionName = require("constants.native_functions.names")

  -- Load values
  _G.BaseValue = require("values.base")
  _G.IntValue = require("values.integer")
  _G.FloatValue = require("values.float")
  _G.StringValue = require("values.string")
  _G.BooleanValue = require("values.boolean")
  _G.Void = require("values.void")
  _G.Glue = require("values.glue")
  _G.Tag = require("values.tag")
  _G.Container = require("values.container")
  _G.Divert = require("values.divert")
  _G.DivertTarget = require("values.divert_target")
  _G.ChoicePoint = require("values.choice_point")
  _G.Choice = require("values.choice")
  _G.VariableAssignment = require("values.variable_assignment")
  _G.VariableReference = require("values.variable_reference")
  _G.VariablePointerValue = require("values.variable_pointer")
  _G.NativeFunctionCall = require("values.native_function")
  _G.ControlCommand = require("values.control_command")
  _G.Path = require("values.path")
  _G.SearchResult = require("values.search_result")

  -- Load list types
  _G.ListItem = require("values.list.list_item")
  _G.InkList = require("values.list.inklist")
  _G.ListValue = require("values.list.list_value")
  _G.ListDefinition = require("values.list.list_definition")
  _G.ListDefinitionOrigin = require("values.list.list_definition_origin")

  -- Load engine components
  _G.Pointer = require("engine.pointer")
  _G.CallStackElement = require("engine.call_stack.element")
  _G.CallStackThread = require("engine.call_stack.thread")
  _G.CallStack = require("engine.call_stack")
  _G.Flow = require("engine.flow")
  _G.StatePatch = require("engine.state_patch")
  _G.VariablesState = require("engine.variables_state")
  _G.StoryState = require("engine.story_state")

  -- Load OOP library
  _G.classic = require("libs.classic")

  -- Finally load Story
  local Story = require("engine.story")

  -- Restore import
  _G.import = old_import

  restore_path()

  return Story
end

-- Lazy load Story class
local Story = nil

--- Get the Story class
-- @return Story The tinta Story class
function M.get_story_class()
  if not Story then
    Story = load_tinta()
  end
  return Story
end

--- Create a new Story from Ink JSON
-- @param json_data table|string Parsed Ink JSON (table) or JSON string
-- @return Story A new Story instance
function M.create_story(json_data)
  local StoryClass = M.get_story_class()

  -- If it's a string, we need to parse it
  if type(json_data) == "string" then
    -- Use a JSON library to parse
    local json = require("cjson") or require("dkjson") or error("No JSON library available")
    json_data = json.decode(json_data)
  end

  return StoryClass(json_data)
end

return M
