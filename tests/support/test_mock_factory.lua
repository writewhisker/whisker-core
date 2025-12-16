-- tests/support/test_mock_factory.lua
-- Tests for Mock Factory

describe("MockFactory", function()
  local MockFactory

  before_each(function()
    package.loaded["tests.support.mock_factory"] = nil
    MockFactory = require("tests.support.mock_factory")
  end)

  describe("from_interface", function()
    it("should create mock from interface", function()
      local ITest = {
        _name = "ITest",
        _required = {"method1", "method2"},
        method1 = "function(self)",
        method2 = "function(self, arg)",
      }

      local mock = MockFactory.from_interface(ITest)
      assert.is_not_nil(mock)
      assert.is_function(mock.method1)
      assert.is_function(mock.method2)
    end)

    it("should work with IState interface", function()
      local IState = require("whisker.interfaces.state")
      local mock = MockFactory.from_interface(IState)

      assert.is_function(mock.get)
      assert.is_function(mock.set)
      assert.is_function(mock.has)
      assert.is_function(mock.clear)
      assert.is_function(mock.snapshot)
      assert.is_function(mock.restore)
    end)

    it("should work with IFormat interface", function()
      local IFormat = require("whisker.interfaces.format")
      local mock = MockFactory.from_interface(IFormat)

      assert.is_function(mock.can_import)
      assert.is_function(mock.import)
      assert.is_function(mock.can_export)
      assert.is_function(mock.export)
    end)

    it("should work with IEngine interface", function()
      local IEngine = require("whisker.interfaces.engine")
      local mock = MockFactory.from_interface(IEngine)

      assert.is_function(mock.load)
      assert.is_function(mock.start)
      assert.is_function(mock.get_current_passage)
      assert.is_function(mock.get_available_choices)
      assert.is_function(mock.make_choice)
      assert.is_function(mock.can_continue)
    end)

    it("should work with ISerializer interface", function()
      local ISerializer = require("whisker.interfaces.serializer")
      local mock = MockFactory.from_interface(ISerializer)

      assert.is_function(mock.serialize)
      assert.is_function(mock.deserialize)
    end)

    it("should work with IConditionEvaluator interface", function()
      local ICondition = require("whisker.interfaces.condition")
      local mock = MockFactory.from_interface(ICondition)

      assert.is_function(mock.evaluate)
    end)

    it("should work with IPlugin interface", function()
      local IPlugin = require("whisker.interfaces.plugin")
      local mock = MockFactory.from_interface(IPlugin)

      assert.is_function(mock.init)
    end)
  end)

  describe("call tracking", function()
    it("should track method calls", function()
      local ITest = {
        _required = {"method1"},
        method1 = "function(self)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:method1()
      mock:method1()

      assert.are.equal(2, mock:call_count("method1"))
    end)

    it("should track arguments", function()
      local ITest = {
        _required = {"method1"},
        method1 = "function(self, a, b)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:method1("arg1", "arg2")

      local calls = mock:get_calls("method1")
      assert.are.equal(1, #calls)
      assert.are.equal("arg1", calls[1].args[1])
      assert.are.equal("arg2", calls[1].args[2])
    end)

    it("should track total call count", function()
      local ITest = {
        _required = {"a", "b"},
        a = "function(self)",
        b = "function(self)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:a()
      mock:b()
      mock:a()

      assert.are.equal(3, mock:call_count())
    end)

    it("should reset calls", function()
      local ITest = {
        _required = {"method1"},
        method1 = "function(self)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:method1()
      mock:method1()
      mock:reset_calls()

      assert.are.equal(0, mock:call_count())
    end)
  end)

  describe("stubbing with when()", function()
    it("should return stubbed value", function()
      local ITest = {
        _required = {"get"},
        get = "function(self, key) -> any",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:when("get"):returns("stubbed_value")

      local result = mock:get("any_key")
      assert.are.equal("stubbed_value", result)
    end)

    it("should allow function stubs", function()
      local ITest = {
        _required = {"calculate"},
        calculate = "function(self, a, b) -> number",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:when("calculate"):returns_fn(function(a, b)
        return a + b
      end)

      assert.are.equal(5, mock:calculate(2, 3))
      assert.are.equal(10, mock:calculate(4, 6))
    end)

    it("should allow chaining", function()
      local ITest = {
        _required = {"a", "b"},
        a = "function(self) -> string",
        b = "function(self) -> number",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:when("a"):returns("hello")
      mock:when("b"):returns(42)

      assert.are.equal("hello", mock:a())
      assert.are.equal(42, mock:b())
    end)

    it("should reset stubs with reset()", function()
      local ITest = {
        _required = {"get"},
        get = "function(self) -> any",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:when("get"):returns("value")
      mock:reset()

      -- After reset, should return default (nil for -> any)
      assert.is_nil(mock:get())
    end)
  end)

  describe("verification with verify()", function()
    it("should verify call count", function()
      local ITest = {
        _required = {"method1"},
        method1 = "function(self)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:method1()
      mock:method1()

      assert.is_true(mock:verify("method1"):called(2))
    end)

    it("should fail verification with wrong count", function()
      local ITest = {
        _required = {"method1"},
        method1 = "function(self)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:method1()

      assert.has_error(function()
        mock:verify("method1"):called(2)
      end)
    end)

    it("should verify never called", function()
      local ITest = {
        _required = {"method1"},
        method1 = "function(self)",
      }
      local mock = MockFactory.from_interface(ITest)

      assert.is_true(mock:verify("method1"):never_called())
    end)

    it("should verify at least N calls", function()
      local ITest = {
        _required = {"method1"},
        method1 = "function(self)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:method1()
      mock:method1()
      mock:method1()

      assert.is_true(mock:verify("method1"):called_at_least(2))
    end)

    it("should verify called with arguments", function()
      local ITest = {
        _required = {"set"},
        set = "function(self, key, value)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:set("name", "John")

      assert.is_true(mock:verify("set"):called_with("name", "John"))
    end)

    it("should fail called_with verification when not matching", function()
      local ITest = {
        _required = {"set"},
        set = "function(self, key, value)",
      }
      local mock = MockFactory.from_interface(ITest)

      mock:set("name", "John")

      assert.has_error(function()
        mock:verify("set"):called_with("name", "Jane")
      end)
    end)
  end)

  describe("default return values", function()
    it("should return false for boolean return type", function()
      local ITest = {
        _required = {"check"},
        check = "function(self) -> boolean",
      }
      local mock = MockFactory.from_interface(ITest)

      assert.is_false(mock:check())
    end)

    it("should return empty table for table return type", function()
      local ITest = {
        _required = {"get_list"},
        get_list = "function(self) -> table",
      }
      local mock = MockFactory.from_interface(ITest)

      local result = mock:get_list()
      assert.is_table(result)
      assert.are.same({}, result)
    end)

    it("should return empty string for string return type", function()
      local ITest = {
        _required = {"get_name"},
        get_name = "function(self) -> string",
      }
      local mock = MockFactory.from_interface(ITest)

      assert.are.equal("", mock:get_name())
    end)

    it("should return 0 for number return type", function()
      local ITest = {
        _required = {"count"},
        count = "function(self) -> number",
      }
      local mock = MockFactory.from_interface(ITest)

      assert.are.equal(0, mock:count())
    end)
  end)

  describe("stub function", function()
    it("should create a stub function", function()
      local fn, tracker = MockFactory.stub("return_value")

      local result = fn("arg1", "arg2")

      assert.are.equal("return_value", result)
      assert.are.equal(1, #tracker.calls)
      assert.are.equal("arg1", tracker.calls[1].args[1])
    end)
  end)

  describe("integration example", function()
    it("should work like the example in the spec", function()
      local IState = require("whisker.interfaces.state")

      local mock_state = MockFactory.from_interface(IState)
      mock_state:when("get"):returns("test_value")

      local result = mock_state:get("key")
      assert.are.equal("test_value", result)
      mock_state:verify("get"):called(1)
      mock_state:verify("get"):called_with("key")
    end)
  end)
end)
