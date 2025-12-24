--- Ink Runtime Unit Tests
-- Tests for InkRuntime implementation
-- @module tests.unit.vendor.ink_runtime_spec
-- @author Whisker Core Team
-- @license MIT

describe("InkRuntime", function()
  local InkRuntime = require("whisker.vendor.runtimes.ink_runtime")
  local JsonCodec = require("whisker.vendor.codecs.json_codec")
  local runtime

  before_each(function()
    runtime = InkRuntime.new({
      json_codec = JsonCodec.new(),
    })
  end)

  describe("new", function()
    it("creates a new instance", function()
      assert.is_table(runtime)
    end)

    it("accepts optional dependencies", function()
      local mock_codec = JsonCodec.new()
      local mock_logger = { debug = function() end }
      local r = InkRuntime.new({
        json_codec = mock_codec,
        logger = mock_logger,
      })
      assert.equal(mock_codec, r.json_codec)
      assert.equal(mock_logger, r.log)
    end)
  end)

  describe("create", function()
    it("creates instance via container pattern", function()
      local mock_container = {
        has = function(_, name)
          return name == "json_codec" or name == "logger"
        end,
        resolve = function(_, name)
          if name == "json_codec" then
            return JsonCodec.new()
          elseif name == "logger" then
            return { debug = function() end }
          end
        end,
      }
      local instance = InkRuntime.create(mock_container)
      assert.is_table(instance)
    end)

    it("works without container", function()
      local instance = InkRuntime.create(nil)
      assert.is_table(instance)
    end)
  end)

  describe("get_runtime_name", function()
    it("returns tinta", function()
      assert.equal("tinta", runtime:get_runtime_name())
    end)
  end)

  describe("get_ink_version", function()
    it("returns supported version number", function()
      local version = runtime:get_ink_version()
      assert.is_number(version)
      assert.equal(21, version)
    end)
  end)

  describe("supports", function()
    it("returns true for supported features", function()
      assert.is_true(runtime:supports("flows"))
      assert.is_true(runtime:supports("threads"))
      assert.is_true(runtime:supports("external_functions"))
      assert.is_true(runtime:supports("tunnels"))
      assert.is_true(runtime:supports("lists"))
      assert.is_true(runtime:supports("variable_observers"))
    end)

    it("returns false for unsupported features", function()
      assert.is_false(runtime:supports("unknown_feature"))
    end)
  end)

  describe("is_available", function()
    it("returns boolean", function()
      local available = runtime:is_available()
      assert.is_boolean(available)
    end)
  end)

  describe("create_story", function()
    -- Note: Full story creation tests require tinta to be properly initialized.
    -- These tests verify error handling without requiring full tinta setup.

    it("returns error for invalid JSON", function()
      local story, err = runtime:create_story("{invalid")
      assert.is_nil(story)
      assert.is_string(err)
    end)

    it("returns error for missing inkVersion", function()
      local story, err = runtime:create_story('{"root":[]}')
      assert.is_nil(story)
      assert.is_string(err)
      assert.is_truthy(err:find("inkVersion"))
    end)

    it("returns error for non-table input", function()
      local story, err = runtime:create_story(12345)
      assert.is_nil(story)
      assert.is_string(err)
    end)
  end)

  describe("IInkRuntime interface compliance", function()
    local IInkRuntime = require("whisker.interfaces.vendor").IInkRuntime

    it("implements create_story", function()
      assert.is_function(runtime.create_story)
    end)

    it("implements get_runtime_name", function()
      assert.is_function(runtime.get_runtime_name)
    end)

    it("implements get_ink_version", function()
      assert.is_function(runtime.get_ink_version)
    end)

    it("implements supports", function()
      assert.is_function(runtime.supports)
    end)
  end)
end)

