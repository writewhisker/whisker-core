--- PassageFactory Unit Tests
-- Tests for the PassageFactory implementation
-- @module tests.unit.core.factories.test_passage_factory_spec
-- @author Whisker Core Team

describe("PassageFactory", function()
  local PassageFactory
  local ChoiceFactory
  local Passage
  local factory

  before_each(function()
    PassageFactory = require("whisker.core.factories.passage_factory")
    ChoiceFactory = require("whisker.core.factories.choice_factory")
    Passage = require("whisker.core.passage")
    factory = PassageFactory.new({ choice_factory = ChoiceFactory.new() })
  end)

  describe("initialization", function()
    it("creates factory instance", function()
      assert.is_not_nil(factory)
    end)

    it("declares _dependencies", function()
      assert.is_table(PassageFactory._dependencies)
    end)

    it("_dependencies includes choice_factory", function()
      local has_choice_factory = false
      for _, dep in ipairs(PassageFactory._dependencies) do
        if dep == "choice_factory" then
          has_choice_factory = true
          break
        end
      end
      assert.is_true(has_choice_factory)
    end)

    it("accepts deps with choice_factory", function()
      local choice_factory = ChoiceFactory.new()
      local custom_factory = PassageFactory.new({ choice_factory = choice_factory })
      assert.is_not_nil(custom_factory)
    end)

    it("works without deps parameter (lazy loads)", function()
      local no_deps_factory = PassageFactory.new()
      assert.is_not_nil(no_deps_factory)
      -- Should still work because it lazy loads
      local passage = no_deps_factory:create({ id = "test", name = "Test" })
      assert.is_not_nil(passage)
    end)
  end)

  describe("create", function()
    it("creates passage with options table", function()
      local passage = factory:create({
        id = "room1",
        name = "Room 1",
        content = "You are in a room."
      })

      assert.is_not_nil(passage)
      assert.equals("room1", passage.id)
      assert.equals("Room 1", passage.name)
      assert.equals("You are in a room.", passage.content)
    end)

    it("creates passage with all options", function()
      local passage = factory:create({
        id = "full",
        name = "Full Passage",
        content = "Full content",
        tags = { "important", "start" },
        position = { x = 100, y = 200 },
        metadata = { custom = "value" },
        on_enter_script = "enter()",
        on_exit_script = "exit()"
      })

      assert.equals("full", passage.id)
      assert.equals("Full Passage", passage.name)
      assert.equals("Full content", passage.content)
      assert.is_true(passage:has_tag("important"))
      assert.equals(100, passage.position.x)
      assert.equals("value", passage:get_metadata("custom"))
    end)

    it("returns object with Passage metatable", function()
      local passage = factory:create({ id = "test", name = "Test" })

      assert.equals(Passage, getmetatable(passage))
    end)

    it("returned passage has validate method", function()
      local passage = factory:create({ id = "test", name = "Test" })

      assert.is_function(passage.validate)
      local valid, err = passage:validate()
      assert.is_true(valid)
    end)
  end)

  describe("from_table", function()
    it("restores passage from serialized data", function()
      local data = {
        id = "restored",
        name = "Restored Passage",
        content = "Restored content"
      }

      local passage = factory:from_table(data)

      assert.is_not_nil(passage)
      assert.equals("restored", passage.id)
      assert.equals("Restored Passage", passage.name)
    end)

    it("returns nil for nil input", function()
      local passage = factory:from_table(nil)

      assert.is_nil(passage)
    end)

    it("restores nested choices with metatables", function()
      local data = {
        id = "with_choices",
        name = "With Choices",
        choices = {
          { text = "Go north", target_passage = "north" },
          { text = "Go south", target_passage = "south" }
        }
      }

      local passage = factory:from_table(data)

      assert.equals(2, #passage.choices)
      assert.is_function(passage.choices[1].validate)
      assert.is_function(passage.choices[2].get_text)
    end)

    it("returned passage has proper metatable", function()
      local data = { id = "t", name = "T" }
      local passage = factory:from_table(data)

      assert.equals(Passage, getmetatable(passage))
    end)
  end)

  describe("restore_metatable", function()
    it("restores metatable to plain table", function()
      local plain_data = {
        id = "plain",
        name = "Plain Passage",
        content = "Plain content",
        choices = {},
        tags = {},
        metadata = {}
      }

      local passage = factory:restore_metatable(plain_data)

      assert.is_not_nil(passage)
      assert.equals(Passage, getmetatable(passage))
    end)

    it("returns nil for nil input", function()
      local result = factory:restore_metatable(nil)

      assert.is_nil(result)
    end)

    it("returns same object if already has metatable", function()
      local passage = factory:create({ id = "t", name = "T" })
      local restored = factory:restore_metatable(passage)

      assert.equals(passage, restored)
    end)

    it("restores nested choice metatables", function()
      local plain = {
        id = "nested",
        name = "Nested",
        choices = {
          { text = "A", target_passage = "a", metadata = {} },
          { text = "B", target_passage = "b", metadata = {} }
        },
        tags = {},
        metadata = {}
      }

      local restored = factory:restore_metatable(plain)

      assert.is_function(restored.choices[1].validate)
      assert.is_function(restored.choices[2].serialize)
    end)
  end)

  describe("get_class", function()
    it("returns Passage class", function()
      local cls = factory:get_class()

      assert.equals(Passage, cls)
    end)
  end)

  describe("get_choice_factory", function()
    it("returns the choice factory", function()
      local cf = factory:get_choice_factory()

      assert.is_not_nil(cf)
      assert.is_function(cf.create)
    end)
  end)

  describe("IPassageFactory contract compliance", function()
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

  describe("uses injected choice_factory", function()
    it("uses provided choice factory for from_table", function()
      local mock_calls = 0
      local mock_choice_factory = {
        create = function() mock_calls = mock_calls + 1 end,
        from_table = function(self, data)
          mock_calls = mock_calls + 1
          local Choice = require("whisker.core.choice")
          return Choice.from_table(data)
        end,
        restore_metatable = function(self, data)
          mock_calls = mock_calls + 1
          local Choice = require("whisker.core.choice")
          return Choice.restore_metatable(data)
        end
      }

      local custom_factory = PassageFactory.new({ choice_factory = mock_choice_factory })
      local data = {
        id = "test",
        name = "Test",
        choices = {
          { text = "A", target_passage = "a" },
          { text = "B", target_passage = "b" }
        }
      }

      custom_factory:from_table(data)

      assert.equals(2, mock_calls)  -- from_table called for each choice
    end)
  end)
end)
