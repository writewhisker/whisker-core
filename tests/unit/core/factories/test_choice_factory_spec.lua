--- ChoiceFactory Unit Tests
-- Tests for the ChoiceFactory implementation
-- @module tests.unit.core.factories.test_choice_factory_spec
-- @author Whisker Core Team

describe("ChoiceFactory", function()
  local ChoiceFactory
  local Choice
  local factory

  before_each(function()
    ChoiceFactory = require("whisker.core.factories.choice_factory")
    Choice = require("whisker.core.choice")
    factory = ChoiceFactory.new()
  end)

  describe("initialization", function()
    it("creates factory instance", function()
      assert.is_not_nil(factory)
    end)

    it("declares _dependencies", function()
      assert.is_table(ChoiceFactory._dependencies)
    end)

    it("_dependencies is empty", function()
      assert.equals(0, #ChoiceFactory._dependencies)
    end)

    it("accepts deps parameter", function()
      local custom_factory = ChoiceFactory.new({ some_dep = true })
      assert.is_not_nil(custom_factory)
    end)

    it("works without deps parameter", function()
      local no_deps_factory = ChoiceFactory.new()
      assert.is_not_nil(no_deps_factory)
    end)
  end)

  describe("create", function()
    it("creates choice with options table", function()
      local choice = factory:create({
        text = "Go north",
        target = "north_room"
      })

      assert.is_not_nil(choice)
      assert.equals("Go north", choice.text)
      assert.equals("north_room", choice.target)
    end)

    it("creates choice with all options", function()
      local choice = factory:create({
        id = "custom_id",
        text = "Buy item",
        target = "shop",
        condition = "gold >= 10",
        action = "gold = gold - 10",
        metadata = { cost = 10 }
      })

      assert.equals("custom_id", choice.id)
      assert.equals("Buy item", choice.text)
      assert.equals("shop", choice.target)
      assert.equals("gold >= 10", choice.condition)
      assert.equals("gold = gold - 10", choice.action)
      assert.equals(10, choice:get_metadata("cost"))
    end)

    it("returns object with Choice metatable", function()
      local choice = factory:create({ text = "Test", target = "t" })

      assert.equals(Choice, getmetatable(choice))
    end)

    it("returned choice has validate method", function()
      local choice = factory:create({ text = "Test", target = "t" })

      assert.is_function(choice.validate)
      local valid, err = choice:validate()
      assert.is_true(valid)
    end)

    it("returned choice has serialize method", function()
      local choice = factory:create({ text = "Test", target = "t" })

      assert.is_function(choice.serialize)
      local data = choice:serialize()
      assert.equals("Test", data.text)
    end)
  end)

  describe("from_table", function()
    it("restores choice from serialized data", function()
      local data = {
        id = "restored_id",
        text = "Restored choice",
        target_passage = "target_passage",
        condition = "has_key"
      }

      local choice = factory:from_table(data)

      assert.is_not_nil(choice)
      assert.equals("restored_id", choice.id)
      assert.equals("Restored choice", choice.text)
      assert.equals("target_passage", choice.target)
    end)

    it("returns nil for nil input", function()
      local choice = factory:from_table(nil)

      assert.is_nil(choice)
    end)

    it("returned choice has proper metatable", function()
      local data = { id = "t", text = "T", target_passage = "p" }
      local choice = factory:from_table(data)

      assert.equals(Choice, getmetatable(choice))
    end)
  end)

  describe("restore_metatable", function()
    it("restores metatable to plain table", function()
      local plain_data = {
        id = "plain_id",
        text = "Plain choice",
        target_passage = "target",
        metadata = {}
      }

      local choice = factory:restore_metatable(plain_data)

      assert.is_not_nil(choice)
      assert.equals(Choice, getmetatable(choice))
    end)

    it("returns nil for nil input", function()
      local result = factory:restore_metatable(nil)

      assert.is_nil(result)
    end)

    it("returns same object if already has metatable", function()
      local choice = factory:create({ text = "T", target = "t" })
      local restored = factory:restore_metatable(choice)

      assert.equals(choice, restored)
    end)

    it("restored object has methods", function()
      local plain = { text = "T", target_passage = "t", metadata = {} }
      local restored = factory:restore_metatable(plain)

      assert.is_function(restored.validate)
      assert.is_function(restored.serialize)
      assert.is_function(restored.get_text)
    end)
  end)

  describe("get_class", function()
    it("returns Choice class", function()
      local cls = factory:get_class()

      assert.equals(Choice, cls)
    end)
  end)

  describe("IChoiceFactory contract compliance", function()
    it("implements create method", function()
      assert.is_function(factory.create)
    end)

    it("implements from_table method", function()
      assert.is_function(factory.from_table)
    end)

    it("implements restore_metatable method", function()
      assert.is_function(factory.restore_metatable)
    end)
  end)
end)
