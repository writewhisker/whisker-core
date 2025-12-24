--- Passage Unit Tests
-- Comprehensive unit tests for the Passage module
-- @module tests.unit.core.test_passage_spec
-- @author Whisker Core Team

describe("Passage", function()
  local Passage, Choice

  before_each(function()
    Passage = require("whisker.core.passage")
    Choice = require("whisker.core.choice")
  end)

  describe("initialization", function()
    it("creates passage with required fields", function()
      local passage = Passage.new({ id = "test", name = "Test" })

      assert.is_not_nil(passage)
      assert.equals("test", passage.id)
      assert.equals("Test", passage.name)
    end)

    it("creates passage with all fields", function()
      local passage = Passage.new({
        id = "full",
        name = "Full Passage",
        content = "Some content"
      })

      assert.equals("full", passage.id)
      assert.equals("Full Passage", passage.name)
      assert.equals("Some content", passage.content)
    end)

    it("initializes empty collections", function()
      local passage = Passage.new({ id = "test", name = "Test" })

      assert.is_table(passage.choices)
      assert.is_table(passage.tags)
      assert.equals(0, #passage.choices)
    end)
  end)

  describe("content management", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("sets content", function()
      passage:set_content("New content")

      assert.equals("New content", passage.content)
    end)

    it("gets content", function()
      passage.content = "Test content"

      assert.equals("Test content", passage:get_content())
    end)

    it("handles empty content", function()
      -- Passage defaults to empty string content
      assert.equals("", passage.content)
      passage:set_content("")
      assert.equals("", passage.content)
    end)
  end)

  describe("choice management", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("adds choice", function()
      local choice = Choice.new({ text = "Go", target = "next" })
      passage:add_choice(choice)

      assert.equals(1, #passage.choices)
      assert.equals(choice, passage.choices[1])
    end)

    it("adds multiple choices", function()
      passage:add_choice(Choice.new({ text = "A", target = "a" }))
      passage:add_choice(Choice.new({ text = "B", target = "b" }))
      passage:add_choice(Choice.new({ text = "C", target = "c" }))

      assert.equals(3, #passage.choices)
    end)

    it("removes choice by index", function()
      passage:add_choice(Choice.new({ text = "A", target = "a" }))
      passage:add_choice(Choice.new({ text = "B", target = "b" }))

      passage:remove_choice(1)

      assert.equals(1, #passage.choices)
      assert.equals("B", passage.choices[1].text)
    end)

    it("gets choice by index", function()
      local choice = Choice.new({ text = "Test", target = "target" })
      passage:add_choice(choice)

      local retrieved = passage:get_choice(1)

      assert.equals(choice, retrieved)
    end)
  end)

  describe("tag management", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("adds tag", function()
      passage:add_tag("important")

      assert.is_true(passage:has_tag("important"))
    end)

    it("removes tag", function()
      passage:add_tag("remove_me")
      passage:remove_tag("remove_me")

      assert.is_false(passage:has_tag("remove_me"))
    end)

    it("gets all tags", function()
      passage:add_tag("a")
      passage:add_tag("b")
      passage:add_tag("c")

      local tags = passage:get_tags()

      assert.equals(3, #tags)
    end)
  end)

  describe("metadata", function()
    local passage

    before_each(function()
      passage = Passage.new({ id = "test", name = "Test" })
    end)

    it("sets and gets metadata", function()
      passage:set_metadata("key", "value")

      assert.equals("value", passage:get_metadata("key"))
    end)

    it("returns nil for nonexistent metadata", function()
      assert.is_nil(passage:get_metadata("nonexistent"))
    end)
  end)

  describe("validation", function()
    it("valid passage passes validation", function()
      local passage = Passage.new({ id = "valid", name = "Valid" })

      local valid, err = passage:validate()

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("fails without id", function()
      local passage = Passage.new({ name = "No ID" })
      passage.id = nil

      local valid, err = passage:validate()

      assert.is_false(valid)
      assert.is_string(err)
    end)
  end)

  describe("serialization", function()
    it("serializes passage data", function()
      local passage = Passage.new({
        id = "test",
        name = "Test",
        content = "Content"
      })
      passage:add_tag("tag1")
      passage:add_choice(Choice.new({ text = "Go", target = "next" }))

      local data = passage:serialize()

      assert.equals("test", data.id)
      assert.equals("Test", data.name)
      assert.equals("Content", data.content)
      assert.is_table(data.tags)
      assert.is_table(data.choices)
    end)

    it("deserializes passage data", function()
      local data = {
        id = "restored",
        name = "Restored",
        content = "Restored content",
        tags = { "tag1" },
        choices = {}
      }

      local passage = Passage.new({ id = "temp", name = "Temp" })
      passage:deserialize(data)

      assert.equals("restored", passage.id)
      assert.equals("Restored", passage.name)
    end)
  end)

  describe("from_table factory", function()
    it("creates passage from table", function()
      local data = {
        id = "from_table",
        name = "From Table",
        content = "Content"
      }

      local passage = Passage.from_table(data)

      assert.is_not_nil(passage)
      assert.equals("from_table", passage.id)
    end)

    it("returns nil for nil input", function()
      local passage = Passage.from_table(nil)

      assert.is_nil(passage)
    end)

    it("restores choices with metatables", function()
      local data = {
        id = "with_choices",
        name = "With Choices",
        choices = {
          { text = "Choice 1", target_passage = "p1" },
          { text = "Choice 2", target_passage = "p2" }
        }
      }

      local passage = Passage.from_table(data)

      assert.equals(2, #passage.choices)
      assert.is_function(passage.choices[1].validate)
      assert.is_function(passage.choices[2].get_text)
    end)
  end)

  describe("DI pattern support", function()
    local ChoiceFactory

    before_each(function()
      ChoiceFactory = require("whisker.core.factories.choice_factory")
    end)

    it("declares _dependencies", function()
      assert.is_table(Passage._dependencies)
    end)

    it("_dependencies includes choice_factory", function()
      local has_choice_factory = false
      for _, dep in ipairs(Passage._dependencies) do
        if dep == "choice_factory" then
          has_choice_factory = true
          break
        end
      end
      assert.is_true(has_choice_factory)
    end)

    it("provides create factory method", function()
      assert.is_function(Passage.create)
    end)

    it("create returns a factory function", function()
      local factory = Passage.create({ choice_factory = ChoiceFactory.new() })

      assert.is_function(factory)
    end)

    it("factory function creates valid passages", function()
      local factory = Passage.create({ choice_factory = ChoiceFactory.new() })
      local passage = factory({ id = "test", name = "Test" })

      assert.is_not_nil(passage)
      assert.equals("test", passage.id)
      assert.equals("Test", passage.name)
    end)

    it("factory function works without deps (backward compat)", function()
      local factory = Passage.create()
      local passage = factory({ id = "no_deps", name = "No Deps" })

      assert.is_not_nil(passage)
      assert.equals("no_deps", passage.id)
    end)

    it("backward compatibility: Passage.new still works", function()
      local passage = Passage.new({ id = "direct", name = "Direct" })

      assert.is_not_nil(passage)
      assert.equals("direct", passage.id)
    end)

    it("from_table accepts choice_factory parameter", function()
      local choice_factory = ChoiceFactory.new()
      local data = {
        id = "test",
        name = "Test",
        choices = {{ text = "Go", target_passage = "next" }}
      }

      local passage = Passage.from_table(data, choice_factory)

      assert.is_not_nil(passage)
      assert.equals(1, #passage.choices)
    end)

    it("restore_metatable accepts choice_factory parameter", function()
      local choice_factory = ChoiceFactory.new()
      local plain = {
        id = "plain",
        name = "Plain",
        choices = {{ text = "Go", target_passage = "next", metadata = {} }},
        tags = {},
        metadata = {}
      }

      local passage = Passage.restore_metatable(plain, choice_factory)

      assert.is_not_nil(passage)
      assert.equals(Passage, getmetatable(passage))
      assert.is_function(passage.choices[1].validate)
    end)

    it("uses mock choice factory when injected", function()
      -- Create a mock factory that tracks calls
      local mock_calls = 0
      local mock_factory = {
        create = function(self, opts)
          mock_calls = mock_calls + 1
          return Choice.new(opts)
        end,
        from_table = function(self, data)
          mock_calls = mock_calls + 1
          return Choice.from_table(data)
        end,
        restore_metatable = function(self, data)
          mock_calls = mock_calls + 1
          return Choice.restore_metatable(data)
        end
      }

      local data = {
        id = "mock_test",
        name = "Mock Test",
        choices = {
          { text = "A", target_passage = "a" },
          { text = "B", target_passage = "b" }
        }
      }

      local passage = Passage.from_table(data, mock_factory)

      assert.is_not_nil(passage)
      assert.equals(2, mock_calls)  -- from_table called twice for 2 choices
    end)
  end)
end)
