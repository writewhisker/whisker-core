--- Export Manager Tests
-- @module tests.unit.export.init_spec

describe("ExportManager", function()
  local ExportManager
  local EventBus
  local manager, event_bus

  before_each(function()
    package.loaded["whisker.export.init"] = nil
    package.loaded["whisker.kernel.events"] = nil
    ExportManager = require("whisker.export.init")
    EventBus = require("whisker.kernel.events")
    event_bus = EventBus.new()
    manager = ExportManager.new(event_bus)
  end)

  describe("new", function()
    it("creates a new export manager", function()
      assert.is_table(manager)
      assert.is_table(manager._exporters)
    end)

    it("works without event bus", function()
      local m = ExportManager.new(nil)
      assert.is_table(m)
    end)
  end)

  describe("register", function()
    it("registers a valid exporter", function()
      local exporter = {
        can_export = function() return true end,
        export = function() return { content = "test" } end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return { format = "test" } end,
      }

      manager:register("test", exporter)
      assert.equals(exporter, manager:get_exporter("test"))
    end)

    it("rejects exporter missing can_export", function()
      local exporter = {
        export = function() end,
        validate = function() end,
        metadata = function() end,
      }

      assert.has_error(function()
        manager:register("bad", exporter)
      end)
    end)

    it("rejects exporter missing export", function()
      local exporter = {
        can_export = function() end,
        validate = function() end,
        metadata = function() end,
      }

      assert.has_error(function()
        manager:register("bad", exporter)
      end)
    end)

    it("rejects exporter missing validate", function()
      local exporter = {
        can_export = function() end,
        export = function() end,
        metadata = function() end,
      }

      assert.has_error(function()
        manager:register("bad", exporter)
      end)
    end)

    it("rejects exporter missing metadata", function()
      local exporter = {
        can_export = function() end,
        export = function() end,
        validate = function() end,
      }

      assert.has_error(function()
        manager:register("bad", exporter)
      end)
    end)

    it("emits exporter:registered event", function()
      local emitted = false
      local emitted_format = nil

      event_bus:on("exporter:registered", function(data)
        emitted = true
        emitted_format = data.format
      end)

      local exporter = {
        can_export = function() return true end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)

      assert.is_true(emitted)
      assert.equals("test", emitted_format)
    end)
  end)

  describe("unregister", function()
    it("removes a registered exporter", function()
      local exporter = {
        can_export = function() return true end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      assert.is_not_nil(manager:get_exporter("test"))

      manager:unregister("test")
      assert.is_nil(manager:get_exporter("test"))
    end)

    it("emits exporter:unregistered event", function()
      local emitted = false

      event_bus:on("exporter:unregistered", function(data)
        emitted = true
      end)

      local exporter = {
        can_export = function() return true end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      manager:unregister("test")

      assert.is_true(emitted)
    end)
  end)

  describe("get_formats", function()
    it("returns empty array when no formats registered", function()
      local formats = manager:get_formats()
      assert.same({}, formats)
    end)

    it("returns sorted list of formats", function()
      local dummy_exporter = {
        can_export = function() return true end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("html", dummy_exporter)
      manager:register("ink", dummy_exporter)
      manager:register("text", dummy_exporter)

      local formats = manager:get_formats()
      assert.same({"html", "ink", "text"}, formats)
    end)
  end)

  describe("has_format", function()
    it("returns false for unregistered format", function()
      assert.is_false(manager:has_format("unknown"))
    end)

    it("returns true for registered format", function()
      local exporter = {
        can_export = function() return true end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      assert.is_true(manager:has_format("test"))
    end)
  end)

  describe("export", function()
    it("returns error for unknown format", function()
      local result = manager:export({}, "unknown", {})
      assert.equals("Unknown export format: unknown", result.error)
    end)

    it("returns error when can_export returns false", function()
      local exporter = {
        can_export = function() return false, "Story is incompatible" end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      local result = manager:export({}, "test", {})
      assert.equals("Story is incompatible", result.error)
    end)

    it("calls exporter methods in correct order", function()
      local calls = {}
      local exporter = {
        can_export = function()
          table.insert(calls, "can_export")
          return true
        end,
        export = function()
          table.insert(calls, "export")
          return { content = "test" }
        end,
        validate = function()
          table.insert(calls, "validate")
          return { valid = true, errors = {} }
        end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      manager:export({}, "test", {})

      assert.same({"can_export", "export", "validate"}, calls)
    end)

    it("includes validation in bundle", function()
      local exporter = {
        can_export = function() return true end,
        export = function() return { content = "test" } end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      local bundle = manager:export({}, "test", {})

      assert.is_table(bundle.validation)
      assert.is_true(bundle.validation.valid)
    end)

    it("emits export:before event", function()
      local before_called = false
      local received_data = nil

      event_bus:on("export:before", function(data)
        before_called = true
        received_data = data
      end)

      local exporter = {
        can_export = function() return true end,
        export = function() return { content = "test" } end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      local story = { title = "Test" }
      manager:register("test", exporter)
      manager:export(story, "test", { opt = "value" })

      assert.is_true(before_called)
      assert.equals("Test", received_data.story.title)
      assert.equals("test", received_data.format)
      assert.equals("value", received_data.options.opt)
    end)

    it("emits export:after event", function()
      local after_called = false

      event_bus:on("export:after", function(data)
        after_called = true
      end)

      local exporter = {
        can_export = function() return true end,
        export = function() return { content = "test" } end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      manager:export({}, "test", {})

      assert.is_true(after_called)
    end)

    it("cancels export when event handler cancels", function()
      event_bus:on("export:before", function(data)
        data.cancel = true
      end)

      local exporter = {
        can_export = function() return true end,
        export = function() return { content = "test" } end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      local result = manager:export({}, "test", {})

      assert.equals("Export cancelled by event handler", result.error)
    end)

    it("handles export errors gracefully", function()
      local exporter = {
        can_export = function() return true end,
        export = function() error("Something went wrong") end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("test", exporter)
      local result = manager:export({}, "test", {})

      assert.truthy(result.error:match("Export failed"))
    end)
  end)

  describe("export_all", function()
    it("exports to multiple formats", function()
      local exporter = {
        can_export = function() return true end,
        export = function(_, story, opts)
          return { content = "exported" }
        end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return {} end,
      }

      manager:register("html", exporter)
      manager:register("text", exporter)

      local story = { title = "Test" }
      local results = manager:export_all(story, {"html", "text"}, {})

      assert.is_table(results.html)
      assert.is_table(results.text)
      assert.equals("exported", results.html.content)
      assert.equals("exported", results.text.content)
    end)
  end)

  describe("get_all_metadata", function()
    it("returns metadata for all exporters", function()
      local exporter1 = {
        can_export = function() return true end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return { format = "html", version = "1.0" } end,
      }

      local exporter2 = {
        can_export = function() return true end,
        export = function() return {} end,
        validate = function() return { valid = true, errors = {} } end,
        metadata = function() return { format = "text", version = "2.0" } end,
      }

      manager:register("html", exporter1)
      manager:register("text", exporter2)

      local metadata = manager:get_all_metadata()

      assert.equals("html", metadata.html.format)
      assert.equals("1.0", metadata.html.version)
      assert.equals("text", metadata.text.format)
      assert.equals("2.0", metadata.text.version)
    end)
  end)
end)
