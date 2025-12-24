--- Choice Unit Tests
-- Comprehensive unit tests for the Choice module
-- @module tests.unit.core.test_choice_spec
-- @author Whisker Core Team

describe("Choice", function()
  local Choice

  before_each(function()
    Choice = require("whisker.core.choice")
  end)

  describe("initialization", function()
    it("creates choice with required fields", function()
      local choice = Choice.new({ text = "Go", target = "next" })

      assert.is_not_nil(choice)
      assert.equals("Go", choice.text)
      assert.equals("next", choice.target)
    end)

    it("generates id when not provided", function()
      local choice = Choice.new({ text = "Go", target = "next" })

      assert.is_not_nil(choice.id)
      assert.is_string(choice.id)
    end)

    it("uses provided id", function()
      local choice = Choice.new({
        id = "custom_id",
        text = "Go",
        target = "next"
      })

      assert.equals("custom_id", choice.id)
    end)

    it("initializes optional fields to nil", function()
      local choice = Choice.new({ text = "Go", target = "next" })

      assert.is_nil(choice.condition)
      assert.is_nil(choice.action)
    end)
  end)

  describe("condition handling", function()
    it("sets condition", function()
      local choice = Choice.new({
        text = "Buy item",
        target = "shop",
        condition = "gold >= 10"
      })

      assert.equals("gold >= 10", choice.condition)
    end)

    it("has_condition returns true when set", function()
      local choice = Choice.new({
        text = "Go",
        target = "next",
        condition = "has_key"
      })

      assert.is_true(choice:has_condition())
    end)

    it("has_condition returns false when not set", function()
      local choice = Choice.new({ text = "Go", target = "next" })

      assert.is_false(choice:has_condition())
    end)
  end)

  describe("action handling", function()
    it("sets action", function()
      local choice = Choice.new({
        text = "Take gold",
        target = "next",
        action = "gold = gold + 10"
      })

      assert.equals("gold = gold + 10", choice.action)
    end)

    it("has_action returns true when set", function()
      local choice = Choice.new({
        text = "Go",
        target = "next",
        action = "visited = true"
      })

      assert.is_true(choice:has_action())
    end)

    it("has_action returns false when not set", function()
      local choice = Choice.new({ text = "Go", target = "next" })

      assert.is_false(choice:has_action())
    end)
  end)

  describe("metadata", function()
    local choice

    before_each(function()
      choice = Choice.new({ text = "Go", target = "next" })
    end)

    it("sets and gets metadata", function()
      choice:set_metadata("key", "value")

      assert.equals("value", choice:get_metadata("key"))
    end)

    it("returns nil for nonexistent metadata", function()
      assert.is_nil(choice:get_metadata("nonexistent"))
    end)

    it("has_metadata returns true when set", function()
      choice:set_metadata("key", "value")

      assert.is_true(choice:has_metadata("key"))
    end)

    it("has_metadata returns false when not set", function()
      assert.is_false(choice:has_metadata("nonexistent"))
    end)
  end)

  describe("validation", function()
    it("valid choice passes validation", function()
      local choice = Choice.new({
        text = "Valid",
        target = "next"
      })

      local valid, err = choice:validate()

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("fails without text", function()
      local choice = Choice.new({ target = "next" })
      choice.text = nil

      local valid, err = choice:validate()

      assert.is_false(valid)
      assert.is_string(err)
    end)

    it("fails without target", function()
      local choice = Choice.new({ text = "Go" })
      choice.target = nil

      local valid, err = choice:validate()

      assert.is_false(valid)
      assert.is_string(err)
    end)
  end)

  describe("serialization", function()
    it("serializes choice data", function()
      local choice = Choice.new({
        id = "test_id",
        text = "Test",
        target = "next",
        condition = "condition",
        action = "action"
      })

      local data = choice:serialize()

      assert.equals("test_id", data.id)
      assert.equals("Test", data.text)
      assert.equals("next", data.target)
      assert.equals("condition", data.condition)
      assert.equals("action", data.action)
    end)

    it("deserializes choice data", function()
      local data = {
        id = "restored_id",
        text = "Restored",
        target = "restored_target",
        condition = "restored_condition"
      }

      local choice = Choice.new({ text = "temp", target = "temp" })
      choice:deserialize(data)

      assert.equals("restored_id", choice.id)
      assert.equals("Restored", choice.text)
      assert.equals("restored_target", choice.target)
      assert.equals("restored_condition", choice.condition)
    end)

    it("round-trip preserves data", function()
      local original = Choice.new({
        id = "round_trip",
        text = "Round Trip",
        target = "destination",
        condition = "cond",
        action = "act"
      })

      local data = original:serialize()
      local restored = Choice.new({ text = "temp", target = "temp" })
      restored:deserialize(data)

      assert.equals(original.id, restored.id)
      assert.equals(original.text, restored.text)
      assert.equals(original.target, restored.target)
      assert.equals(original.condition, restored.condition)
      assert.equals(original.action, restored.action)
    end)
  end)

  describe("from_table factory", function()
    it("creates choice from table", function()
      local data = {
        id = "from_table",
        text = "From Table",
        target = "target"
      }

      local choice = Choice.from_table(data)

      assert.is_not_nil(choice)
      assert.equals("from_table", choice.id)
      assert.equals("From Table", choice.text)
    end)

    it("returns nil for nil input", function()
      local choice = Choice.from_table(nil)

      assert.is_nil(choice)
    end)
  end)

  describe("DI pattern support", function()
    it("declares _dependencies", function()
      assert.is_table(Choice._dependencies)
    end)

    it("_dependencies is empty (no dependencies)", function()
      assert.equals(0, #Choice._dependencies)
    end)

    it("provides create factory method", function()
      assert.is_function(Choice.create)
    end)

    it("create returns a factory function", function()
      local factory = Choice.create({})

      assert.is_function(factory)
    end)

    it("factory function creates valid choices", function()
      local factory = Choice.create({})
      local choice = factory({ text = "Test", target = "next" })

      assert.is_not_nil(choice)
      assert.equals("Test", choice.text)
      assert.equals("next", choice.target)
    end)

    it("factory function works without deps parameter", function()
      local factory = Choice.create()
      local choice = factory({ text = "No deps", target = "target" })

      assert.is_not_nil(choice)
      assert.equals("No deps", choice.text)
    end)

    it("factory function supports two-argument form", function()
      local factory = Choice.create({})
      local choice = factory("Simple text", "destination")

      assert.is_not_nil(choice)
      assert.equals("Simple text", choice.text)
      assert.equals("destination", choice.target)
    end)

    it("backward compatibility: Choice.new still works", function()
      local choice = Choice.new({ text = "Direct", target = "direct" })

      assert.is_not_nil(choice)
      assert.equals("Direct", choice.text)
    end)
  end)
end)
