--- Export Integration Tests
-- End-to-end tests for the export system
-- @module tests.integration.export.integration_spec

describe("Export Integration", function()
  local ExportManager
  local EventBus
  local HTMLExporter
  local InkExporter
  local TextExporter

  local manager, event_bus

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.export.init"] = nil
    package.loaded["whisker.kernel.events"] = nil
    package.loaded["whisker.export.html.html_exporter"] = nil
    package.loaded["whisker.export.ink.ink_exporter"] = nil
    package.loaded["whisker.export.text.text_exporter"] = nil
    package.loaded["whisker.export.utils"] = nil

    -- Load modules
    ExportManager = require("whisker.export.init")
    EventBus = require("whisker.kernel.events")
    HTMLExporter = require("whisker.export.html.html_exporter")
    InkExporter = require("whisker.export.ink.ink_exporter")
    TextExporter = require("whisker.export.text.text_exporter")

    -- Set up manager with all exporters
    event_bus = EventBus.new()
    manager = ExportManager.new(event_bus)
    manager:register("html", HTMLExporter.new())
    manager:register("ink", InkExporter.new())
    manager:register("text", TextExporter.new())
  end)

  describe("with minimal story", function()
    local story

    before_each(function()
      story = require("tests.fixtures.stories.minimal")
    end)

    after_each(function()
      package.loaded["tests.fixtures.stories.minimal"] = nil
    end)

    it("exports to HTML", function()
      local bundle = manager:export(story, "html", {})

      assert.is_nil(bundle.error)
      assert.is_string(bundle.content)
      assert.truthy(bundle.content:match("Minimal Story"))
      assert.truthy(bundle.content:match("WHISKER_STORY_DATA"))
      assert.is_true(bundle.validation.valid)
    end)

    it("exports to Ink JSON", function()
      local bundle = manager:export(story, "ink", {})

      assert.is_nil(bundle.error)
      assert.is_string(bundle.content)
      assert.truthy(bundle.content:match("inkVersion"))
      assert.truthy(bundle.content:match("root"))
      assert.is_true(bundle.validation.valid)
    end)

    it("exports to text", function()
      local bundle = manager:export(story, "text", {})

      assert.is_nil(bundle.error)
      assert.is_string(bundle.content)
      assert.truthy(bundle.content:match("Minimal Story"))
      assert.truthy(bundle.content:match("Test Author"))
      assert.is_true(bundle.validation.valid)
    end)
  end)

  describe("with branching story", function()
    local story

    before_each(function()
      story = require("tests.fixtures.stories.branching")
    end)

    after_each(function()
      package.loaded["tests.fixtures.stories.branching"] = nil
    end)

    it("exports all passages to HTML", function()
      local bundle = manager:export(story, "html", {})

      assert.is_nil(bundle.error)
      assert.truthy(bundle.content:match("crossroads"))
      assert.truthy(bundle.content:match("left path"))
      assert.truthy(bundle.content:match("THE END"))
    end)

    it("exports all passages to text", function()
      local bundle = manager:export(story, "text", {})

      assert.is_nil(bundle.error)
      -- Should have 7 passages
      assert.truthy(bundle.content:match("Total passages: 7"))
    end)

    it("preserves story structure in Ink", function()
      local bundle = manager:export(story, "ink", {})

      assert.is_nil(bundle.error)
      -- Should have passage references
      assert.truthy(bundle.content:match("start"))
      assert.truthy(bundle.content:match("left"))
      assert.truthy(bundle.content:match("right"))
    end)
  end)

  describe("export options", function()
    local story

    before_each(function()
      story = require("tests.fixtures.stories.minimal")
    end)

    after_each(function()
      package.loaded["tests.fixtures.stories.minimal"] = nil
    end)

    it("minify option reduces HTML size", function()
      local normal = manager:export(story, "html", { minify = false })
      local minified = manager:export(story, "html", { minify = true })

      assert.is_true(#minified.content < #normal.content)
    end)

    it("pretty option increases Ink JSON size", function()
      local compact = manager:export(story, "ink", { pretty = false })
      local pretty = manager:export(story, "ink", { pretty = true })

      assert.is_true(#pretty.content > #compact.content)
    end)

    it("include_metadata option affects text output", function()
      local with_meta = manager:export(story, "text", { include_metadata = true })
      local without_meta = manager:export(story, "text", { include_metadata = false })

      assert.truthy(with_meta.content:match("Total passages"))
      assert.falsy(without_meta.content:match("Total passages"))
    end)
  end)

  describe("event emission", function()
    local story

    before_each(function()
      story = require("tests.fixtures.stories.minimal")
    end)

    after_each(function()
      package.loaded["tests.fixtures.stories.minimal"] = nil
    end)

    it("emits export:before event", function()
      local before_called = false
      local received_format = nil

      event_bus:on("export:before", function(data)
        before_called = true
        received_format = data.format
      end)

      manager:export(story, "html", {})

      assert.is_true(before_called)
      assert.equals("html", received_format)
    end)

    it("emits export:after event", function()
      local after_called = false
      local received_bundle = nil

      event_bus:on("export:after", function(data)
        after_called = true
        received_bundle = data.bundle
      end)

      manager:export(story, "html", {})

      assert.is_true(after_called)
      assert.is_table(received_bundle)
      assert.is_string(received_bundle.content)
    end)

    it("allows cancellation via before event", function()
      event_bus:on("export:before", function(data)
        data.cancel = true
      end)

      local result = manager:export(story, "html", {})

      assert.truthy(result.error)
      assert.truthy(result.error:match("cancelled"))
    end)
  end)

  describe("error handling", function()
    it("returns error for unknown format", function()
      local story = { passages = {{ name = "start", text = "Hello" }} }
      local result = manager:export(story, "unknown", {})

      assert.truthy(result.error)
      assert.truthy(result.error:match("Unknown export format"))
    end)

    it("returns error for incompatible story (Ink)", function()
      local story = {
        passages = {{
          name = "start",
          text = "Hello",
          lua_code = "print('not compatible')"
        }}
      }

      local result = manager:export(story, "ink", {})

      assert.truthy(result.error)
    end)
  end)

  describe("multi-format export", function()
    local story

    before_each(function()
      story = require("tests.fixtures.stories.minimal")
    end)

    after_each(function()
      package.loaded["tests.fixtures.stories.minimal"] = nil
    end)

    it("exports to all formats", function()
      local results = manager:export_all(story, {"html", "ink", "text"}, {})

      assert.is_table(results.html)
      assert.is_table(results.ink)
      assert.is_table(results.text)

      assert.is_nil(results.html.error)
      assert.is_nil(results.ink.error)
      assert.is_nil(results.text.error)
    end)
  end)
end)
