-- tests/unit/script/writer_spec.lua
-- Tests for Whisker Script source code writer

describe("WhiskerScriptWriter", function()
  local Writer
  local writer_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.writer"] = nil

    writer_module = require("whisker.script.writer")
    Writer = writer_module.Writer
  end)

  describe("new()", function()
    it("should create a new writer", function()
      local writer = Writer.new()
      assert.is_not_nil(writer)
    end)

    it("should accept custom indent", function()
      local writer = Writer.new({ indent = "\t" })
      assert.is_not_nil(writer)
    end)
  end)

  describe("write()", function()
    it("should return string", function()
      local writer = Writer.new()
      local result = writer:write({
        metadata = {},
        passages = {}
      })
      assert.is_string(result)
    end)

    it("should end with newline", function()
      local writer = Writer.new()
      local result = writer:write({
        metadata = {},
        passages = { { name = "Start", content = "Hello" } }
      })
      assert.are.equal("\n", result:sub(-1))
    end)
  end)

  describe("metadata writing", function()
    local writer

    before_each(function()
      writer = Writer.new()
    end)

    it("should write title", function()
      local result = writer:write({
        metadata = { title = "My Story" },
        passages = {}
      })
      assert.is_truthy(result:find("@@ title: My Story"))
    end)

    it("should write author", function()
      local result = writer:write({
        metadata = { author = "Jane Doe" },
        passages = {}
      })
      assert.is_truthy(result:find("@@ author: Jane Doe"))
    end)

    it("should write version", function()
      local result = writer:write({
        metadata = { version = "1.0.0" },
        passages = {}
      })
      -- Version strings with dots are quoted
      assert.is_truthy(result:find('@@ version: "1.0.0"'))
    end)

    it("should write custom metadata", function()
      local result = writer:write({
        metadata = { custom_field = "custom value" },
        passages = {}
      })
      assert.is_truthy(result:find("@@ custom_field: custom value"))
    end)

    it("should skip internal fields", function()
      local result = writer:write({
        metadata = {
          _internal = "hidden",
          format = "whisker",
          format_version = "1.0.0"
        },
        passages = {}
      })
      assert.is_nil(result:find("@@ _internal"))
      assert.is_nil(result:find("@@ format:"))
      assert.is_nil(result:find("@@ format_version"))
    end)

    it("should add blank line after metadata", function()
      local result = writer:write({
        metadata = { title = "Story" },
        passages = { { name = "Start", content = "Hello" } }
      })
      -- Should have metadata, blank line, then passage
      assert.is_truthy(result:find("@@ title: Story\n\n:: Start"))
    end)
  end)

  describe("passage writing", function()
    local writer

    before_each(function()
      writer = Writer.new()
    end)

    it("should write passage header", function()
      local result = writer:write({
        metadata = {},
        passages = { { name = "MyPassage", content = "" } }
      })
      assert.is_truthy(result:find(":: MyPassage"))
    end)

    it("should write passage content", function()
      local result = writer:write({
        metadata = {},
        passages = { { name = "Start", content = "Hello world!" } }
      })
      assert.is_truthy(result:find("Hello world!"))
    end)

    it("should write passage tags", function()
      local result = writer:write({
        metadata = {},
        passages = {
          { name = "Start", content = "", tags = { "tag1", "tag2" } }
        }
      })
      assert.is_truthy(result:find(":: Start %[tag1, tag2%]"))
    end)

    it("should put blank lines between passages", function()
      local result = writer:write({
        metadata = {},
        passages = {
          { name = "First", content = "Content 1" },
          { name = "Second", content = "Content 2" }
        }
      })
      -- Should have blank line between passages
      assert.is_truthy(result:find("Content 1\n\n:: Second"))
    end)

    it("should handle multiline content", function()
      local result = writer:write({
        metadata = {},
        passages = {
          { name = "Start", content = "Line 1\nLine 2\nLine 3" }
        }
      })
      assert.is_truthy(result:find("Line 1\nLine 2\nLine 3"))
    end)

    it("should use id as fallback for name", function()
      local result = writer:write({
        metadata = {},
        passages = { { id = "passage_id", content = "Hello" } }
      })
      assert.is_truthy(result:find(":: passage_id"))
    end)
  end)

  describe("choice writing", function()
    local writer

    before_each(function()
      writer = Writer.new()
    end)

    it("should write choice with target", function()
      local result = writer:write({
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "",
            choices = { { text = "Go", target = "Target" } }
          }
        }
      })
      assert.is_truthy(result:find("%+ %[Go%] %-> Target"))
    end)

    it("should write choice without target", function()
      local result = writer:write({
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "",
            choices = { { text = "Stay here" } }
          }
        }
      })
      assert.is_truthy(result:find("%+ %[Stay here%]"))
    end)

    it("should write choice with condition", function()
      local result = writer:write({
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "",
            choices = {
              { text = "Open door", target = "Inside", condition = "$has_key" }
            }
          }
        }
      })
      assert.is_truthy(result:find("%+ { %$has_key } %[Open door%] %-> Inside"))
    end)

    it("should handle choice label field", function()
      local result = writer:write({
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "",
            choices = { { label = "My Choice", target = "Next" } }
          }
        }
      })
      assert.is_truthy(result:find("%+ %[My Choice%]"))
    end)

    it("should handle choice link field", function()
      local result = writer:write({
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "",
            choices = { { text = "Go", link = "Destination" } }
          }
        }
      })
      assert.is_truthy(result:find("%-> Destination"))
    end)

    it("should write multiple choices", function()
      local result = writer:write({
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "",
            choices = {
              { text = "North", target = "North" },
              { text = "South", target = "South" },
              { text = "East", target = "East" }
            }
          }
        }
      })
      assert.is_truthy(result:find("%+ %[North%] %-> North"))
      assert.is_truthy(result:find("%+ %[South%] %-> South"))
      assert.is_truthy(result:find("%+ %[East%] %-> East"))
    end)
  end)

  describe("passage ordering", function()
    local writer

    before_each(function()
      writer = Writer.new()
    end)

    it("should put Start passage first", function()
      local result = writer:write({
        metadata = {},
        passages = {
          { name = "Zebra", content = "Z" },
          { name = "Start", content = "Beginning" },
          { name = "Apple", content = "A" }
        }
      })
      -- Start should come first
      local start_pos = result:find(":: Start")
      local zebra_pos = result:find(":: Zebra")
      local apple_pos = result:find(":: Apple")
      assert.is_truthy(start_pos < zebra_pos)
      assert.is_truthy(start_pos < apple_pos)
    end)

    it("should sort other passages alphabetically", function()
      local result = writer:write({
        metadata = {},
        passages = {
          { name = "Zebra", content = "Z" },
          { name = "Apple", content = "A" },
          { name = "Middle", content = "M" }
        }
      })
      local apple_pos = result:find(":: Apple")
      local middle_pos = result:find(":: Middle")
      local zebra_pos = result:find(":: Zebra")
      assert.is_truthy(apple_pos < middle_pos)
      assert.is_truthy(middle_pos < zebra_pos)
    end)
  end)

  describe("value formatting", function()
    local writer

    before_each(function()
      writer = Writer.new()
    end)

    it("should format string values", function()
      local result = writer:write({
        metadata = { title = "Test" },
        passages = {}
      })
      assert.is_truthy(result:find("@@ title: Test"))
    end)

    it("should format number values", function()
      local result = writer:write({
        metadata = { version = 2 },
        passages = {}
      })
      assert.is_truthy(result:find("@@ version: 2"))
    end)

    it("should format boolean values", function()
      local result = writer:write({
        metadata = { debug = true },
        passages = {}
      })
      assert.is_truthy(result:find("@@ debug: true"))
    end)
  end)

  describe("Story object compatibility", function()
    local writer

    before_each(function()
      writer = Writer.new()
    end)

    it("should handle Story with get_all_passages method", function()
      local story = {
        metadata = {},
        get_all_passages = function()
          return {
            { name = "Start", content = "Hello" }
          }
        end
      }
      local result = writer:write(story)
      assert.is_truthy(result:find(":: Start"))
    end)

    it("should handle Story with passages as hash table", function()
      local story = {
        metadata = {},
        passages = {
          Start = { content = "Hello", tags = {} },
          End = { content = "Goodbye", tags = {} }
        }
      }
      local result = writer:write(story)
      assert.is_truthy(result:find(":: Start"))
      assert.is_truthy(result:find(":: End"))
    end)

    it("should handle passage with get_choices method", function()
      local story = {
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "Choose:",
            get_choices = function()
              return {
                { text = "Go", target = "End" }
              }
            end
          }
        }
      }
      local result = writer:write(story)
      assert.is_truthy(result:find("%+ %[Go%] %-> End"))
    end)
  end)
end)
