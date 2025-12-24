--- Vendor Interface Contract Tests
-- Tests that implementations of IJsonCodec and IInkRuntime meet their contracts
-- @module tests.contracts.vendor_contract
-- @author Whisker Core Team
-- @license MIT

describe("Vendor Interface Contracts", function()
  local Vendor = require("whisker.interfaces.vendor")

  describe("IJsonCodec", function()
    local IJsonCodec = Vendor.IJsonCodec

    it("defines encode method", function()
      assert.is_function(IJsonCodec.encode)
    end)

    it("defines decode method", function()
      assert.is_function(IJsonCodec.decode)
    end)

    it("defines get_library_name method", function()
      assert.is_function(IJsonCodec.get_library_name)
    end)

    it("defines supports method", function()
      assert.is_function(IJsonCodec.supports)
    end)

    it("defines null method", function()
      assert.is_function(IJsonCodec.null)
    end)

    it("encode throws if not implemented", function()
      assert.has_error(function()
        IJsonCodec:encode({})
      end, "IJsonCodec:encode must be implemented")
    end)

    it("decode throws if not implemented", function()
      assert.has_error(function()
        IJsonCodec:decode("{}")
      end, "IJsonCodec:decode must be implemented")
    end)

    it("get_library_name throws if not implemented", function()
      assert.has_error(function()
        IJsonCodec:get_library_name()
      end, "IJsonCodec:get_library_name must be implemented")
    end)

    it("supports throws if not implemented", function()
      assert.has_error(function()
        IJsonCodec:supports("pretty")
      end, "IJsonCodec:supports must be implemented")
    end)

    it("null throws if not implemented", function()
      assert.has_error(function()
        IJsonCodec:null()
      end, "IJsonCodec:null must be implemented")
    end)
  end)

  describe("IInkRuntime", function()
    local IInkRuntime = Vendor.IInkRuntime

    it("defines create_story method", function()
      assert.is_function(IInkRuntime.create_story)
    end)

    it("defines get_runtime_name method", function()
      assert.is_function(IInkRuntime.get_runtime_name)
    end)

    it("defines get_ink_version method", function()
      assert.is_function(IInkRuntime.get_ink_version)
    end)

    it("defines supports method", function()
      assert.is_function(IInkRuntime.supports)
    end)

    it("create_story throws if not implemented", function()
      assert.has_error(function()
        IInkRuntime:create_story({})
      end, "IInkRuntime:create_story must be implemented")
    end)

    it("get_runtime_name throws if not implemented", function()
      assert.has_error(function()
        IInkRuntime:get_runtime_name()
      end, "IInkRuntime:get_runtime_name must be implemented")
    end)

    it("get_ink_version throws if not implemented", function()
      assert.has_error(function()
        IInkRuntime:get_ink_version()
      end, "IInkRuntime:get_ink_version must be implemented")
    end)

    it("supports throws if not implemented", function()
      assert.has_error(function()
        IInkRuntime:supports("flows")
      end, "IInkRuntime:supports must be implemented")
    end)
  end)

  describe("IStoryWrapper", function()
    local IStoryWrapper = Vendor.IStoryWrapper

    -- Core story methods
    it("defines canContinue method", function()
      assert.is_function(IStoryWrapper.canContinue)
    end)

    it("defines Continue method", function()
      assert.is_function(IStoryWrapper.Continue)
    end)

    it("defines currentText method", function()
      assert.is_function(IStoryWrapper.currentText)
    end)

    it("defines currentTags method", function()
      assert.is_function(IStoryWrapper.currentTags)
    end)

    it("defines currentChoices method", function()
      assert.is_function(IStoryWrapper.currentChoices)
    end)

    it("defines ChooseChoiceIndex method", function()
      assert.is_function(IStoryWrapper.ChooseChoiceIndex)
    end)

    it("defines ChoosePathString method", function()
      assert.is_function(IStoryWrapper.ChoosePathString)
    end)

    -- State methods
    it("defines get_state method", function()
      assert.is_function(IStoryWrapper.get_state)
    end)

    it("defines ResetState method", function()
      assert.is_function(IStoryWrapper.ResetState)
    end)

    -- External functions
    it("defines BindExternalFunction method", function()
      assert.is_function(IStoryWrapper.BindExternalFunction)
    end)

    it("defines UnbindExternalFunction method", function()
      assert.is_function(IStoryWrapper.UnbindExternalFunction)
    end)

    -- Variable observation
    it("defines ObserveVariable method", function()
      assert.is_function(IStoryWrapper.ObserveVariable)
    end)

    it("defines RemoveVariableObserver method", function()
      assert.is_function(IStoryWrapper.RemoveVariableObserver)
    end)

    -- Flow management
    it("defines currentFlowName method", function()
      assert.is_function(IStoryWrapper.currentFlowName)
    end)

    it("defines SwitchFlow method", function()
      assert.is_function(IStoryWrapper.SwitchFlow)
    end)

    it("defines RemoveFlow method", function()
      assert.is_function(IStoryWrapper.RemoveFlow)
    end)

    it("defines aliveFlowNames method", function()
      assert.is_function(IStoryWrapper.aliveFlowNames)
    end)

    -- Function evaluation
    it("defines HasFunction method", function()
      assert.is_function(IStoryWrapper.HasFunction)
    end)

    it("defines EvaluateFunction method", function()
      assert.is_function(IStoryWrapper.EvaluateFunction)
    end)

    -- Verify abstract methods throw
    it("canContinue throws if not implemented", function()
      assert.has_error(function()
        IStoryWrapper:canContinue()
      end, "IStoryWrapper:canContinue must be implemented")
    end)

    it("Continue throws if not implemented", function()
      assert.has_error(function()
        IStoryWrapper:Continue()
      end, "IStoryWrapper:Continue must be implemented")
    end)
  end)
end)
