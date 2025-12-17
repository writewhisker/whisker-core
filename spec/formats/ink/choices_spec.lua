-- spec/formats/ink/choices_spec.lua
-- Tests for Ink choice handling

describe("Ink Choices", function()
  local InkEngine
  local InkStory
  local ChoiceAdapter

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.vendor%.tinta") then
        package.loaded[k] = nil
      end
    end
    -- Clear tinta globals
    rawset(_G, "import", nil)
    rawset(_G, "compat", nil)
    rawset(_G, "dump", nil)
    rawset(_G, "classic", nil)

    InkEngine = require("whisker.formats.ink.engine")
    InkStory = require("whisker.formats.ink.story")
    ChoiceAdapter = require("whisker.formats.ink.choice_adapter")
  end)

  describe("ChoiceAdapter", function()
    describe("module metadata", function()
      it("should have _whisker metadata", function()
        assert.is_table(ChoiceAdapter._whisker)
        assert.are.equal("InkChoiceAdapter", ChoiceAdapter._whisker.name)
      end)
    end)

    describe("new", function()
      it("should create adapter instance", function()
        local adapter = ChoiceAdapter.new()
        assert.is_table(adapter)
      end)
    end)

    describe("adapt", function()
      it("should adapt ink choice to whisker format", function()
        local adapter = ChoiceAdapter.new()
        local ink_choice = {
          text = "Go north",
          pathStringOnChoice = "start.north",
          index = 0
        }

        local adapted = adapter:adapt(ink_choice, 1)

        assert.is_table(adapted)
        assert.are.equal("Go north", adapted.text)
        assert.are.equal("start.north", adapted.id)
        assert.are.equal(1, adapted.index)
        assert.are.equal("start.north", adapted.target)
      end)

      it("should return nil for nil input", function()
        local adapter = ChoiceAdapter.new()
        assert.is_nil(adapter:adapt(nil, 1))
      end)

      it("should include metadata", function()
        local adapter = ChoiceAdapter.new()
        local ink_choice = {
          text = "Test",
          pathStringOnChoice = "test.path",
          index = 2,
          tags = {"tag1", "tag2"}
        }

        local adapted = adapter:adapt(ink_choice, 3)

        assert.is_table(adapted.metadata)
        assert.are.equal(2, adapted.metadata.ink_index)
        assert.are.same({"tag1", "tag2"}, adapted.metadata.tags)
      end)
    end)

    describe("adapt_all", function()
      it("should adapt multiple choices", function()
        local adapter = ChoiceAdapter.new()
        local ink_choices = {
          { text = "Choice 1", pathStringOnChoice = "path1", index = 0 },
          { text = "Choice 2", pathStringOnChoice = "path2", index = 1 }
        }

        local adapted = adapter:adapt_all(ink_choices)

        assert.are.equal(2, #adapted)
        assert.are.equal("Choice 1", adapted[1].text)
        assert.are.equal("Choice 2", adapted[2].text)
      end)

      it("should return empty array for nil", function()
        local adapter = ChoiceAdapter.new()
        local result = adapter:adapt_all(nil)
        assert.are.same({}, result)
      end)

      it("should return empty array for empty input", function()
        local adapter = ChoiceAdapter.new()
        local result = adapter:adapt_all({})
        assert.are.same({}, result)
      end)
    end)

    describe("to_ink", function()
      it("should convert back to ink format", function()
        local adapter = ChoiceAdapter.new()
        local choice = {
          text = "Test choice",
          target = "test.path",
          index = 2,
          metadata = {
            ink_index = 1,
            tags = {"tag1"}
          }
        }

        local ink = adapter:to_ink(choice)

        assert.are.equal("Test choice", ink.text)
        assert.are.equal("test.path", ink.pathStringOnChoice)
        assert.are.equal(1, ink.index)
      end)

      it("should return nil for nil input", function()
        local adapter = ChoiceAdapter.new()
        assert.is_nil(adapter:to_ink(nil))
      end)
    end)

    describe("is_sticky", function()
      it("should return false by default", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = {} }
        assert.is_false(adapter:is_sticky(choice))
      end)

      it("should return true when marked sticky", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = { is_sticky = true } }
        assert.is_true(adapter:is_sticky(choice))
      end)

      it("should return false for nil input", function()
        local adapter = ChoiceAdapter.new()
        assert.is_false(adapter:is_sticky(nil))
      end)
    end)

    describe("is_once_only", function()
      it("should return true by default", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = {} }
        assert.is_true(adapter:is_once_only(choice))
      end)

      it("should return false when sticky", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = { is_sticky = true } }
        assert.is_false(adapter:is_once_only(choice))
      end)
    end)

    describe("is_fallback", function()
      it("should return false by default", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = {} }
        assert.is_false(adapter:is_fallback(choice))
      end)

      it("should return true for invisible default", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = { is_invisible_default = true } }
        assert.is_true(adapter:is_fallback(choice))
      end)
    end)

    describe("get_tags", function()
      it("should return tags", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = { tags = {"a", "b"} } }
        assert.are.same({"a", "b"}, adapter:get_tags(choice))
      end)

      it("should return empty array for no tags", function()
        local adapter = ChoiceAdapter.new()
        local choice = { metadata = {} }
        assert.are.same({}, adapter:get_tags(choice))
      end)
    end)
  end)

  describe("InkEngine choice integration", function()
    -- Note: These tests use minimal.json which has no choices
    -- The choice adapter is tested in isolation above
    -- Full integration tests with choices require a properly compiled .ink.json file

    it("should return empty choices for story without choices", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      local choices = engine:get_available_choices()
      assert.is_table(choices)
      assert.are.equal(0, #choices)
    end)

    it("should return empty before start", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)

      local choices = engine:get_available_choices()
      assert.is_table(choices)
      assert.are.equal(0, #choices)
    end)

    it("should error on invalid choice index when no choices", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      assert.has_error(function()
        engine:make_choice(1)
      end)
    end)

    it("should error on zero index", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      assert.has_error(function()
        engine:make_choice(0)
      end)
    end)
  end)

  describe("get_choices_as_objects", function()
    it("should return empty for story without choices", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      local choices = engine:get_choices_as_objects()
      assert.is_table(choices)
      assert.are.equal(0, #choices)
    end)

    it("should use Choice adapter for conversion", function()
      -- The adapter is tested in isolation above
      -- This just verifies the method exists and works
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      engine:load(story)
      engine:start()

      -- Should not error
      local choices = engine:get_choices_as_objects()
      assert.is_table(choices)
    end)
  end)
end)
