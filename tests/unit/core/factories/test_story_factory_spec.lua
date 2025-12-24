--- StoryFactory Unit Tests
-- Tests for the StoryFactory implementation
-- @module tests.unit.core.factories.test_story_factory_spec
-- @author Whisker Core Team

describe("StoryFactory", function()
  local StoryFactory
  local PassageFactory
  local ChoiceFactory
  local Story
  local factory

  before_each(function()
    StoryFactory = require("whisker.core.factories.story_factory")
    PassageFactory = require("whisker.core.factories.passage_factory")
    ChoiceFactory = require("whisker.core.factories.choice_factory")
    Story = require("whisker.core.story")

    local choice_factory = ChoiceFactory.new()
    local passage_factory = PassageFactory.new({ choice_factory = choice_factory })
    factory = StoryFactory.new({ passage_factory = passage_factory })
  end)

  describe("initialization", function()
    it("creates factory instance", function()
      assert.is_not_nil(factory)
    end)

    it("declares _dependencies", function()
      assert.is_table(StoryFactory._dependencies)
    end)

    it("_dependencies includes passage_factory", function()
      local has_passage_factory = false
      for _, dep in ipairs(StoryFactory._dependencies) do
        if dep == "passage_factory" then
          has_passage_factory = true
          break
        end
      end
      assert.is_true(has_passage_factory)
    end)

    it("works without deps parameter (lazy loads)", function()
      local no_deps_factory = StoryFactory.new()
      assert.is_not_nil(no_deps_factory)
      local story = no_deps_factory:create({ title = "Test" })
      assert.is_not_nil(story)
    end)
  end)

  describe("create", function()
    it("creates story with title", function()
      local story = factory:create({ title = "My Story" })

      assert.is_not_nil(story)
      assert.equals("My Story", story.metadata.name)
    end)

    it("creates story with all metadata", function()
      local story = factory:create({
        title = "Full Story",
        author = "Test Author",
        version = "2.0.0",
        ifid = "12345678-1234-1234-1234-123456789012"
      })

      assert.equals("Full Story", story.metadata.name)
      assert.equals("Test Author", story.metadata.author)
      assert.equals("2.0.0", story.metadata.version)
      assert.equals("12345678-1234-1234-1234-123456789012", story.metadata.ifid)
    end)

    it("returns object with Story metatable", function()
      local story = factory:create({ title = "Test" })

      assert.equals(Story, getmetatable(story))
    end)

    it("returned story has validate method", function()
      local story = factory:create({ title = "Test" })

      assert.is_function(story.validate)
    end)

    it("returned story has add_passage method", function()
      local story = factory:create({ title = "Test" })

      assert.is_function(story.add_passage)
    end)
  end)

  describe("from_table", function()
    it("restores story from serialized data", function()
      local data = {
        metadata = {
          name = "Restored Story",
          author = "Author"
        },
        start_passage = "start"
      }

      local story = factory:from_table(data)

      assert.is_not_nil(story)
      assert.equals("Restored Story", story.metadata.name)
    end)

    it("returns nil for nil input", function()
      local story = factory:from_table(nil)

      assert.is_nil(story)
    end)

    it("restores nested passages with metatables", function()
      local data = {
        metadata = { name = "Story" },
        passages = {
          start = {
            id = "start",
            name = "Start",
            content = "Beginning",
            choices = {
              { text = "Continue", target_passage = "next" }
            }
          },
          next = {
            id = "next",
            name = "Next",
            content = "Continuation"
          }
        },
        start_passage = "start"
      }

      local story = factory:from_table(data)

      assert.is_not_nil(story.passages.start)
      assert.is_function(story.passages.start.validate)
      assert.is_function(story.passages.start.choices[1].validate)
    end)

    it("returned story has proper metatable", function()
      local data = { metadata = { name = "T" } }
      local story = factory:from_table(data)

      assert.equals(Story, getmetatable(story))
    end)
  end)

  describe("restore_metatable", function()
    it("restores metatable to plain table", function()
      local plain_data = {
        metadata = { name = "Plain Story" },
        passages = {},
        variables = {},
        tags = {},
        settings = {}
      }

      local story = factory:restore_metatable(plain_data)

      assert.is_not_nil(story)
      assert.equals(Story, getmetatable(story))
    end)

    it("returns nil for nil input", function()
      local result = factory:restore_metatable(nil)

      assert.is_nil(result)
    end)

    it("returns same object if already has metatable", function()
      local story = factory:create({ title = "T" })
      local restored = factory:restore_metatable(story)

      assert.equals(story, restored)
    end)

    it("restores nested passage metatables", function()
      local plain = {
        metadata = { name = "Nested" },
        passages = {
          start = {
            id = "start",
            name = "Start",
            choices = {
              { text = "Go", target_passage = "end", metadata = {} }
            },
            tags = {},
            metadata = {}
          }
        },
        variables = {},
        tags = {},
        settings = {}
      }

      local restored = factory:restore_metatable(plain)

      assert.is_function(restored.passages.start.validate)
      assert.is_function(restored.passages.start.choices[1].validate)
    end)
  end)

  describe("get_class", function()
    it("returns Story class", function()
      local cls = factory:get_class()

      assert.equals(Story, cls)
    end)
  end)

  describe("get_passage_factory", function()
    it("returns the passage factory", function()
      local pf = factory:get_passage_factory()

      assert.is_not_nil(pf)
      assert.is_function(pf.create)
    end)
  end)

  describe("IStoryFactory contract compliance", function()
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

  describe("uses injected passage_factory", function()
    it("uses provided passage factory for from_table", function()
      local mock_calls = 0
      local mock_passage_factory = {
        create = function() mock_calls = mock_calls + 1 end,
        from_table = function(self, data)
          mock_calls = mock_calls + 1
          local Passage = require("whisker.core.passage")
          return Passage.from_table(data)
        end,
        restore_metatable = function(self, data)
          mock_calls = mock_calls + 1
          local Passage = require("whisker.core.passage")
          return Passage.restore_metatable(data)
        end
      }

      local custom_factory = StoryFactory.new({ passage_factory = mock_passage_factory })
      local data = {
        metadata = { name = "Test" },
        passages = {
          start = { id = "start", name = "Start" },
          middle = { id = "middle", name = "Middle" }
        }
      }

      custom_factory:from_table(data)

      assert.equals(2, mock_calls)  -- from_table called for each passage
    end)
  end)
end)
