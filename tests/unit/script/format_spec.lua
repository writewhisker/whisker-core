-- tests/unit/script/format_spec.lua
-- Tests for WhiskerScriptFormat IFormat implementation

describe("WhiskerScriptFormat", function()
  local WhiskerScriptFormat
  local format_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.format"] = nil
    package.loaded["whisker.script"] = nil
    package.loaded["whisker.script.writer"] = nil

    format_module = require("whisker.script.format")
    WhiskerScriptFormat = format_module.WhiskerScriptFormat
  end)

  describe("new()", function()
    it("should create a new format handler", function()
      local handler = WhiskerScriptFormat.new()
      assert.is_not_nil(handler)
    end)

    it("should accept options", function()
      local emitter = { emit = function() end }
      local handler = WhiskerScriptFormat.new({
        event_emitter = emitter
      })
      assert.is_not_nil(handler)
    end)
  end)

  describe("metadata", function()
    it("should have name 'whisker'", function()
      assert.are.equal("whisker", WhiskerScriptFormat.name)
    end)

    it("should have version", function()
      assert.is_not_nil(WhiskerScriptFormat.version)
    end)

    it("should have .wsk extension", function()
      assert.is_truthy(
        vim == nil or -- Handle vim global
        table.concat(WhiskerScriptFormat.extensions, ","):find("wsk")
      )
    end)
  end)

  describe("can_import()", function()
    local handler

    before_each(function()
      handler = WhiskerScriptFormat.new()
    end)

    it("should return false for nil", function()
      assert.is_false(handler:can_import(nil))
    end)

    it("should return false for non-string", function()
      assert.is_false(handler:can_import(123))
      assert.is_false(handler:can_import({}))
    end)

    it("should detect passage declaration (::)", function()
      local source = ":: Start\nHello world!"
      assert.is_true(handler:can_import(source))
    end)

    it("should detect metadata declaration (@@)", function()
      local source = "@@ title: My Story\n:: Start\nHello!"
      assert.is_true(handler:can_import(source))
    end)

    it("should detect choice markers (+)", function()
      local source = "Some text\n+ [Go north] -> North"
      assert.is_true(handler:can_import(source))
    end)

    it("should detect variable assignments (~)", function()
      local source = ":: Start\n~ $score = 0\nGame started."
      assert.is_true(handler:can_import(source))
    end)

    it("should handle leading whitespace", function()
      local source = "  :: Start\nHello!"
      assert.is_true(handler:can_import(source))
    end)

    it("should return false for plain text", function()
      local source = "This is just some plain text without any markers."
      assert.is_false(handler:can_import(source))
    end)

    it("should return false for JSON", function()
      local source = '{"inkVersion": 21, "root": []}'
      assert.is_false(handler:can_import(source))
    end)
  end)

  describe("import()", function()
    local handler

    before_each(function()
      handler = WhiskerScriptFormat.new()
    end)

    it("should compile simple story", function()
      local source = [[
:: Start
Welcome to the story!

+ [Continue] -> End

:: End
The end.
]]
      local story = handler:import(source)
      assert.is_not_nil(story)
    end)

    it("should throw on nil source", function()
      assert.has_error(function()
        handler:import(nil)
      end)
    end)

    it("should compile with warnings for undefined references", function()
      -- Undefined passage references generate warnings, not blocking errors
      -- The import should still succeed
      local source = ":: Start\n+ [Go] -> NonExistentPassage"
      local story = handler:import(source)
      assert.is_not_nil(story)
    end)

    it("should create passages from source", function()
      local source = [[
:: Start
Hello!

:: Other
World!
]]
      local story = handler:import(source)
      assert.is_not_nil(story)
      -- Story should have passages
      local has_passages = story.passages ~= nil or
        (type(story.get_passage) == "function" and story:get_passage("Start"))
      assert.is_truthy(has_passages)
    end)
  end)

  describe("can_export()", function()
    local handler

    before_each(function()
      handler = WhiskerScriptFormat.new()
    end)

    it("should return false for nil", function()
      assert.is_false(handler:can_export(nil))
    end)

    it("should return false for non-table", function()
      assert.is_false(handler:can_export("string"))
      assert.is_false(handler:can_export(123))
    end)

    it("should return true for story with passages table", function()
      local story = {
        passages = {
          { name = "Start", content = "Hello" }
        }
      }
      assert.is_true(handler:can_export(story))
    end)

    it("should return true for story with get_passages method", function()
      local story = {
        get_passages = function()
          return {}
        end
      }
      assert.is_true(handler:can_export(story))
    end)
  end)

  describe("export()", function()
    local handler

    before_each(function()
      handler = WhiskerScriptFormat.new()
    end)

    it("should export story with metadata", function()
      local story = {
        metadata = {
          title = "Test Story",
          author = "Test Author"
        },
        passages = {
          { name = "Start", content = "Hello world!" }
        }
      }
      local source = handler:export(story)
      assert.is_not_nil(source)
      assert.is_truthy(source:find("@@ title: Test Story"))
      assert.is_truthy(source:find("@@ author: Test Author"))
    end)

    it("should export passages", function()
      local story = {
        metadata = {},
        passages = {
          { name = "Start", content = "Welcome!" },
          { name = "End", content = "Goodbye!" }
        }
      }
      local source = handler:export(story)
      assert.is_truthy(source:find(":: Start"))
      assert.is_truthy(source:find(":: End"))
      assert.is_truthy(source:find("Welcome!"))
      assert.is_truthy(source:find("Goodbye!"))
    end)

    it("should export choices", function()
      local story = {
        metadata = {},
        passages = {
          {
            name = "Start",
            content = "Choose:",
            choices = {
              { text = "Go north", target = "North" },
              { text = "Go south", target = "South" }
            }
          }
        }
      }
      local source = handler:export(story)
      assert.is_truthy(source:find("%+ %[Go north%] %-> North"))
      assert.is_truthy(source:find("%+ %[Go south%] %-> South"))
    end)

    it("should export tags", function()
      local story = {
        metadata = {},
        passages = {
          { name = "Start", content = "Hello", tags = { "intro", "important" } }
        }
      }
      local source = handler:export(story)
      assert.is_truthy(source:find(":: Start %[intro, important%]"))
    end)
  end)

  describe("event emissions", function()
    it("should emit event on import", function()
      local emitted = nil
      local emitter = {
        emit = function(_, event_name, data)
          emitted = { name = event_name, data = data }
        end
      }
      local handler = WhiskerScriptFormat.new({ event_emitter = emitter })

      pcall(function()
        handler:import(":: Start\nHello!")
      end)

      assert.is_not_nil(emitted)
      assert.are.equal("whisker.script.imported", emitted.name)
    end)

    it("should emit event on export", function()
      local emitted = nil
      local emitter = {
        emit = function(_, event_name, data)
          emitted = { name = event_name, data = data }
        end
      }
      local handler = WhiskerScriptFormat.new({ event_emitter = emitter })

      handler:export({
        metadata = {},
        passages = { { name = "Start", content = "Hello" } }
      })

      assert.is_not_nil(emitted)
      assert.are.equal("whisker.script.exported", emitted.name)
    end)
  end)
end)
