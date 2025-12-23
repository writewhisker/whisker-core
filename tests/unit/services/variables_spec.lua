--- VariableService Unit Tests
-- @module tests.unit.services.variables_spec
-- @author Whisker Core Team

describe("VariableService", function()
  local VariableService
  local TestContainer = require("tests.helpers.test_container")

  before_each(function()
    VariableService = require("whisker.services.variables")
  end)

  describe("initialization", function()
    it("creates variable service without container", function()
      local variables = VariableService.new(nil)
      assert.is_not_nil(variables)
    end)

    it("creates variable service with container", function()
      local container = TestContainer.create_full()
      local variables = VariableService.new(container)
      assert.is_not_nil(variables)
    end)
  end)

  describe("get/set operations", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("sets and gets a variable", function()
      variables:set("player_name", "Alice")
      assert.equals("Alice", variables:get("player_name"))
    end)

    it("returns nil for nonexistent variable", function()
      assert.is_nil(variables:get("nonexistent"))
    end)

    it("overwrites existing variable", function()
      variables:set("gold", 100)
      variables:set("gold", 200)
      assert.equals(200, variables:get("gold"))
    end)

    it("handles different value types", function()
      variables:set("name", "Bob")
      variables:set("level", 5)
      variables:set("active", true)
      variables:set("inventory", { "sword", "shield" })

      assert.equals("Bob", variables:get("name"))
      assert.equals(5, variables:get("level"))
      assert.equals(true, variables:get("active"))
      assert.same({ "sword", "shield" }, variables:get("inventory"))
    end)
  end)

  describe("has operation", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("returns true for existing variable", function()
      variables:set("exists", "yes")
      assert.is_true(variables:has("exists"))
    end)

    it("returns false for nonexistent variable", function()
      assert.is_false(variables:has("nonexistent"))
    end)
  end)

  describe("delete operation", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("deletes existing variable", function()
      variables:set("temp", "value")
      local result = variables:delete("temp")

      assert.is_true(result)
      assert.is_nil(variables:get("temp"))
    end)

    it("returns false for nonexistent variable", function()
      local result = variables:delete("nonexistent")
      assert.is_false(result)
    end)
  end)

  describe("list operation", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("returns all variable names", function()
      variables:set("alpha", 1)
      variables:set("beta", 2)
      variables:set("gamma", 3)

      local names = variables:list()

      assert.equals(3, #names)
      assert.same({"alpha", "beta", "gamma"}, names)  -- sorted
    end)

    it("returns empty table when no variables", function()
      local names = variables:list()
      assert.same({}, names)
    end)
  end)

  describe("get_all operation", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("returns all variables as table", function()
      variables:set("a", 1)
      variables:set("b", 2)

      local all = variables:get_all()

      assert.equals(1, all.a)
      assert.equals(2, all.b)
    end)
  end)

  describe("clear operation", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("clears all variables", function()
      variables:set("a", 1)
      variables:set("b", 2)
      variables:clear()

      assert.is_nil(variables:get("a"))
      assert.is_nil(variables:get("b"))
      assert.same({}, variables:list())
    end)
  end)

  describe("increment/decrement operations", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("increments a variable", function()
      variables:set("counter", 10)
      local result = variables:increment("counter")

      assert.equals(11, result)
      assert.equals(11, variables:get("counter"))
    end)

    it("increments by custom amount", function()
      variables:set("gold", 100)
      local result = variables:increment("gold", 50)

      assert.equals(150, result)
    end)

    it("increments non-existent variable from 0", function()
      local result = variables:increment("new_counter")

      assert.equals(1, result)
      assert.equals(1, variables:get("new_counter"))
    end)

    it("decrements a variable", function()
      variables:set("health", 100)
      local result = variables:decrement("health", 20)

      assert.equals(80, result)
      assert.equals(80, variables:get("health"))
    end)

    it("decrements by default amount", function()
      variables:set("lives", 3)
      local result = variables:decrement("lives")

      assert.equals(2, result)
    end)
  end)

  describe("toggle operation", function()
    local variables

    before_each(function()
      variables = VariableService.new(nil)
    end)

    it("toggles false to true", function()
      variables:set("flag", false)
      local result = variables:toggle("flag")

      assert.equals(true, result)
      assert.equals(true, variables:get("flag"))
    end)

    it("toggles true to false", function()
      variables:set("flag", true)
      local result = variables:toggle("flag")

      assert.equals(false, result)
    end)

    it("toggles nil to true", function()
      local result = variables:toggle("new_flag")
      assert.equals(true, result)
    end)
  end)

  describe("with state service", function()
    local variables, state

    before_each(function()
      local container = TestContainer.create_full()
      state = container:resolve("state")
      variables = VariableService.new(container)
    end)

    it("stores variables in state with prefix", function()
      variables:set("test_var", "test_value")

      -- Variable should be stored in state with prefix
      assert.equals("test_value", state:get("var:test_var"))
    end)

    it("retrieves variables from state", function()
      state:set("var:existing", "existing_value")

      assert.equals("existing_value", variables:get("existing"))
    end)
  end)

  describe("event emission", function()
    local variables, events, emitted

    before_each(function()
      local container = TestContainer.create()
      events = container:resolve("events")
      variables = VariableService.new(container)
      emitted = {}

      events:on("variable:*", function(data)
        table.insert(emitted, data)
      end)
    end)

    it("emits variable:changed when set", function()
      variables:set("key", "value")

      assert.equals(1, #emitted)
      assert.equals("key", emitted[1].name)
      assert.equals("value", emitted[1].new_value)
    end)

    it("emits variable:deleted when deleted", function()
      variables:set("key", "value")
      emitted = {}

      variables:delete("key")

      assert.equals(1, #emitted)
      assert.equals("key", emitted[1].name)
    end)
  end)

  describe("destroy", function()
    it("cleans up resources", function()
      local variables = VariableService.new(nil)
      variables:set("key", "value")
      variables:destroy()

      assert.same({}, variables:list())
    end)
  end)
end)
