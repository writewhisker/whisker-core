-- tests/interfaces/test_interfaces.lua
-- Tests for interface validation system

describe("Interfaces", function()
  local Interfaces

  before_each(function()
    package.loaded["whisker.interfaces.init"] = nil
    Interfaces = require("whisker.interfaces.init")
  end)

  describe("register", function()
    it("should register an interface", function()
      local ITest = { _name = "ITest", _required = {"foo"} }
      Interfaces.register(ITest)
      assert.are.equal(ITest, Interfaces.get("ITest"))
    end)

    it("should reject interface without name", function()
      assert.has_error(function()
        Interfaces.register({ _required = {"foo"} })
      end)
    end)
  end)

  describe("implements", function()
    local ITest

    before_each(function()
      ITest = {
        _name = "ITest",
        _required = {"method1", "method2"},
        method1 = "function(self) -> boolean",
        method2 = "function(self, arg)",
      }
    end)

    it("should return true for valid implementation", function()
      local impl = {
        method1 = function() return true end,
        method2 = function() end,
      }
      assert.is_true(Interfaces.implements(impl, ITest))
    end)

    it("should return false for missing method", function()
      local impl = {
        method1 = function() return true end,
        -- missing method2
      }
      assert.is_false(Interfaces.implements(impl, ITest))
    end)

    it("should return false for non-function when function expected", function()
      local impl = {
        method1 = "not a function",
        method2 = function() end,
      }
      assert.is_false(Interfaces.implements(impl, ITest))
    end)

    it("should return false for nil object", function()
      assert.is_false(Interfaces.implements(nil, ITest))
    end)

    it("should return false for nil interface", function()
      assert.is_false(Interfaces.implements({}, nil))
    end)
  end)

  describe("validate", function()
    local ITest

    before_each(function()
      ITest = {
        _name = "ITest",
        _required = {"method1", "prop1"},
        method1 = "function(self)",
        prop1 = "string",
      }
    end)

    it("should return true for valid implementation", function()
      local impl = {
        method1 = function() end,
        prop1 = "value",
      }
      local valid, errors = Interfaces.validate(impl, ITest)
      assert.is_true(valid)
      assert.are.same({}, errors)
    end)

    it("should return errors for missing members", function()
      local impl = {}
      local valid, errors = Interfaces.validate(impl, ITest)
      assert.is_false(valid)
      assert.are.equal(2, #errors)
    end)

    it("should return error for nil object", function()
      local valid, errors = Interfaces.validate(nil, ITest)
      assert.is_false(valid)
      assert.are.equal("Object is nil", errors[1])
    end)
  end)

  describe("stub", function()
    it("should create stub with function methods", function()
      local ITest = {
        _name = "ITest",
        _required = {"method1", "method2"},
        method1 = "function(self)",
        method2 = "function(self, arg)",
      }
      local stub = Interfaces.stub(ITest)
      assert.is_function(stub.method1)
      assert.is_function(stub.method2)
    end)
  end)

  describe("list", function()
    it("should return registered interface names", function()
      Interfaces.register({ _name = "IA" })
      Interfaces.register({ _name = "IB" })
      local names = Interfaces.list()
      assert.is_true(#names >= 2)
    end)
  end)
end)

describe("IFormat", function()
  local Interfaces, IFormat

  before_each(function()
    package.loaded["whisker.interfaces.init"] = nil
    package.loaded["whisker.interfaces.format"] = nil
    Interfaces = require("whisker.interfaces.init")
    IFormat = require("whisker.interfaces.format")
  end)

  it("should have correct name", function()
    assert.are.equal("IFormat", IFormat._name)
  end)

  it("should have required methods", function()
    assert.are.same({"can_import", "import", "can_export", "export"}, IFormat._required)
  end)

  it("should validate a proper format implementation", function()
    local format = {
      can_import = function() return true end,
      import = function() return {} end,
      can_export = function() return true end,
      export = function() return "" end,
    }
    assert.is_true(Interfaces.implements(format, IFormat))
  end)
end)

describe("IState", function()
  local Interfaces, IState

  before_each(function()
    package.loaded["whisker.interfaces.init"] = nil
    package.loaded["whisker.interfaces.state"] = nil
    Interfaces = require("whisker.interfaces.init")
    IState = require("whisker.interfaces.state")
  end)

  it("should have correct name", function()
    assert.are.equal("IState", IState._name)
  end)

  it("should have required methods", function()
    assert.are.same({"get", "set", "has", "clear", "snapshot", "restore"}, IState._required)
  end)

  it("should validate a proper state implementation", function()
    local state = {
      get = function() end,
      set = function() end,
      has = function() return false end,
      clear = function() end,
      snapshot = function() return {} end,
      restore = function() end,
    }
    assert.is_true(Interfaces.implements(state, IState))
  end)
end)

describe("IEngine", function()
  local Interfaces, IEngine

  before_each(function()
    package.loaded["whisker.interfaces.init"] = nil
    package.loaded["whisker.interfaces.engine"] = nil
    Interfaces = require("whisker.interfaces.init")
    IEngine = require("whisker.interfaces.engine")
  end)

  it("should have correct name", function()
    assert.are.equal("IEngine", IEngine._name)
  end)

  it("should have required methods", function()
    local expected = {"load", "start", "get_current_passage", "get_available_choices", "make_choice", "can_continue"}
    assert.are.same(expected, IEngine._required)
  end)
end)

describe("ISerializer", function()
  local ISerializer

  before_each(function()
    package.loaded["whisker.interfaces.serializer"] = nil
    ISerializer = require("whisker.interfaces.serializer")
  end)

  it("should have correct name", function()
    assert.are.equal("ISerializer", ISerializer._name)
  end)

  it("should have required methods", function()
    assert.are.same({"serialize", "deserialize"}, ISerializer._required)
  end)
end)

describe("IConditionEvaluator", function()
  local IConditionEvaluator

  before_each(function()
    package.loaded["whisker.interfaces.condition"] = nil
    IConditionEvaluator = require("whisker.interfaces.condition")
  end)

  it("should have correct name", function()
    assert.are.equal("IConditionEvaluator", IConditionEvaluator._name)
  end)

  it("should have required methods", function()
    assert.are.same({"evaluate"}, IConditionEvaluator._required)
  end)
end)

describe("IPlugin", function()
  local Interfaces, IPlugin

  before_each(function()
    package.loaded["whisker.interfaces.init"] = nil
    package.loaded["whisker.interfaces.plugin"] = nil
    Interfaces = require("whisker.interfaces.init")
    IPlugin = require("whisker.interfaces.plugin")
  end)

  it("should have correct name", function()
    assert.are.equal("IPlugin", IPlugin._name)
  end)

  it("should have required members", function()
    assert.are.same({"name", "version", "init"}, IPlugin._required)
  end)

  it("should validate a proper plugin implementation", function()
    local plugin = {
      name = "test-plugin",
      version = "1.0.0",
      init = function() end,
    }
    assert.is_true(Interfaces.implements(plugin, IPlugin))
  end)
end)