describe("StoryWrapper", function()
  local StoryWrapper = require("whisker.vendor.runtimes.story_wrapper")
  local wrapper

  -- Mock raw tinta story for testing
  local function create_mock_story()
    local mock_text = "Hello, World!\n"
    local mock_tags = {}
    local mock_can_continue = true

    return {
      canContinue = function() return mock_can_continue end,
      Continue = function()
        mock_can_continue = false
        return mock_text
      end,
      currentText = function() return mock_text end,
      currentTags = function() return mock_tags end,
      currentChoices = function() return {} end,
      ChooseChoiceIndex = function() end,
      ChoosePathString = function() end,
      ResetState = function() mock_can_continue = true end,
      BindExternalFunction = function() end,
      UnbindExternalFunction = function() end,
      ObserveVariable = function() end,
      RemoveVariableObserver = function() end,
      currentFlowName = function() return "DEFAULT" end,
      SwitchFlow = function() end,
      RemoveFlow = function() end,
      aliveFlowNames = function() return {} end,
      HasFunction = function() return false end,
      EvaluateFunction = function() return nil, "" end,
      state = {
        save = function() return {} end,
        load = function() end,
        variablesState = {
          GetVariableWithName = function() return nil end,
          SetVariable = function() end,
        },
      },
    }
  end

  local mock_ink_data = { inkVersion = 21, root = {} }

  before_each(function()
    wrapper = StoryWrapper.new(create_mock_story(), mock_ink_data, nil)
  end)

  describe("new", function()
    it("creates a new instance", function()
      assert.is_table(wrapper)
    end)

    it("stores ink data", function()
      assert.is_table(wrapper._ink_data)
      assert.equal(21, wrapper._ink_data.inkVersion)
    end)
  end)

  describe("canContinue", function()
    it("delegates to raw story", function()
      assert.is_true(wrapper:canContinue())
    end)
  end)

  describe("Continue", function()
    it("returns text content", function()
      local text = wrapper:Continue()
      assert.is_string(text)
      assert.is_truthy(text:find("Hello"))
    end)
  end)

  describe("currentText", function()
    it("returns current text", function()
      wrapper:Continue()
      local text = wrapper:currentText()
      assert.is_string(text)
    end)
  end)

  describe("currentTags", function()
    it("returns table of tags", function()
      wrapper:Continue()
      local tags = wrapper:currentTags()
      assert.is_table(tags)
    end)
  end)

  describe("currentChoices", function()
    it("returns table of choices", function()
      wrapper:Continue()
      local choices = wrapper:currentChoices()
      assert.is_table(choices)
    end)
  end)

  describe("ResetState", function()
    it("resets story to initial state", function()
      wrapper:Continue()
      assert.is_false(wrapper:canContinue())

      wrapper:ResetState()
      assert.is_true(wrapper:canContinue())
    end)
  end)

  describe("currentFlowName", function()
    it("returns flow name", function()
      local name = wrapper:currentFlowName()
      assert.equal("DEFAULT", name)
    end)
  end)

  describe("aliveFlowNames", function()
    it("returns table of flow names", function()
      local flows = wrapper:aliveFlowNames()
      assert.is_table(flows)
    end)
  end)

  describe("HasFunction", function()
    it("returns boolean", function()
      local result = wrapper:HasFunction("test")
      assert.is_boolean(result)
    end)
  end)

  describe("get_raw_story", function()
    it("returns the underlying story", function()
      local raw = wrapper:get_raw_story()
      assert.is_table(raw)
    end)
  end)

  describe("get_ink_data", function()
    it("returns the original ink data", function()
      local data = wrapper:get_ink_data()
      assert.is_table(data)
      assert.is_number(data.inkVersion)
    end)
  end)

  describe("save/load state", function()
    it("save returns state data", function()
      local state = wrapper:save()
      assert.is_table(state)
    end)

    it("load accepts state data", function()
      -- Should not error
      wrapper:load({})
    end)
  end)

  describe("IStoryWrapper interface compliance", function()
    local IStoryWrapper = require("whisker.interfaces.vendor").IStoryWrapper

    it("implements canContinue", function()
      assert.is_function(wrapper.canContinue)
    end)

    it("implements Continue", function()
      assert.is_function(wrapper.Continue)
    end)

    it("implements currentText", function()
      assert.is_function(wrapper.currentText)
    end)

    it("implements currentTags", function()
      assert.is_function(wrapper.currentTags)
    end)

    it("implements currentChoices", function()
      assert.is_function(wrapper.currentChoices)
    end)

    it("implements ChooseChoiceIndex", function()
      assert.is_function(wrapper.ChooseChoiceIndex)
    end)

    it("implements ChoosePathString", function()
      assert.is_function(wrapper.ChoosePathString)
    end)

    it("implements ResetState", function()
      assert.is_function(wrapper.ResetState)
    end)

    it("implements BindExternalFunction", function()
      assert.is_function(wrapper.BindExternalFunction)
    end)

    it("implements UnbindExternalFunction", function()
      assert.is_function(wrapper.UnbindExternalFunction)
    end)

    it("implements ObserveVariable", function()
      assert.is_function(wrapper.ObserveVariable)
    end)

    it("implements RemoveVariableObserver", function()
      assert.is_function(wrapper.RemoveVariableObserver)
    end)

    it("implements currentFlowName", function()
      assert.is_function(wrapper.currentFlowName)
    end)

    it("implements SwitchFlow", function()
      assert.is_function(wrapper.SwitchFlow)
    end)

    it("implements RemoveFlow", function()
      assert.is_function(wrapper.RemoveFlow)
    end)

    it("implements aliveFlowNames", function()
      assert.is_function(wrapper.aliveFlowNames)
    end)

    it("implements HasFunction", function()
      assert.is_function(wrapper.HasFunction)
    end)

    it("implements EvaluateFunction", function()
      assert.is_function(wrapper.EvaluateFunction)
    end)
  end)
end)
